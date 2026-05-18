# GymBro — Gym & Nutrition Tracker

A dark-themed fitness companion built with Flutter and Supabase. Track
workouts, plan training routines, log meals and water, watch your weight
trend, and get daily reminders to stay on track.

> **Tagline:** TRAIN. EAT. DOMINATE.

## Features

- **Auth** — email/password and Google sign-in via Supabase Auth.
- **Home dashboard** — activity rings, weekly progress, and a live
  "Today's Workout" list driven by your workout plan.
- **Workout Plan** — create exercises grouped by muscle group (sets ×
  reps), tick them off as you train, swipe to delete, reset for a new day.
- **Nutrition** — log meals by type, track calories and macros against
  daily targets, and a water tracker with quick-add buttons.
- **Stats** — calories-burned and workout-minute charts, an animated
  **weight-progress line chart**, achievements, and a daily health
  overview.
- **Profile** — edit personal info, upload an avatar, and toggle
  **water / workout reminders**.
- **Local reminders** — daily water (10:00, 13:00, 16:00, 19:00) and
  workout (18:00) notifications, scheduled on-device.

## Tech stack

| Area            | Package                                          |
|-----------------|--------------------------------------------------|
| Backend / auth  | `supabase_flutter`, `google_sign_in`             |
| Routing         | `go_router`                                      |
| UI / animation  | `flutter_animate`, `google_fonts`                |
| Media           | `video_player`, `image_picker`                   |
| Notifications   | `flutter_local_notifications`, `timezone`, `flutter_timezone` |
| Local prefs     | `shared_preferences`                             |

## Getting started

### 1. Prerequisites

- Flutter SDK `>=3.0.0`
- A Supabase project

### 2. Configure Supabase

Open `lib/core/supabase_config.dart` and set your project URL and anon key
(Supabase Dashboard → Settings → API):

```dart
static const String supabaseUrl = 'https://YOUR-PROJECT.supabase.co';
static const String supabaseAnonKey = 'YOUR-ANON-KEY';
```

### 3. Create the database tables

Run [`database/schema.sql`](database/schema.sql) in the Supabase SQL
Editor. It creates the `workout_exercises` and `weight_logs` tables (with
row-level security) used by the Workout Plan and Weight Progress features.

The app also expects these existing tables: `profiles`, `nutrition_logs`,
`water_logs`, `workout_logs`. Create a public `avatars` storage bucket for
profile pictures.

### 4. Run

```bash
flutter pub get
flutter run
```

## Project structure

```
lib/
├── core/
│   ├── supabase_config.dart      # Supabase credentials
│   ├── theme.dart                # App colors & typography
│   └── notification_service.dart # Local reminder scheduling
├── screens/
│   ├── splash_screen.dart
│   ├── login_screen.dart
│   ├── register_screen.dart
│   ├── home_screen.dart
│   ├── workout_plan_screen.dart  # Exercise plan CRUD
│   ├── stats_screen.dart         # Charts + weight progress
│   ├── nutrition_screen.dart
│   └── profile_screen.dart       # Profile + reminder settings
├── widgets/
│   └── auth_text_field.dart
└── main.dart
database/
└── schema.sql                    # SQL for new tables
```

## Notifications

Reminders are local (on-device) notifications — no push server required.
Android needs notification permission (Android 13+); the app requests it
when you enable a reminder in **Profile → Reminders**. Boot-persistence
and exact-alarm receivers are declared in `AndroidManifest.xml`, and
core-library desugaring is enabled in `android/app/build.gradle.kts` (a
requirement of `flutter_local_notifications`).
