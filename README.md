# FocusLock

FocusLock is a Flutter app for screen-time control, lock windows, unlock limits, and focus habits.

The app has been migrated from a custom PHP backend to Firebase.

## Firebase Setup

1. Create a Firebase project in Firebase Console.
2. Enable Authentication with Email/Password.
3. Enable Cloud Firestore.
4. Add your Android app in Firebase Console and download `google-services.json`.
5. Place `google-services.json` in `android/app/`.
6. (Optional for iOS) Add `GoogleService-Info.plist` to `ios/Runner/`.

## Firestore Data Model

Each signed-in user is stored in:

- `users/{uid}`

Document structure:

- `email` (string)
- `displayName` (string)
- `settings` (map of `UserSettings` fields)
- `lockState` (map)
- `createdAt` / `updatedAt` (timestamps)

`lockState` fields used by the app:

- `todayUnlockCount` (number)
- `unlockDayKey` (string in `yyyy-MM-dd`)
- `cooldownActive` (bool)
- `cooldownEndAt` (ISO timestamp string or null)

## Firestore Rules (Starter)

Use this as a safe baseline and tighten further as needed:

```text
rules_version = '2';
service cloud.firestore {
	match /databases/{database}/documents {
		match /users/{userId} {
			allow read, write: if request.auth != null && request.auth.uid == userId;
		}
	}
}
```

## Run

```bash
flutter pub get
flutter run
```

## Optional: Web/Desktop Dart-Define Setup

If you do not use `firebase_options.dart`, you can provide Firebase config at runtime:

```bash
flutter run \
	--dart-define=FIREBASE_API_KEY=... \
	--dart-define=FIREBASE_APP_ID=... \
	--dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
	--dart-define=FIREBASE_PROJECT_ID=...
```
