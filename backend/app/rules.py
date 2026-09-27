"""Keyword rules used when Claude is not configured (no ANTHROPIC_API_KEY)
or not reachable. Same behaviour as the app's offline extractor."""

from __future__ import annotations

import re
from datetime import date, timedelta

MEDICINES = {
    "l": ("Lisinopril", "10 mg"),
    "v": ("Vitamin D", "1000 IU"),
    "m": ("Metformin", "500 mg"),
    "a": ("Atorvastatin", "20 mg"),
}

_ALIASES = {
    "Lisinopril": ["lisinopril", "blood pressure"],
    "Metformin": ["metformin", "sugar pill", "diabetes"],
    "Atorvastatin": ["atorvastatin", "cholesterol"],
    "Vitamin D": ["vitamin d"],
}
_WEEKDAYS = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
_EVENT_WORDS = ["visit", "coming", "appointment", "doctor", "dr.", "dr ", "party", "birthday",
                "lunch", "dinner", "meet", "pick me up", "check-up", "checkup"]
_SYMPTOMS = {
    "dizzy": ["dizzy", "dizziness", "lightheaded"],
    "pain": ["pain", "hurts", "ache"],
    "tired": ["tired", "exhausted", "no energy"],
    "fall": ["fell", "fall down", "tripped"],
    "sleep": ["couldn't sleep", "could not sleep", "slept badly", "bad sleep"],
}


def _next_weekday(today: date, weekday: int) -> date:
    add = (weekday - today.weekday()) % 7 or 7
    return today + timedelta(days=add)


def extract(text: str, today: date) -> dict:
    sentences = [s.strip() for s in re.split(r"(?<=[.!?])\s+", text) if s.strip()]
    updates: list[dict] = []

    for name, dose in MEDICINES.values():
        for s in sentences:
            sl = s.lower()
            if not any(a in sl for a in _ALIASES[name]):
                continue
            when = None
            if "morning" in sl:
                when = "now mornings"
            if "evening" in sl or "night" in sl:
                when = "now evenings"
            if "stop" in sl:
                when = "stopped"
            if when:
                updates.append({"title": f"{name} {dose}, {when}", "kind": "Medicine change"})
                break

    for s in sentences:
        sl = s.lower()
        idx = next((i for i, d in enumerate(_WEEKDAYS) if d in sl), -1)
        if idx < 0 or not any(w in sl for w in _EVENT_WORDS):
            continue
        if re.search(r"\b(saw|felt|went|was|had)\b", sl) and "coming" not in sl and "will" not in sl:
            continue
        day = _next_weekday(today, idx)
        label = re.sub(r"[.!?]$", "", s.split(",")[0])
        label = re.sub(r"\s+(on\s+)?(next\s+)?" + _WEEKDAYS[idx], "", label, flags=re.I)
        if len(label) > 36:
            label = label[:34].strip() + "..."
        updates.append({"title": f"{label}, {day.strftime('%A %b')} {day.day}", "kind": "Calendar"})

    lower = text.lower()
    flags = [k for k, words in _SYMPTOMS.items() if any(w in lower for w in words)]
    return {"updates": updates, "flags": flags}
