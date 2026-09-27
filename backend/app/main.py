"""Grandvoice API.

Run:  uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
Docs: http://localhost:8000/docs

Most write endpoints return the caller's full state (same shape the app
keeps on the phone), so the app can simply replace what it has.
"""

from __future__ import annotations

import json
from datetime import datetime
import re
import sqlite3
from collections.abc import Iterator
from contextlib import asynccontextmanager
from typing import Literal

from fastapi import Depends, FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from . import ai, db
from .auth import check_password, hash_password, new_token
from .rules import MEDICINES


@asynccontextmanager
async def lifespan(_: FastAPI):
    db.init_db()
    yield


app = FastAPI(title="Grandvoice API", version="1.0", lifespan=lifespan)

# The Flutter web build runs on another port; tokens go in a header (no
# cookies), so allowing any origin is safe here.
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])


# ---------------------------------------------------------------- plumbing

def get_conn() -> Iterator[sqlite3.Connection]:
    conn = db.connect()
    try:
        yield conn
    finally:
        conn.close()


class User(BaseModel):
    id: int
    email: str
    name: str
    role: Literal["diary", "family"]
    household_id: int | None
    pending_household_id: int | None


def current_user(
    authorization: str = Header(default=""),
    conn: sqlite3.Connection = Depends(get_conn),
) -> User:
    token = authorization.removeprefix("Bearer ").strip()
    row = conn.execute(
        "SELECT u.* FROM sessions s JOIN users u ON u.id = s.user_id WHERE s.token = ?", (token,)
    ).fetchone()
    if row is None:
        raise HTTPException(401, "Please sign in again.")
    return User(**{k: row[k] for k in row.keys() if k != "password_hash"})


def household_of(user: User) -> int:
    if user.household_id is None:
        raise HTTPException(403, "You are not connected to anyone yet.")
    return user.household_id


def diary_only(user: User = Depends(current_user)) -> User:
    if user.role != "diary":
        raise HTTPException(403, "Only the diary keeper can do this.")
    household_of(user)
    return user


def family_only(user: User = Depends(current_user)) -> User:
    if user.role != "family":
        raise HTTPException(403, "Only family members can do this.")
    household_of(user)
    return user


def first(name: str) -> str:
    return name.strip().split(" ")[0]


def diary_user(conn: sqlite3.Connection, household_id: int) -> sqlite3.Row:
    return conn.execute(
        "SELECT u.* FROM households h JOIN users u ON u.id = h.diary_user_id WHERE h.id = ?",
        (household_id,),
    ).fetchone()


def entry_json(row: sqlite3.Row, hide_text: bool = False) -> dict:
    return {
        "id": row["id"],
        "text": "" if hide_text else row["text"],
        "createdAt": row["created_at"],
        "shared": bool(row["shared"]),
        "kind": row["kind"],
        "title": row["title"],
        "durationSeconds": row["duration_seconds"],
        "flags": json.loads(row["flags_json"]),
    }


def build_state(conn: sqlite3.Connection, user: User) -> dict:
    """Everything the app shows, from this user's point of view."""
    if user.household_id is None:
        # A family member whose join request hasn't been accepted yet.
        req = None
        if user.pending_household_id:
            req = db.load_state(conn, user.pending_household_id).get("famRequest")
        return {**db.empty_state(), "role": "david", "diaryName": req["name"] if req else "",
                "familyName": user.name, "entries": [], "famRequest": req, "connected": False}

    hh = user.household_id
    state = db.load_state(conn, hh)
    diary = diary_user(conn, hh)
    is_family = user.role == "family"
    rows = conn.execute("SELECT * FROM entries WHERE household_id = ? ORDER BY created_at DESC", (hh,)).fetchall()
    # Family sees private entries only as "journaled at <time>", never the words.
    entries = [entry_json(r, hide_text=is_family and not r["shared"]) for r in rows]
    if is_family:
        family_name = user.name
    else:
        fam = conn.execute(
            "SELECT name FROM users WHERE household_id = ? AND role = 'family' ORDER BY id LIMIT 1", (hh,)
        ).fetchone()
        family_name = fam["name"] if fam else "Family"
    return {
        **state,
        "role": "david" if is_family else "rosa",
        "diaryName": diary["name"],
        "familyName": family_name,
        "entries": entries,
        "connected": True,
    }


def change_state(conn: sqlite3.Connection, user: User, fn) -> dict:
    """Load the household state, let `fn` edit it, save, return the caller's view."""
    hh = household_of(user)
    state = db.load_state(conn, hh)
    fn(state)
    db.save_state(conn, hh, state)
    conn.commit()
    return build_state(conn, user)


def fam_note(state: dict, text: str) -> None:
    state["famNotes"].insert(0, {"text": text, "at": db.iso(db.now())})
    del state["famNotes"][30:]


# ---------------------------------------------------------------- auth

class LoginIn(BaseModel):
    email: str
    password: str


class SignupIn(LoginIn):
    name: str = Field(min_length=1)
    role: Literal["diary", "family"]


class AuthOut(BaseModel):
    token: str
    role: Literal["rosa", "david"]
    state: dict


def _session(conn: sqlite3.Connection, user_id: int) -> str:
    token = new_token()
    conn.execute("INSERT INTO sessions (token, user_id, created_at) VALUES (?, ?, ?)",
                 (token, user_id, db.iso(db.now())))
    conn.commit()
    return token


def _user(conn: sqlite3.Connection, user_id: int) -> User:
    row = conn.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
    return User(**{k: row[k] for k in row.keys() if k != "password_hash"})


@app.post("/auth/login", response_model=AuthOut, tags=["auth"])
def login(body: LoginIn, conn: sqlite3.Connection = Depends(get_conn)):
    row = conn.execute("SELECT * FROM users WHERE email = ?", (body.email.strip().lower(),)).fetchone()
    if row is None or not check_password(body.password, row["password_hash"]):
        raise HTTPException(401, "That email and password don't match.")
    user = _user(conn, row["id"])
    return AuthOut(token=_session(conn, user.id), role="rosa" if user.role == "diary" else "david",
                   state=build_state(conn, user))


@app.post("/auth/signup", response_model=AuthOut, tags=["auth"])
def signup(body: SignupIn, conn: sqlite3.Connection = Depends(get_conn)):
    email = body.email.strip().lower()
    if not re.match(r"^[^@\s]+@[^@\s]+\.[^@\s]+$", email):
        raise HTTPException(400, "Please check the email address.")
    if len(body.password) < 8:
        raise HTTPException(400, "Use at least 8 letters or numbers.")
    if conn.execute("SELECT 1 FROM users WHERE email = ?", (email,)).fetchone():
        raise HTTPException(409, "That email already has an account. Try signing in.")
    cur = conn.execute("INSERT INTO users (email, name, password_hash, role) VALUES (?, ?, ?, ?)",
                       (email, body.name.strip(), hash_password(body.password), body.role))
    user_id = cur.lastrowid
    if body.role == "diary":
        cur = conn.execute("INSERT INTO households (diary_user_id, state_json) VALUES (?, ?)",
                           (user_id, json.dumps(db.empty_state())))
        conn.execute("UPDATE users SET household_id = ? WHERE id = ?", (cur.lastrowid, user_id))
    conn.commit()
    user = _user(conn, user_id)
    return AuthOut(token=_session(conn, user.id), role="rosa" if user.role == "diary" else "david",
                   state=build_state(conn, user))


@app.post("/auth/logout", tags=["auth"])
def logout(authorization: str = Header(default=""), conn: sqlite3.Connection = Depends(get_conn)):
    conn.execute("DELETE FROM sessions WHERE token = ?", (authorization.removeprefix("Bearer ").strip(),))
    conn.commit()
    return {"ok": True}


# ---------------------------------------------------------------- state

@app.get("/health", tags=["meta"])
def health():
    return {"ok": True, "claude": ai.enabled(), "model": ai.MODEL if ai.enabled() else None}


@app.get("/state", tags=["state"])
def get_state(user: User = Depends(current_user), conn: sqlite3.Connection = Depends(get_conn)):
    return build_state(conn, user)


# ---------------------------------------------------------------- journal (Rosa)

class UpdateIn(BaseModel):
    title: str
    kind: str


class EntryIn(BaseModel):
    id: str | None = None
    text: str = Field(min_length=1)
    shared: bool = True
    duration_seconds: int = 0
    updates: list[UpdateIn] = []
    flags: list[str] = []


@app.post("/entries", tags=["journal"])
def add_entry(body: EntryIn, user: User = Depends(diary_only), conn: sqlite3.Connection = Depends(get_conn)):
    """Save a diary entry. The server stamps the date and time."""
    hh = household_of(user)
    now = db.iso(db.now())
    entry_id = body.id or new_token()[:16]
    conn.execute(
        "INSERT OR IGNORE INTO entries (id, household_id, kind, text, shared, duration_seconds, flags_json, created_at)"
        " VALUES (?, ?, 'day', ?, ?, ?, ?, ?)",
        (entry_id, hh, body.text.strip(), int(body.shared), body.duration_seconds, json.dumps(body.flags), now),
    )

    def edit(state: dict) -> None:
        for u in body.updates:
            state["changes"].insert(0, {"title": u.title, "kind": u.kind, "at": now})
        del state["changes"][20:]
        state["remind"] = None
        fam_note(state, f"{first(user.name)} shared her day" if body.shared else f"{first(user.name)} journaled (private)")

    return change_state(conn, user, edit)


class SharedIn(BaseModel):
    shared: bool


@app.patch("/entries/{entry_id}", tags=["journal"])
def set_shared(entry_id: str, body: SharedIn, user: User = Depends(diary_only),
               conn: sqlite3.Connection = Depends(get_conn)):
    conn.execute("UPDATE entries SET shared = ? WHERE id = ? AND household_id = ?",
                 (int(body.shared), entry_id, user.household_id))
    conn.commit()
    return build_state(conn, user)


@app.delete("/entries/{entry_id}", tags=["journal"])
def delete_entry(entry_id: str, user: User = Depends(diary_only), conn: sqlite3.Connection = Depends(get_conn)):
    conn.execute("DELETE FROM entries WHERE id = ? AND household_id = ?", (entry_id, user.household_id))
    conn.commit()
    return build_state(conn, user)


class StoryIn(BaseModel):
    id: str | None = None
    title: str
    text: str = Field(min_length=1)
    duration_seconds: int = 0


@app.post("/stories", tags=["journal"])
def add_story(body: StoryIn, user: User = Depends(diary_only), conn: sqlite3.Connection = Depends(get_conn)):
    conn.execute(
        "INSERT OR IGNORE INTO entries (id, household_id, kind, title, text, shared, duration_seconds, created_at)"
        " VALUES (?, ?, 'story', ?, ?, 1, ?, ?)",
        (body.id or new_token()[:16], user.household_id, body.title, body.text.strip(),
         body.duration_seconds, db.iso(db.now())),
    )
    return change_state(conn, user, lambda s: fam_note(s, f"Mom added a Life Story: {body.title}"))


# ---------------------------------------------------------------- medicines

class DoseIn(BaseModel):
    med_id: Literal["l", "v", "m", "a"]
    taken: bool


@app.post("/doses", tags=["medicines"])
def set_dose(body: DoseIn, user: User = Depends(diary_only), conn: sqlite3.Connection = Depends(get_conn)):
    def edit(state: dict) -> None:
        state["takenAt"][body.med_id] = db.iso(db.now()) if body.taken else None
        if body.taken:
            fam_note(state, f"{first(user.name)} took {MEDICINES[body.med_id][0]}")
            if body.med_id == "m":
                state["medRemind"] = None

    return change_state(conn, user, edit)


# ---------------------------------------------------------------- family → Rosa

class ReminderIn(BaseModel):
    kind: Literal["day", "med"]


@app.post("/reminders", tags=["family"])
def send_reminder(body: ReminderIn, user: User = Depends(family_only), conn: sqlite3.Connection = Depends(get_conn)):
    key = "remind" if body.kind == "day" else "medRemind"

    def edit(state: dict) -> None:
        if state[key] is None:
            state[key] = {"who": first(user.name), "at": db.iso(db.now())}

    return change_state(conn, user, edit)


class NoteIn(BaseModel):
    kind: Literal["love", "voice"]
    say: str | None = None


@app.post("/notes", tags=["family"])
def send_note(body: NoteIn, user: User = Depends(family_only), conn: sqlite3.Connection = Depends(get_conn)):
    who = first(user.name)
    text = f"{who} sent you love" if body.kind == "love" else f"Voice message from {who}"

    def edit(state: dict) -> None:
        state["notes"].insert(0, {"kind": body.kind, "text": text, "at": db.iso(db.now()),
                                  "say": body.say, "thanked": False, "lovedBack": False})
        del state["notes"][20:]

    return change_state(conn, user, edit)


@app.post("/notes/thank", tags=["family"])
def thank_note(user: User = Depends(diary_only), conn: sqlite3.Connection = Depends(get_conn)):
    def edit(state: dict) -> None:
        if state["notes"] and not state["notes"][0]["thanked"]:
            state["notes"][0]["thanked"] = True
            fam_note(state, f"{first(user.name)} says thank you, dear")

    return change_state(conn, user, edit)


@app.post("/notes/love-back", tags=["family"])
def love_back(user: User = Depends(diary_only), conn: sqlite3.Connection = Depends(get_conn)):
    def edit(state: dict) -> None:
        if state["notes"] and not state["notes"][0]["lovedBack"]:
            state["notes"][0].update(lovedBack=True, thanked=True)
            fam_note(state, "Mom sent love back")

    return change_state(conn, user, edit)


# ---------------------------------------------------------------- circle

class FamRequestIn(BaseModel):
    name: str
    contact: str
    rel: str


@app.post("/fam-requests", tags=["circle"])
def request_to_join(body: FamRequestIn, user: User = Depends(current_user),
                    conn: sqlite3.Connection = Depends(get_conn)):
    """A family member asks to join a diary keeper's circle (found by email)."""
    if user.role != "family":
        raise HTTPException(403, "Only family members can send a request.")
    target = conn.execute("SELECT * FROM users WHERE email = ? AND role = 'diary'",
                          (body.contact.strip().lower(),)).fetchone()
    if target is None:
        raise HTTPException(404, "No Grandvoice diary uses that email yet.")
    hh = target["household_id"]
    state = db.load_state(conn, hh)
    state["famRequest"] = {"from": first(user.name), "fromUserId": user.id, "name": body.name,
                           "rel": body.rel, "at": db.iso(db.now()), "status": "pending", "respondedAt": None}
    state["famRequestSeen"] = False
    db.save_state(conn, hh, state)
    if user.household_id != hh:
        conn.execute("UPDATE users SET pending_household_id = ? WHERE id = ?", (hh, user.id))
    conn.commit()
    return build_state(conn, _user(conn, user.id))


class AnswerIn(BaseModel):
    accept: bool


@app.post("/fam-requests/answer", tags=["circle"])
def answer_request(body: AnswerIn, user: User = Depends(diary_only), conn: sqlite3.Connection = Depends(get_conn)):
    hh = household_of(user)
    state = db.load_state(conn, hh)
    req = state.get("famRequest")
    if not req:
        raise HTTPException(404, "There is no request to answer.")
    req.update(status="accepted" if body.accept else "declined", respondedAt=db.iso(db.now()))
    if body.accept:
        if req.get("fromUserId"):
            conn.execute("UPDATE users SET household_id = ?, pending_household_id = NULL WHERE id = ?",
                         (hh, req["fromUserId"]))
        if not any(c["name"] == req["from"] for c in state["circle"]):
            state["circle"].insert(0, {"name": req["from"], "relation": "Family", "pending": False})
    db.save_state(conn, hh, state)
    conn.commit()
    return build_state(conn, user)


@app.post("/fam-requests/seen", tags=["circle"])
def request_seen(user: User = Depends(diary_only), conn: sqlite3.Connection = Depends(get_conn)):
    return change_state(conn, user, lambda s: s.update(famRequestSeen=True))


class InviteIn(BaseModel):
    email: str
    relation: str


@app.post("/circle", tags=["circle"])
def invite(body: InviteIn, user: User = Depends(diary_only), conn: sqlite3.Connection = Depends(get_conn)):
    if not re.match(r"^[^@\s]+@[^@\s]+\.[^@\s]+$", body.email.strip()):
        raise HTTPException(400, "Please check the email address.")
    return change_state(conn, user, lambda s: s["circle"].append(
        {"name": body.email.strip(), "relation": body.relation, "pending": True}))


# ---------------------------------------------------------------- AI

class AnalyzeIn(BaseModel):
    text: str


@app.post("/analyze", tags=["ai"])
def analyze(body: AnalyzeIn, user: User = Depends(current_user)):
    """Transcript → summary, medicine/calendar updates and symptom flags (Claude)."""
    return ai.analyze(body.text, db.now().date())


def _shared_entries(conn: sqlite3.Connection, hh: int, only_today: bool) -> list[dict]:
    rows = conn.execute(
        "SELECT * FROM entries WHERE household_id = ? AND shared = 1 AND kind = 'day' ORDER BY created_at DESC LIMIT 60",
        (hh,),
    ).fetchall()
    today = db.now().date()
    out = []
    for r in rows:
        t = datetime.fromisoformat(r["created_at"]).astimezone()
        if only_today and t.date() != today:
            continue
        clock = f"{t.hour % 12 or 12}:{t.minute:02d} {'AM' if t.hour < 12 else 'PM'}"
        out.append({"id": r["id"], "text": r["text"], "time": clock,
                    "when": f"{t.strftime('%a %b')} {t.day}, {clock}"})
    return out


@app.get("/digest", tags=["ai"])
def digest(user: User = Depends(current_user), conn: sqlite3.Connection = Depends(get_conn)):
    """Tonight's digest for family: a Claude summary of today's shared entries."""
    hh = household_of(user)
    state = db.load_state(conn, hh)
    taken = [MEDICINES[k][0] for k, v in state["takenAt"].items() if v]
    missing = [MEDICINES[k][0] for k, v in state["takenAt"].items() if not v]
    meds_line = f"taken: {', '.join(taken) or 'none'}; not yet: {', '.join(missing) or 'none'}"
    return ai.digest(_shared_entries(conn, hh, only_today=True), meds_line)


class AskIn(BaseModel):
    question: str = Field(min_length=2)


@app.post("/ask", tags=["ai"])
def ask(body: AskIn, user: User = Depends(current_user), conn: sqlite3.Connection = Depends(get_conn)):
    """Ask about Mom: answered only from what she shared."""
    entries = _shared_entries(conn, household_of(user), only_today=False)
    result = ai.ask(body.question, entries)
    whens = {e["id"]: e["when"] for e in entries}
    result["sources"] = [whens[i] for i in result.get("source_ids", []) if i in whens]
    return result


# ---------------------------------------------------------------- demo

@app.post("/demo/reset", tags=["meta"])
def reset_demo():
    """Wipe everything and restore the Rosa + David sample data."""
    db.init_db(reset=True)
    return {"ok": True}
