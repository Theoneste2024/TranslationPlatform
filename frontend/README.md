# Translation Platform

A Flutter mobile application for multilingual translation.

## Features

- Text Translation
- Speech Translation
- Driver Mode
- Camera Translation
- Offline Translation (Pack)
- Education Tools
- Google Maps

## Technologies Used

- Flutter
- Dart
- REST API

## Developer
Theoneste Isezerano  
Data Scientist
0785446324
isezeranotheoneste@gmail.com
primedataconsultinggroup.rw@gmail.com

## Installation

From the repository root, enter `frontend`:

```powershell
cd frontend
flutter pub get
flutter run
```

The local Django API is used by default. Override it for another environment
with `--dart-define=API_BASE_URL=https://your-api-host/api/v1`.

## Accounts and access

Register with an email address, username, international phone number, gender,
and password. A verification email must be confirmed before signing in with
email or phone number and password. Translation features require a valid
account session; JWTs are stored securely and refreshed by the app. Password
reset and verification emails require SMTP to be configured on the backend.
