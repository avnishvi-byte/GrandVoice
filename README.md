# Grandvoice

Speak your day. Family stays close.

An older adult talks about their day. The app turns it into a dated journal
entry, picks out medicine changes and visits, and shares it with family, who
can send love, reminders and voice replies back.

```
mobile/    Flutter app (Android, iOS, web): the diary side and the family side
backend/   FastAPI + SQLite API, with Claude for summaries and "Ask about Mom"
```

## Run it

**1. Backend**

```bash
cd backend
python -m venv .venv
.venv\Scripts\pip install -r requirements.txt      # macOS/Linux: .venv/bin/pip
.venv\Scripts\python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

API docs: http://localhost:8000/docs. To turn on Claude, set `ANTHROPIC_API_KEY`
before starting (without it, the AI features use simple keyword rules).

**2. App**

```bash
cd mobile
flutter pub get
flutter run -d chrome        # or plug in an Android phone and run: flutter run
```

On a real phone, open the `...` menu (or "Server settings" on sign-in) and set the
server to your laptop's Wi-Fi address, e.g. `http://192.168.1.20:8000`.

## Demo accounts

| Person | Email | Password |
|---|---|---|
| Rosa (diary) | rosa.m@example.com | bridge2026 |
| David (family) | david.m@example.com | familyfirst |

## Tests

```bash
cd backend && .venv\Scripts\python -m pytest
cd mobile && flutter test
```
