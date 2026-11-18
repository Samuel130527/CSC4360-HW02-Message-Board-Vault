
# Message Board Vault Hunt

## CSC 4360 — Homework 02

A Flutter and Firebase real-time message board application.

### Features
- Firebase Authentication: Register, Login, Logout
- Real-time Cloud Firestore message feed
- Create, Read, Update, and Delete messages
- Owner-only Edit and Delete permissions
- Firestore security rules
- Duplicate-submission protection using transactions
- Offline error handling and retry
- Schema versioning and v1-to-v2 migration

### Technology Stack
- Flutter and Dart
- Firebase Authentication
- Cloud Firestore
- Android and Web

### Project Structure
- lib/main.dart — Firebase initialization
- lib/auth_gate.dart — Authentication routing
- lib/auth_screen.dart — Login and registration
- lib/auth_service.dart — Authentication operations
- lib/user_service.dart — User profile management
- lib/board_screen.dart — Message board interface
- lib/board_service.dart — Firestore message operations

### Running the Application
1. Install Flutter and configure Firebase.
2. Run `flutter pub get`.
3. Run `flutter run`.

### Android Release Build
Run `flutter build apk --release`.

APK output:
`build/app/outputs/flutter-apk/app-release.apk`

### Testing
The project was tested for authentication, message CRUD,
real-time updates, sequential duplicate submissions,
offline recovery, schema migration, and Android device operation.

### Known Limitations
- Offline transactional message creation requires reconnection.
- Pending submission IDs are not persisted across app restarts.
- Concurrent duplicate submissions require further testing.
- Automated cross-user security tests remain to be completed.

### Repository
https://github.com/Samuel130527/CSC4360-HW02-Message-Board-Vault
