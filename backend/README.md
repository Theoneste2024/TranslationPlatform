# Django backend

The Django API contains the text, speech, and video translation services. Its
routes preserve the Flutter app's existing request, response, and video-stream
formats; Firebase Functions configuration and handlers have been removed.

## Local setup (PowerShell)

Create a MySQL database, then create a `.env` file in this directory with the
database settings (`DB_ENGINE`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DB_HOST`,
and `DB_PORT`), `OPENAI_API_KEY`, and the appropriate Django settings. Copy the
SMTP setting names from `.env.example` and fill them with your provider
credentials. Email verification and password reset require SMTP. Phone numbers
must use E.164 format (for example, `+12025550143`). Then from this directory:

```powershell
py -3.12 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
python manage.py migrate
python manage.py runserver 0.0.0.0:8000
```

Install FFmpeg and add it to `PATH` for video uploads that need audio extraction.

For backend tests without a running MySQL server, set `$env:DB_ENGINE = "sqlite"`
before running `python manage.py test`.

## API routes

- `GET /api/v1/health/`
- `POST /api/v1/translate_text/`
- `POST /api/v1/translate_text/speech/`
- `POST /api/v1/speech_translate/`
- `POST /api/v1/analyze_video/`
- `POST /api/v1/auth/register/`
- `GET /api/v1/auth/verify-email/<token>/`
- `POST /api/v1/auth/verify-email/resend/`
- `POST /api/v1/auth/token/`
- `POST /api/v1/auth/token/refresh/`
- `POST /api/v1/auth/password-reset/`
- `POST /api/v1/auth/password-reset/confirm/<uidb64>/<token>/`
- `GET /api/v1/auth/me/` (JWT required)

The translation routes preserve the existing request and response formats.
Text Translation speech is generated on demand by
`POST /api/v1/translate_text/speech/`, which accepts translated `text` and
`target_language` and returns base64-encoded MP3 audio. It uses the
`gpt-4o-mini-tts` model and the server-side `OPENAI_API_KEY`. OpenAI currently
plans to retire this model on January 6, 2027, so the speech provider will need
to be migrated before then.
Registration requires `email`, `username`, `phone_number`, `gender`, `password`,
and `confirm_password`. Gender values are `male`, `female`, `other`, and
`prefer_not_to_say`. Registration sends an email verification link and does not
issue tokens until the email is verified. Sign-in accepts an `identifier`
containing either an email or an E.164 phone number plus `password`, and issues
JWTs directly after successful authentication. Password reset links are sent
by email.

The current user model uses the `users_user` table. The initial migrations
create this table and the translation tables for a fresh database; they do not
reuse the legacy `accounts_user` table. This migration history is intended for
a fresh local database. Back up any database you need to keep before resetting
it, and use a separate data migration if legacy account records must be
preserved.

Set `DJANGO_DEBUG=false`, `DJANGO_SECRET_KEY`, `DJANGO_ALLOWED_HOSTS`, and
`CORS_ALLOWED_ORIGINS` in production. Keep database and API credentials in
environment variables, not in source files.
