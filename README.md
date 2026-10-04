# AICSSYC 2026 QR Scanner (Flutter Android)

Companion Android scanning app for AICSSYC 2026 registration check-in and meal access control with offline-first synchronization.

## Features

- **High-speed QR Code Scanning**: Camera-based continuous QR code detection with flashlight toggle.
- **Dual Operating Modes**:
  - **Check-in Mode**: Attendee check-in with registration verification.
  - **Meal Distribution Mode**: Real-time meal access verification across all event meal sessions.
- **Offline-First Synchronization**:
  - Embedded local SQLite database mirroring Supabase state.
  - Offline action queueing when network connection drops.
  - Automatic bidirectional delta synchronization when network is restored.
- **Audio & Haptic Feedback**: Frequency-accurate chimes and vibrations for success, warning, and error states.
- **Device Identity Tracking**: Random 6-digit persistent device identifier logged against all transactions.
- **Security & RLS**: Role-based access control and staff passcode protection.

## Setup & Configuration

### 1. Configure Environment Variables
Copy `.env.example` to `.env`:

```bash
cp .env.example .env
```

Edit `.env` with your project's configuration:

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your-supabase-key-or-service-role-key
TEAM_PASSCODE=Your Password
```

> **Security Note**: Never commit `.env` or sensitive keys to version control. The `.gitignore` file is pre-configured to ignore `.env`, `.env.*`, and keystore files.

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Run the App

#### Using VS Code:
Select **qrcode_scanner (Debug)** from the Run & Debug menu or press `F5`.

#### Using Flutter CLI:

```bash
flutter run --dart-define-from-file=.env
```

### 4. Build Release APK

```bash
flutter build apk --dart-define-from-file=.env
```

The compiled APK will be generated at `build/app/outputs/flutter-apk/app-release.apk`.
