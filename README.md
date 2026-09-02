<!--
  TEMPLATE — README-EXAMPLE.md
  Replace every <ANGLE_BRACKET> placeholder, drop the sections you don't want,
  then rename this file to README.md.
  Placeholders left to fill: <YOUR_GITHUB_USER>, <REPO>, <TESTFLIGHT_LINK>, <LICENSE>.
  Demo GIF and screenshots are already wired to assets/images/app-images/.
-->

<div align="center">

<img src="assets/images/thepear.png" width="120" alt="MacroScan logo" />

# MacroScan
## Contact me for the latest build download on iOS and Android
# Beta Version 1.1.1 is Released, new features include: Water logging based on profile preference, revamped UI.
**Track your macros by searching, scanning a barcode, or just taking a photo of your plate.**

Do you despise MyFitnessPal's decision to put their barcode scanning feature behind a paywall. I have developed a cross platform, Flutter based, mobile application that allows you to log your daily food intake with FREE features like MyFitnessPal's restricted barcode scanning. 

[![Flutter](https://img.shields.io/badge/Flutter-3.10%2B-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.10%2B-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20Android-lightgrey)]()


<!-- Optional: TestFlight / Play Store buttons -->
<!-- [Join the TestFlight beta](<TESTFLIGHT_LINK>) -->

</div>

---

## Demos

| Create an Account | Edit Your Goals | Log Food |
|:---:|:---:|:---:|
| <img src="assets/images/app-images/gifs/create-account.gif" width="260" alt="Create an account with email or Google" /> | <img src="assets/images/app-images/gifs/edit-goals.gif" width="260" alt="Edit your goals to align with your weight targets" /> | <img src="assets/images/app-images/gifs/product-demo.gif" width="260" alt="Logging a meal in MacroScan: search, pick a serving, watch the macro bars fill" /> |
| Email/password or Google, with inline validation | Edit your goals to align with your weight targets | Logging a meal in MacroScan: search, pick a serving, watch the macro bars fill |

## Screenshots

| Sign in | Home Screen | Guided onboarding |
|:---:|:---:|:---:|
| <img src="assets/images/app-images/login.PNG" width="230" alt="Sign-in screen with email, password and Google sign-in" /> | <img src="assets/images/app-images/home.PNG" width="230" alt="Home tab showing calorie and macro progress bars plus a hydration card" /> | <img src="assets/images/app-images/IMG_2986.PNG" width="230" alt="Account created screen with a three-step Account, Profile, Goals progress indicator" /> |
| Email/password or Google, with inline validation | Calories, protein, carbs and fat against your daily targets, plus water | Three-step setup: account, profile, then goals |

---

## Features

- **Three ways to log food**
  - Text search with live autocomplete, backed by the FatSecret food database
  - Barcode scanning (`mobile_scanner`) for packaged products
  - **Meal photo recognition (COMING SOON)** — Snap a pic of your plate, get the food and an estimated serving back
- **Daily macro dashboard** — calories, protein, carbs and fat against your targets, per day, with date navigation
- **Personalised goals** — profile (age, height, weight, sex, activity level) plus a weekly weight-change target drives the calorie and macro budget
- **Meal-aware food log** — breakfast / lunch / dinner / snacks, swipe to delete, tap to edit servings
- **Water tracking** with ml / fl oz / cup display units
- **Accounts** — Firebase email/password and Google sign-in, password reset, account deletion
- **Offline-friendly** — disk cache of summaries, logs and profile with prefetch of the last 10 days
- **Light and dark themes**, persisted, with an iOS/Android-adaptive dialog layer

---

## Tech stack

| Layer | Choice |
|---|---|
| App | Flutter (Dart 3.10+), Material 3, iOS + Android |
| Auth | Firebase Auth — email/password + Google Sign-In |
| State | Plain `setState` + `ValueNotifier` singletons (no state-management package) |
| Networking | `http` against a REST API, with a disk cache layer |
| Cache | `flutter_cache_manager` (disk, uid-scoped) + `AutomaticKeepAliveClientMixin` |
| Local prefs | `shared_preferences` (theme, water) |
| Scanning | `mobile_scanner` (barcodes), `image_picker` (meal photos) |
| Nutrition data | FatSecret Platform API |
| Backend | Node/Express + PostgreSQL — **separate private repository** |

> **Note on scope.** This repository contains the Flutter client only. The API
> server (Express + PostgreSQL, deployed on Railway) lives in its own private
> repo; the app talks to it over HTTPS. See [Backend](#backend) below for the
> contract it implements.

---

## Architecture
<div align="center">

<img src="assets/images/MacroScan-Architecture.png" width="" alt="Basic Overview on Application's Architecture" />

</div>


**Layering rule:** screens never call `http` directly. Everything goes
`screen → DatabaseService → CacheService → API`.

<!-- ## Getting started

### Prerequisites

- Flutter SDK 3.10 or newer (`flutter doctor` should be clean)
- Xcode (iOS) and/or Android Studio (Android)
- A Firebase project with Auth enabled (email/password + Google) -->

<!-- ### Setup

```bash
git clone https://github.com/<YOUR_GITHUB_USER>/<REPO>.git
cd <REPO>
flutter pub get
```

**1. Firebase.** `lib/firebase_options.dart` is not committed. Generate your own:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

Then add the platform config files Firebase gives you
(`android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`).

**2. Point the app at an API.** The base URL lives in
`DatabaseService.baseUrl` and can be overridden at build time:

```bash
flutter run                                                   # default host
flutter run --dart-define=API_BASE_URL=http://localhost:3000/api
```

> Android emulator reaches your machine at `10.0.2.2`; a physical device needs
> your LAN IP; the iOS simulator can use `localhost`.

### Everyday commands

```bash
flutter run                  # debug build on the selected device
flutter analyze              # lints (flutter_lints)
flutter test                 # unit/widget tests
dart run flutter_launcher_icons   # regenerate app icons from assets/images/applogo.png
flutter build ipa            # iOS release
flutter build appbundle      # Android release
``` -->

---

## Backend

The server is **not** part of this repository. The app expects a REST API that
implements the following routes, all under `API_BASE_URL`, authenticated with a
Firebase ID token (`Authorization: Bearer <token>`):

| Method | Route | Purpose |
|---|---|---|
| `POST` | `/user/create` | Create the user row after sign-up |
| `GET` | `/user/:uid` | Fetch profile |
| `POST` | `/user/update` | Update profile |
| `GET` | `/goals/:uid` | Calorie + macro targets |
| `GET` | `/daily-summary/:uid?date=YYYY-MM-DD` | Totals for a day |
| `GET` | `/food/log/:uid?date=YYYY-MM-DD` | Log entries for a day |
| `POST` | `/food/log` | Add a log entry |
| `PUT` / `DELETE` | `/food/log/:id` | Edit / remove an entry |
| `GET` | `/food/search?q=` | Food search (FatSecret proxy) |
| `GET` | `/food/autocomplete?q=` | Search suggestions |
| `GET` | `/food/:id` | Full food detail with servings |
| `GET` | `/barcode/:gtin13` | Barcode → food id |
| `POST` | `/food/recognize` | Meal photo (base64) → recognised food |

Anything that satisfies this contract will work; the reference implementation is
Express + PostgreSQL on Railway.

---

## Implementation notes

A few decisions worth calling out:

- **Serving maths.** FatSecret returns servings as free-text descriptions plus
  metric fields. The client derives normalised `1 g` / `1 oz` / `1 cup` servings
  from those so quantity editing works consistently across foods.
- **Cache invalidation across kept-alive tabs.** Tabs are kept alive and never
  rebuild on switch, so writes bump a cache revision and record the affected
  date; a hidden screen reloads only if that date is the one it is showing.
- **Photo pipeline.** Meal photos are downsized to 512 px and rejected above
  ~1 MB before upload; a "no food detected" response is surfaced as a typed
  exception rather than a generic error.
- **Adaptive UI.** Dialogs, date pickers and spinners pick Cupertino or Material
  based on platform, so the app feels native on both.

---

## Roadmap

- [ ] Weight history and trend chart
- [ ] Recent / favourite foods and custom recipes
- [ ] Server-side water logging
- [ ] Apple Health / Google Fit integration
- [ ] Widget + Live Activity for daily calories

---

## License

<LICENSE> — see [LICENSE](LICENSE).

Nutrition data is provided by the [FatSecret Platform API](https://platform.fatsecret.com/).