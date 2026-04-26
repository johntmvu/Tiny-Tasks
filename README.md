# Tiny Tasks

Tiny Tasks is a cross-platform Flutter app built to help students manage their day with less overwhelm.
It focuses on a simple daily workflow, quick task capture, and syncing data between local storage and cloud services.

Originally created as a Capstone project (Team 6), Tiny Tasks is designed with ADHD-friendly planning in mind: show what matters now, reduce clutter, and make progress feel lightweight.

## Why Tiny Tasks?

- Keep attention on **today's priorities**, not an overloaded backlog.
- Support **quick add**, **complete/hide**, and **history** workflows.
- Offer **Big Task -> Tiny Task** breakdown support, including AI-assisted recommendations.
- Sync with cloud services while preserving a local-first experience.

## Core Features

- Email/password authentication with Firebase Auth
- Task CRUD with date/time and completion state
- Big task management and tiny task decomposition
- Local notifications for reminders
- Google Calendar integration hooks
- SQLite + Firestore dual persistence strategy
- In-app settings, profile, and history views

## Architecture Overview

Tiny Tasks follows a layered design:

- **Presentation Layer:** Flutter screens/widgets (`lib/screens`, `lib/widgets`)
- **Business Logic Layer:** repositories/services handling task rules, sync, and AI integration
- **Data Layer:**
  - SQLite (`lib/database/sqlite_helper.dart`) for local/offline data
  - Firestore/Firebase services for cloud persistence and auth

Task writes are coordinated through repositories so local and cloud data stay in sync.

## Tech Stack

- Flutter + Dart
- Firebase (Auth, Firestore, Core)
- SQLite (`sqflite`)
- Google Sign-In
- Google Generative AI integration
- Flutter Local Notifications

## Project Structure

```text
lib/
  main.dart
  login_page.dart
  models/
  database/
  repositories/
  services/
  screens/
  widgets/
test/
```

## Getting Started

### Prerequisites

- Flutter SDK installed
- Dart SDK (bundled with Flutter)
- Firebase project configured for this app
- iOS/Android toolchains set up

### Setup

1. Clone the repository:

```bash
git clone https://github.com/<your-org-or-user>/Tiny-Tasks.git
cd Tiny-Tasks
```

2. Install dependencies:

```bash
flutter pub get
```

3. Create a `.env` file in the repo root and add required keys:

```env
GEMINI_API_KEY=your_api_key_here
```

4. Ensure Firebase configuration is present (`lib/firebase_options.dart`) and valid for your project.

## Run the App

```bash
flutter run
```

## Testing and Analysis

Run all tests:

```bash
flutter test
```

Run a single test file:

```bash
flutter test test/database/big_task_tiny_task_test.dart
```

Run static analysis:

```bash
flutter analyze
```

## Roadmap

- Expand calendar sync reliability and conflict handling
- Continue improving AI task decomposition quality
- Strengthen test coverage across repositories and screens
- Add more accessibility and usability refinements

## Team

Capstone Team 6:

- Isaac Lara ()
- Jagruthi Vadlamudi
- Christopher Nguyen
- John Vu
