# FocusLock Mobile Application

FocusLock is a Flutter-based mobile app that helps users build better focus habits by blocking access to social media platforms for customizable periods. The app is ideal for individuals seeking to reduce digital distractions and improve productivity.

---

## Features

- **Social Media Platform Locking:** Restricts access to distracting apps for set periods.
- **Customizable Lock Durations:** Users choose how long apps are locked.
- **Statistics & Tracking:** Review recent focus and unlock history.
- **Local Data Storage:** Stores usage and setting data locally using LiftStore (from pub.dev).
- **Firebase Integration:** Handles user authentication and secure cloud storage.

---

## Technologies Used

- **Dart / Flutter** – Cross-platform mobile development
- **Local Data Storage:** [LiftStore](https://pub.dev/packages/lift) (or similar) for persisting data on the device
- **Firebase:** For user credentials, authentication, and cross-device sync

---

## Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install)
- [Git](https://git-scm.com/)
- Android Studio or Xcode (for emulation and native builds)

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/joshuaagyemang08/Mobile_App_Final.git
   ```
2. **Navigate to the project directory:**
   ```bash
   cd Mobile_App_Final
   ```
3. **Install dependencies:**
   ```bash
   flutter pub get
   ```
4. **Run the app:**
   ```bash
   flutter run
   ```

### Firebase Setup

1. Create a Firebase project at [Firebase Console](https://console.firebase.google.com/).
2. Enable Authentication (Email/Password).
3. Enable Cloud Firestore.
4. Add your Android app and download the `google-services.json`, placing it in `android/app/`.
5. *(Optional for iOS)* Add `GoogleService-Info.plist` to `ios/Runner/`.

---

## Contributing

Contributions are welcome! Please open an issue or submit a pull request for improvements or suggestions.

## License

[MIT License](LICENSE)

---

> **Note:** FocusLock is under active development. Features and documentation will continue to evolve.
