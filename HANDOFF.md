# SoundConnect Mobile Handoff

## Project
- Repo: https://github.com/berkaybasol/soundconnect_mobile_231225
- Workspace: c:\Users\B-BOY\Desktop\soundonnect_mobile23122025codex
- Flutter app name: soundconnect_23_12_25codx

## Current status
- Login UI polished (dark navy theme, gradient focus borders, neon subtle glow).
- Register flow is multi-step with PageView swipe.
- Role selection is in 2-column grid, venue option separated below a divider.
- Venue role adds extra step with venue details and cascading location dropdowns.
- OTP screen uses stored email from register flow (no email input shown).

## Key files (frontend)
- Login UI: lib/modules/auth/presentation/screens/login_screen.dart
- Register flow: lib/modules/auth/presentation/screens/register_screen.dart
- Venue form: lib/modules/auth/presentation/screens/venue_application_screen.dart
- OTP screen: lib/modules/auth/presentation/screens/otp_verify_screen.dart
- Theme/colors: lib/shared/theme/app_theme.dart, lib/shared/theme/app_colors.dart
- Gradient widgets: lib/shared/widgets/gradient_text_field.dart, lib/shared/widgets/gradient_outline_button.dart
- Routing: lib/app/router/app_routes.dart, lib/app/router/app_router.dart
- DI: lib/core/di/service_locator.dart

## Backend integration
- Auth endpoints: /api/v1/auth/*
- Location endpoints:
  - GET /api/v1/cities/get-all-cities
  - GET /api/v1/districts/get-by-city/{cityId}
  - GET /api/v1/neighborhoods/get-by-district/{districtId}
- Venue application (user): /api/v1/user/venue-applications/create
- JWT token should not be attached to auth/location endpoints.
  - Handled in lib/core/network/dio_api_client.dart via _isPublicPath.

## Current base URL
- For real device: lib/core/network/network_config.dart
  - baseUrl = http://192.168.1.114:8080 (update per ipconfig)

## Known issues
- Swipe animation feels a bit heavy; may need perf tuning later.
- OTP verify sometimes shows "Verification failed" despite backend success (to revisit).
- If expired token errors occur, remove token or ensure auth endpoints are public.

## How to run
- USB device id example: flutter run -d 10GCA400GT0001N
- Ensure backend running on PC and phone can access PC IP.

## Next steps (planned)
- Continue role text tuning (user will provide copy).
- Refine swipe performance if needed.
- Fix OTP verify UX once backend behavior finalized.
