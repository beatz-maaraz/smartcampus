# AI-Powered Smart Campus Assistant
**Team Artemis • Selvam College of Technology**

A Flutter app matching the Application Flow document: role-based login
(Student / Faculty / Admin), each with its own dashboard, and cross-role
data flows (e.g. Faculty marks attendance → Student % updates instantly).

## Project structure

Per project convention, everything lives flat inside `lib/` — no nested
feature folders:

```
lib/
├── main.dart                 # Entry point, Firebase bootstrap, providers
├── app_router.dart           # go_router — role-based routing (§2)
├── constants.dart            # Colors, roles, demo credentials
├── theme.dart                # App-wide ThemeData
├── models.dart                # All data models (User, Attendance, Fees, ...)
├── auth_service.dart         # Login/logout (demo mode + firebase_auth hook)
├── campus_data_service.dart  # Shared in-memory data layer (Firestore hook)
├── gemini_service.dart       # Chatbot + Chemical Hub AI (firebase_ai hook)
├── widgets.dart              # Shared UI components
├── login_screen.dart         # §2 Login & Authentication
├── student_dashboard.dart    # §3 Student flow
├── faculty_dashboard.dart    # §4 Faculty flow
├── admin_dashboard.dart      # §6 Admin flow
├── timetable_screen.dart     # Full weekly timetable
├── navigation_screen.dart    # Smart/Dynamic Navigation (maps hook)
├── chatbot_screen.dart       # AI Campus Chatbot
├── chemical_hub_screen.dart  # Chemical Hub (camera OCR hook)
└── notice_screen.dart        # Notices / broadcasts
```

## Running it right now (demo mode)

The app runs **without any Firebase setup** out of the box:

- `AuthService.demoMode = true` (in `auth_service.dart`) uses the
  prototype credentials from the Application Flow doc §2.1:

  | Role | ID | Password |
  |---|---|---|
  | Student | `student` | `student123` |
  | Faculty | `faculty` | `faculty123` |
  | Admin | `admin` | `admin123` |

- `CampusDataService` holds all app data in memory (attendance, timetable,
  assignments, materials, fees, events, notices, venues, chemical DB), so
  every cross-role flow (Faculty posts → Student sees) works live in the
  demo without a backend.
- `GeminiService.mockMode = true` gives canned chatbot/chemical-hub replies
  so those screens are fully interactive offline.

```bash
flutter pub get
flutter run
```

## Wiring up the real backend

Each mock/demo spot in the code has a comment showing exactly what to
swap in:

1. **Firebase project** — run `flutterfire configure`, then uncomment the
   `Firebase.initializeApp(...)` block in `main.dart`.
2. **Auth** — set `AuthService.demoMode = false` and fill in
   `_firebaseLogin()` in `auth_service.dart` with `firebase_auth` calls.
3. **Data** — replace the in-memory lists inside `campus_data_service.dart`
   with `cloud_firestore` collection reads/writes (structure is already
   split method-by-method to make this a 1:1 swap).
4. **AI** — set `GeminiService.mockMode = false` and implement
   `_callGemini()` using `firebase_ai` (see the class doc-comment in
   `gemini_service.dart` for the exact snippet).
5. **Maps** — `navigation_screen.dart` has a placeholder map surface;
   swap it for a real `GoogleMap` widget from `google_maps_flutter`
   (snippet included in the file comment). Add your Maps API key to
   Android/iOS config.
6. **Chemical label scanning** — `chemical_hub_screen.dart._scanLabel()`
   is a placeholder; wire up `camera` + `google_mlkit_text_recognition`
   per the comment at the top of that file.
7. **SMS fee reminders** — flagged as an open question in the Application
   Flow doc (§8.2): needs a third-party SMS gateway (Twilio, etc.) or can
   be scoped down to `firebase_messaging` push notifications for the MVP.

## Open items from the Application Flow doc

These are flagged in the source doc (§8) and still need a team decision
before they're implemented for real:

- **§8.1** — Is "Mod" a 4th role, or shorthand for Admin? (Not implemented
  here; only Student/Faculty/Admin exist.)
- **§8.2** — SMS gateway choice for fee reminders.
- **§8.3** — Exact Emergency SOS behavior for the Student role.
- **§8.4** — Scope of camera + OCR/barcode capability for Chemical Hub.
- **§8.5** — Remove/disable demo credentials before any public build.

## Packages

See `pubspec.yaml` — the full stack matches Application Flow §9
(Firebase Core/Auth, Firestore, Storage, `firebase_ai`, Maps/Geolocation,
Camera/ML Kit, Notifications, file handling, `fl_chart`, `provider`,
`go_router`, and utilities).
# smartcampus
