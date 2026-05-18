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
- **Friends** — search other users, send/accept friend requests, and
  manage your gym-bro list.
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

### 2. Pick a backend

The app talks to Supabase. You can use the hosted cloud project **or**
run the whole Supabase stack locally in Docker — `lib/core/supabase_config.dart`
switches between them with one flag:

```dart
static const bool useLocalDocker = false; // true → local Docker
```

**Option A — Supabase cloud.** Set `_cloudUrl` / `_cloudAnonKey` in
`supabase_config.dart` (Dashboard → Settings → API), then run
[`database/schema.sql`](database/schema.sql) and
[`database/social.sql`](database/social.sql) in the SQL Editor. The app
also expects the base tables `profiles`, `nutrition_logs`, `water_logs`,
`workout_logs`, and a public `avatars` storage bucket.

**Option B — self-hosted Supabase in Docker (recommended for development).**
See [Local backend with Docker](#local-backend-with-docker) below.

### 3. Run

```bash
flutter pub get
flutter run
```

## Local backend with Docker

The [`supabase/`](supabase) folder is a [Supabase CLI](https://supabase.com/docs/guides/cli)
project. `supabase start` boots the entire backend — Postgres, Auth,
Storage, REST API, Realtime and Studio — as Docker containers, and
applies every migration in `supabase/migrations/`.

**Prerequisites:** Docker Desktop and the Supabase CLI
(`scoop install supabase`, `npm i -g supabase`, or see the CLI docs).

```bash
supabase start          # boots the stack + applies migrations
supabase db reset       # wipes the DB and re-applies migrations
supabase stop           # shuts the stack down
```

Then flip the backend in `lib/core/supabase_config.dart`:

```dart
static const bool useLocalDocker = true;
```

- Web / desktop reach the API at `http://127.0.0.1:54321`.
- An Android emulator must use `http://10.0.2.2:54321` instead — it
  cannot see the host's `localhost`.
- Supabase Studio (DB browser): `http://127.0.0.1:54323`.
- Captured emails (signup confirmations): `http://127.0.0.1:54324`.

The schema lives in [`supabase/migrations/`](supabase/migrations) — all
tables, row-level security, the `avatars` storage bucket, and a trigger
that creates a `profiles` row for every new user.

## Project structure

```
lib/
├── core/
│   ├── supabase_config.dart      # Backend URL/key + cloud↔Docker switch
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
│   ├── friends_screen.dart       # User search + friend requests
│   └── profile_screen.dart       # Profile + reminder settings
├── widgets/
│   └── auth_text_field.dart
└── main.dart
supabase/
├── config.toml                   # Supabase CLI / Docker config
└── migrations/                   # Full schema for the self-hosted DB
database/
├── schema.sql                    # Workout plan + weight tables (cloud)
└── social.sql                    # Friendships table (cloud)
```

## Notifications

Reminders are local (on-device) notifications — no push server required.
Android needs notification permission (Android 13+); the app requests it
when you enable a reminder in **Profile → Reminders**. Boot-persistence
and exact-alarm receivers are declared in `AndroidManifest.xml`, and
core-library desugaring is enabled in `android/app/build.gradle.kts` (a
requirement of `flutter_local_notifications`).
