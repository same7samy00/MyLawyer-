# GEMINI.md - Directives for Gemini AI Models

## ⚖️ Project Identity & Scope
- **Brand Name:** My Lawyer (English branding).
- **Platform Scope:** Comprehensive legal services platform connecting clients and lawyers (legal consultations, contract drafting, business formation, lawsuits/representation, urgent "محاميك حالاً", legal wallet). Not a single-purpose emergency app.
- **UI Language:** Egyptian Arabic with a refined, accessible tone (عربية رسمية بلمسة مصرية خفيفة وقريبة للمستخدم).
- **Text Direction:** Strictly RTL everywhere (`Locale('ar', 'EG')`).
- **Icons Policy:** Strictly NO scales of justice (ميزان), no gavels (مطرقة), and no classical courthouse pillars (`account_balance`). Modern safety/location/shield/policy icons only.
- **Target OS:** Android (minSdk 21, compileSdk 35) & iOS (iOS 12+).
- **Target Context:** Egyptian phone numbers (`01xxxxxxxxx`) & Egyptian region, but NEVER display explicit text stating it is restricted to Egypt.

## 🎨 Design System Constraints
- **Primary Color:** `#1D4ED8` | **Dark Neutral:** `#0F172A` | **Card Border:** `#E2E8F0` | **Background:** `#F8FAFC`
- **Font Family:** `flat-jooza` for text, with English digits from `assets/fonts/app-digits.ttf`.
- **Border Radii:** Strictly **12.0px** for all buttons (`BorderRadius.circular(12.0)`), and **7.0px** for all standard cards, inputs, dialogs, badges, and snackbars.
- **Navigation Layout:**
  - **Splash Screen:** Pure white background, primary blue "My Lawyer" typography, no icons/spinners, 850ms motion graphics.
  - **Global Unified Header (`AppHeader`):** Persistent top header on all screens (including map screens) except `LoginScreen`. Dynamic centered screen title, unboxed right search (tabs) / back button (inner pages), and unboxed left notifications.
  - **Bottom Navigation Bar (`AppBottomBar`):** Exactly 4 tabs: الرئيسية، الطلبات، المحفظة، الحساب. Services in الرئيسية are rendered in a clean vertical LIST.
  - **Map Bottom Sheet:** Fixed-height spacious profile (390px), centered title without icon with dashed line below it, drag gestures for smooth expand/collapse, no order type element, absolute height stability during search/cycling, and integrated WebView for lawyer Google profiles.

## 🛰️ Geolocation Policy
- Single-point current location pinpointing on map (`LocationService`).
- NO live streaming, NO movement trails. The line between parties is drawn on the phone only. Navigation uses Google Maps after payment.
- Read docs/HANDOFF.md and docs/GPS_SYSTEM.md before any work.
- Display City and Governorate in Arabic only (`GeoNamingService`); NEVER display raw numeric coordinates to the user.
- Confirmation flows must strictly reside in bottom sheets with 7.0px corners.

## 🛡️ Governance & Quality Gate
- Before modifying: Inspect existing files and understand dependencies.
- Never break existing functionality or replace real logic with fake data.
- Always maintain synchronized documentation with every change (`AGENTS.md`, `README.md`, `docs/ARCHITECTURE.md`, `docs/CHANGELOG.md`).
- Static analysis gate: `flutter analyze` must output `No issues found!` (0 warnings, 0 errors).
- Test gate: `flutter test` must pass 100%.
