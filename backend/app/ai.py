"""Claude features: reading a transcript, the family digest, and "Ask about Mom".

Every function falls back to simple rules when Claude isn't configured, so
the app keeps working without an API key (or without internet).
"""

from __future__ import annotations

import logging
import os
from datetime import date
from typing import Literal

import anthropic
from pydantic import BaseModel, Field

from . import rules

log = logging.getLogger("grandvoice.ai")

MODEL = os.environ.get("CLAUDE_MODEL", "claude-opus-5")

# If Claude's safety classifiers decline a request, the API retries it on
# Anthropic's recommended fallback model instead of returning a refusal.
_FALLBACK = {
    "extra_headers": {"anthropic-beta": "server-side-fallback-2026-07-01"},
    "extra_body": {"fallbacks": "default"},
}

_client: anthropic.Anthropic | None = None


def enabled() -> bool:
    return bool(os.environ.get("ANTHROPIC_API_KEY") or os.environ.get("ANTHROPIC_AUTH_TOKEN"))


def client() -> anthropic.Anthropic:
    global _client
    if _client is None:
        _client = anthropic.Anthropic(timeout=30.0, max_retries=1)
    return _client


# ---------- 1. Here's what I heard ----------

class Update(BaseModel):
    title: str = Field(description="Short line shown with a checkbox, e.g. 'Lisinopril 10 mg, now mornings' or 'Maya visits, Sunday Sep 27'")
    kind: Literal["Medicine change", "Calendar"]


class Analysis(BaseModel):
    summary: str = Field(description="The entry retold in 1-3 short first-person sentences")
    updates: list[Update]
    flags: list[Literal["dizzy", "pain", "tired", "fall", "sleep", "confused", "lonely"]]


ANALYZE_SYSTEM = """You read a spoken diary entry from an older adult and pull out things their family and medicine list need to know.

Her medicines: {meds}.
Today is {today}.

- summary: retell the entry in 1-3 short sentences, first person, plain words, keeping her voice.
- updates: only changes she clearly stated.
  - "Medicine change": a medicine from her list whose time, dose or status changed. Title like "Lisinopril 10 mg, now mornings". Map descriptions such as "blood pressure pill" to the right medicine.
  - "Calendar": a future visit, appointment or event with a day. Title like "Maya visits, Sunday Sep 27" with the real date worked out from today.
  - Past events are not updates. Return an empty list when nothing changed.
- flags: symptoms or feelings she mentioned, from the allowed list only."""


def analyze(text: str, today: date) -> dict:
    fallback = {**rules.extract(text, today), "summary": text, "source": "rules"}
    if not enabled() or not text.strip():
        return fallback
    meds = ", ".join(f"{n} {d}" for n, d in rules.MEDICINES.values())
    try:
        response = client().messages.parse(
            model=MODEL,
            max_tokens=4000,
            system=ANALYZE_SYSTEM.format(meds=meds, today=today.strftime("%A, %B %d, %Y")),
            messages=[{"role": "user", "content": text}],
            output_format=Analysis,
            output_config={"effort": "low"},
            **_FALLBACK,
        )
        if response.stop_reason == "refusal" or response.parsed_output is None:
            return fallback
        result = response.parsed_output.model_dump()
        result["source"] = "claude"
        return result
    except anthropic.APIError as e:
        log.warning("analyze fell back to rules: %s", e)
        return fallback


# ---------- 2. Tonight's digest ----------

DIGEST_SYSTEM = """You write a short evening update for a family member about their mom, using only her shared diary entries and medicine log below.
Write 2-4 warm, plain sentences in third person ("Mom ..."). Mention anything health-related (symptoms, medicine changes, missed doses) and upcoming visits.
Do not add anything that is not in the entries. If there is nothing today, say so kindly."""


def digest(entries: list[dict], meds_line: str) -> dict:
    if not entries:
        return {"digest": "Mom hasn't shared anything today yet.", "source": "rules"}
    joined = "\n".join(f"- {e['time']}: {e['text']}" for e in entries)
    fallback = {"digest": " ".join(e["text"] for e in entries), "source": "rules"}
    if not enabled():
        return fallback
    try:
        response = client().messages.create(
            model=MODEL,
            max_tokens=2000,
            system=DIGEST_SYSTEM,
            messages=[{"role": "user", "content": f"Today's shared entries:\n{joined}\n\nMedicines: {meds_line}"}],
            output_config={"effort": "low"},
            **_FALLBACK,
        )
        text = "".join(b.text for b in response.content if b.type == "text").strip()
        if response.stop_reason == "refusal" or not text:
            return fallback
        return {"digest": text, "source": "claude"}
    except anthropic.APIError as e:
        log.warning("digest fell back: %s", e)
        return fallback


# ---------- 3. Ask about Mom ----------

class Answer(BaseModel):
    answer: str = Field(description="2-3 plain sentences answering from the entries only")
    source_ids: list[str] = Field(description="ids of the entries the answer is based on")


ASK_SYSTEM = """A family member is asking about their mom. Answer only from her shared diary entries below; each has an id and a date.
Be warm and brief (2-3 sentences). Mention dates when they help. If the entries don't say, reply that she hasn't mentioned it in what she shared.
List the ids of the entries you used in source_ids."""


def ask(question: str, entries: list[dict]) -> dict:
    if not entries:
        return {"answer": "Mom hasn't shared any entries yet.", "source_ids": [], "source": "rules"}
    if not enabled():
        words = [w for w in question.lower().replace("?", "").split() if len(w) > 3]
        hits = [e for e in entries if any(w in e["text"].lower() for w in words)][:3]
        if not hits:
            return {"answer": "I couldn't find that in what Mom shared. (Add an Anthropic API key for smarter answers.)",
                    "source_ids": [], "source": "rules"}
        return {"answer": " ".join(f"{e['when']}: {e['text']}" for e in hits),
                "source_ids": [e["id"] for e in hits], "source": "rules"}
    listing = "\n".join(f"[{e['id']}] {e['when']}: {e['text']}" for e in entries)
    try:
        response = client().messages.parse(
            model=MODEL,
            max_tokens=3000,
            system=ASK_SYSTEM,
            messages=[{"role": "user", "content": f"Entries:\n{listing}\n\nQuestion: {question}"}],
            output_format=Answer,
            output_config={"effort": "low"},
            **_FALLBACK,
        )
        if response.stop_reason == "refusal" or response.parsed_output is None:
            return {"answer": "I can't answer that one.", "source_ids": [], "source": "claude"}
        return {**response.parsed_output.model_dump(), "source": "claude"}
    except anthropic.APIError as e:
        log.warning("ask failed: %s", e)
        return {"answer": "The assistant is not reachable right now.", "source_ids": [], "source": "error"}
