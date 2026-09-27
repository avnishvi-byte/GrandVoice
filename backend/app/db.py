"""SQLite storage.

Tables:
  users       one row per person (diary keeper or family member)
  sessions    login tokens
  households  a diary keeper and the family who can see her day.
              Small, changing things (medicines taken today, reminders,
              love notes, circle, recent changes) live in `state_json`.
  entries     journal entries and Life Stories, one row each, so they can be
              queried and sorted by date.
"""

from __future__ import annotations

import json
import os
import sqlite3
from datetime import datetime, timedelta
from pathlib import Path

from .auth import hash_password

DB_PATH = Path(os.environ.get("GRANDVOICE_DB", Path(__file__).resolve().parent.parent / "grandvoice.db"))

SCHEMA = """
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    password_hash TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('diary', 'family')),
    household_id INTEGER,
    pending_household_id INTEGER
);
CREATE TABLE IF NOT EXISTS sessions (
    token TEXT PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id),
    created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS households (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    diary_user_id INTEGER NOT NULL REFERENCES users(id),
    state_json TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS entries (
    id TEXT PRIMARY KEY,
    household_id INTEGER NOT NULL REFERENCES households(id),
    kind TEXT NOT NULL DEFAULT 'day',
    title TEXT,
    text TEXT NOT NULL,
    shared INTEGER NOT NULL DEFAULT 0,
    duration_seconds INTEGER NOT NULL DEFAULT 0,
    flags_json TEXT NOT NULL DEFAULT '[]',
    created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS entries_by_day ON entries (household_id, created_at);
"""


def now() -> datetime:
    """Current time with the server's UTC offset, e.g. 2026-09-26T12:26:00+05:30."""
    return datetime.now().astimezone().replace(microsecond=0)


def iso(t: datetime) -> str:
    return t.isoformat()


def connect() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def empty_state() -> dict:
    return {
        "takenAt": {"l": None, "v": None, "m": None, "a": None},
        "takenDay": "",
        "remind": None,
        "medRemind": None,
        "notes": [],
        "famNotes": [],
        "famRequest": None,
        "famRequestSeen": True,
        "circle": [],
        "changes": [],
    }


def init_db(reset: bool = False) -> None:
    conn = connect()
    with conn:
        if reset:
            conn.executescript(
                "DROP TABLE IF EXISTS entries; DROP TABLE IF EXISTS sessions;"
                "DROP TABLE IF EXISTS households; DROP TABLE IF EXISTS users;"
            )
        conn.executescript(SCHEMA)
        if conn.execute("SELECT COUNT(*) FROM users").fetchone()[0] == 0:
            seed(conn)
    conn.close()


def seed(conn: sqlite3.Connection) -> None:
    """Demo household: Rosa keeps the diary, David is her son."""
    cur = conn.execute(
        "INSERT INTO users (email, name, password_hash, role) VALUES (?, ?, ?, 'diary')",
        ("rosa.m@example.com", "Rosa Martinez", hash_password("bridge2026")),
    )
    rosa_id = cur.lastrowid
    state = empty_state()
    state["circle"] = [
        {"name": "David", "relation": "Son", "pending": False},
        {"name": "Maya", "relation": "Granddaughter", "pending": False},
        {"name": "ana.r@example.com", "relation": "Caregiver", "pending": True},
    ]
    cur = conn.execute(
        "INSERT INTO households (diary_user_id, state_json) VALUES (?, ?)",
        (rosa_id, json.dumps(state)),
    )
    hh = cur.lastrowid
    conn.execute("UPDATE users SET household_id = ? WHERE id = ?", (hh, rosa_id))
    conn.execute(
        "INSERT INTO users (email, name, password_hash, role, household_id) VALUES (?, ?, ?, 'family', ?)",
        ("david.m@example.com", "David Martinez", hash_password("familyfirst"), hh),
    )

    today = now().replace(hour=0, minute=0, second=0)

    def at(days_ago: int, h: int, m: int) -> str:
        return iso(today - timedelta(days=days_ago) + timedelta(hours=h, minutes=m))

    rows = [
        ("seed1", "day", None, False, [], at(1, 19, 40),
         "Quiet evening. I miss Walter's piano on nights like this. "
         "He used to play Moon River after dinner. The house feels very still now."),
        ("seed2", "day", None, True, [], at(1, 9, 5),
         "Walked to the garden with Linda. Tomatoes are finally red. "
         "We picked six. Linda is making sauce on Saturday."),
        ("seed3", "day", None, True, ["dizzy"], at(3, 18, 20),
         "Maya called. She got the part in the school play. She is going to be the "
         "narrator. I will sit in the front row. Felt a little dizzy after lunch but "
         "it passed when I sat down."),
        ("story1", "story", "How I met Walter", True, [], at(15, 16, 0),
         "It was a church dance in 1968. He stepped on my foot twice and apologised "
         "so sweetly that I agreed to a second dance."),
        ("story2", "story", "Our first winter in Chicago", True, [], at(22, 16, 0),
         "We had one coat between us that first winter and took turns wearing it to the bus stop."),
        ("story3", "story", "Sunday dinners at Mama's", True, [], at(29, 16, 0),
         "Every Sunday the whole family squeezed into Mama's kitchen. "
         "There was always more food than chairs."),
    ]
    conn.executemany(
        "INSERT INTO entries (id, household_id, kind, title, shared, flags_json, created_at, text)"
        " VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        [(i, hh, k, t, int(s), json.dumps(f), c, x) for i, k, t, s, f, c, x in rows],
    )


# ---------- household state helpers ----------

def load_state(conn: sqlite3.Connection, household_id: int) -> dict:
    row = conn.execute("SELECT state_json FROM households WHERE id = ?", (household_id,)).fetchone()
    state = {**empty_state(), **json.loads(row["state_json"])}
    return roll_over_day(conn, household_id, state)


def save_state(conn: sqlite3.Connection, household_id: int, state: dict) -> None:
    conn.execute("UPDATE households SET state_json = ? WHERE id = ?", (json.dumps(state), household_id))


def roll_over_day(conn: sqlite3.Connection, household_id: int, state: dict) -> dict:
    """On a new day, reset medicines and the day's reminders."""
    today = now().date().isoformat()
    if state.get("takenDay") == today:
        return state
    morning = iso(now().replace(hour=8, minute=12, second=0))
    # Demo default: the two 8 AM medicines were already taken.
    state["takenAt"] = {"l": morning, "v": morning, "m": None, "a": None}
    state["takenDay"] = today
    state["remind"] = None
    state["medRemind"] = None
    save_state(conn, household_id, state)
    conn.commit()
    return state
