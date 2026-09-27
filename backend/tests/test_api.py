"""End-to-end API tests. Claude is switched off, so AI endpoints use the rules."""

import os
import tempfile

import pytest

os.environ["GRANDVOICE_DB"] = os.path.join(tempfile.mkdtemp(), "test.db")
os.environ.pop("ANTHROPIC_API_KEY", None)
os.environ.pop("ANTHROPIC_AUTH_TOKEN", None)

from fastapi.testclient import TestClient  # noqa: E402

from app import db  # noqa: E402
from app.main import app  # noqa: E402


@pytest.fixture()
def client():
    db.init_db(reset=True)
    with TestClient(app) as c:
        yield c


def login(c, email, password):
    r = c.post("/auth/login", json={"email": email, "password": password})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['token']}"}, r.json()


def test_login_roles_and_bad_password(client):
    _, rosa = login(client, "rosa.m@example.com", "bridge2026")
    _, david = login(client, "david.m@example.com", "familyfirst")
    assert rosa["role"] == "rosa" and david["role"] == "david"
    assert rosa["state"]["diaryName"] == "Rosa Martinez"
    assert client.post("/auth/login", json={"email": "rosa.m@example.com", "password": "nope"}).status_code == 401
    assert client.get("/state").status_code == 401


def test_entry_is_timestamped_and_family_sees_shared_only(client):
    rosa, _ = login(client, "rosa.m@example.com", "bridge2026")
    david, _ = login(client, "david.m@example.com", "familyfirst")

    r = client.post("/entries", headers=rosa, json={
        "id": "e1", "text": "Saw Dr. Patel today.", "shared": True, "duration_seconds": 31,
        "updates": [{"title": "Lisinopril 10 mg, now mornings", "kind": "Medicine change"}],
    })
    assert r.status_code == 200
    e1 = next(e for e in r.json()["entries"] if e["id"] == "e1")
    assert e1["createdAt"][:10] == db.now().date().isoformat()
    assert "+" in e1["createdAt"] or "-" in e1["createdAt"][10:]  # has a UTC offset
    client.post("/entries", headers=rosa, json={"id": "e2", "text": "Private thought.", "shared": False})

    fam = client.get("/state", headers=david).json()
    by_id = {e["id"]: e for e in fam["entries"]}
    assert by_id["e1"]["text"] == "Saw Dr. Patel today."
    assert by_id["e2"]["text"] == ""  # private: time only, no words
    assert fam["changes"][0]["title"] == "Lisinopril 10 mg, now mornings"
    assert fam["famNotes"][0]["text"] == "Rosa journaled (private)"
    # Entries come newest first.
    dates = [e["createdAt"] for e in fam["entries"]]
    assert dates == sorted(dates, reverse=True)


def test_family_actions_reach_rosa(client):
    rosa, _ = login(client, "rosa.m@example.com", "bridge2026")
    david, _ = login(client, "david.m@example.com", "familyfirst")

    client.post("/reminders", headers=david, json={"kind": "med"})
    client.post("/notes", headers=david, json={"kind": "voice", "say": "Hi Mom"})
    state = client.get("/state", headers=rosa).json()
    assert state["medRemind"]["who"] == "David"
    assert state["notes"][0]["say"] == "Hi Mom"

    state = client.post("/doses", headers=rosa, json={"med_id": "m", "taken": True}).json()
    assert state["takenAt"]["m"] and state["medRemind"] is None
    client.post("/notes/love-back", headers=rosa)
    assert client.get("/state", headers=david).json()["famNotes"][0]["text"] == "Mom sent love back"

    # Roles are enforced.
    assert client.post("/entries", headers=david, json={"text": "x"}).status_code == 403
    assert client.post("/reminders", headers=rosa, json={"kind": "day"}).status_code == 403


def test_signup_and_join_request(client):
    r = client.post("/auth/signup", json={"name": "Priya Shah", "email": "priya@example.com",
                                          "password": "longpass1", "role": "family"})
    assert r.status_code == 200
    priya = {"Authorization": f"Bearer {r.json()['token']}"}
    assert r.json()["state"]["connected"] is False

    r = client.post("/fam-requests", headers=priya, json={"name": "Rosa", "contact": "rosa.m@example.com", "rel": "Mom"})
    assert r.json()["famRequest"]["status"] == "pending"

    rosa, _ = login(client, "rosa.m@example.com", "bridge2026")
    client.post("/fam-requests/answer", headers=rosa, json={"accept": True})
    state = client.get("/state", headers=priya).json()
    assert state["connected"] is True and state["diaryName"] == "Rosa Martinez"


def test_ai_endpoints_fall_back_to_rules(client):
    rosa, _ = login(client, "rosa.m@example.com", "bridge2026")
    r = client.post("/analyze", headers=rosa, json={
        "text": "She moved my blood pressure pill to the morning. Maya is coming to visit on Sunday. I felt dizzy."})
    body = r.json()
    assert body["source"] == "rules"
    assert body["updates"][0]["title"] == "Lisinopril 10 mg, now mornings"
    assert body["updates"][1]["kind"] == "Calendar"
    assert body["flags"] == ["dizzy"]

    ans = client.post("/ask", headers=rosa, json={"question": "When was she dizzy?"}).json()
    assert ans["source_ids"] == ["seed3"] and ans["sources"]
    assert client.get("/digest", headers=rosa).json()["source"] == "rules"
