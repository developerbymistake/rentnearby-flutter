# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Flutter app for the "Bakhli" rental/plot marketplace (Uttarakhand-focused; the Flutter project name
`bakhli` and internal branding are current — the repo directory name, Android `applicationId`
(`com.rentnearby.rentnearby`), and iOS bundle id are legacy `rentnearby` naming that was never
renamed). No brokers/commission — lists rental rooms and plots, in-app chat between owner/seeker,
and paid listing plans via Razorpay.

## Commands

```bash
flutter pub get                 # install dependencies

flutter analyze                 # lint/static analysis (flutter_lints, see analysis_options.yaml)

flutter run                     # run on a connected device/emulator (debug)
flutter run -d chrome           # run on web
flutter run --release           # run in release mode

flutter build apk               # Android APK
flutter build appbundle         # Android App Bundle (Play Store)
flutter build ios               # iOS (requires macOS/Xcode)
flutter build web               # Web build

flutter test                    # run all tests
flutter test test/widget_test.dart   # run a single test file
flutter test --plain-name "app smoke test placeholder"  # run a single test by name
```

There is effectively one placeholder test (`test/widget_test.dart`) — the comment in it notes "Full
integration tests require backend". Don't assume meaningful test coverage exists; when adding tests,
there's no existing suite convention to follow beyond `flutter_test`.

Only `flutter analyze *` is pre-approved in `.claude/settings.json`; other commands may prompt for
permission.

## Architecture

**State management: GetX (`get` package)** — used for reactive state (`.obs` / `Rx` + `Obx`/`GetX`
widgets), dependency injection (`Get.put`/`Get.find`), and navigation (`GetMaterialApp`,
`Get.toNamed`/`offAllNamed`). There is no `Bindings` layer — dependencies are registered eagerly and
explicitly:
- App-wide singletons (`NotificationService`, `AuthController`) are `Get.put` in `main()` before
  `runApp`.
- Everything else (feature controllers, repositories, hub services) is `Get.put` in
  `MainScreen.initState()` (`lib/screens/main_screen.dart`) in a specific dependency order — read the
  comments there before reordering (e.g. `HomeController.onInit()` looks up `LocationController`, so
  it must be put after it).
- Controllers are looked up elsewhere via `Get.find<T>()`; there is no constructor injection.

**Navigation**: `GetMaterialApp` + named routes declared in `lib/config/app_routes.dart`
(`AppRoutes.routes`, a flat `List<GetPage>` with per-route transitions). The bottom-nav tabs (Home,
Rooms, Plots, Chats, Profile — indices defined in `lib/config/app_tabs.dart`) are NOT part of this
route table: `MainScreen` renders them as an `IndexedStack` of `TabNavigator` widgets
(`lib/navigation/tab_router.dart`), each wrapping its tab root screen in its own nested `Navigator`
keyed via `lib/navigation/tab_keys.dart`. This isolates keyboard/layout/MediaQuery changes per tab.
Deep/detail screens (listing detail, add listing, payment, chat conversation, etc.) still go through
the global `Get.toNamed` navigator on top of everything, unaffected by which tab is active. "My
Rooms"/"My Plots" are pushed named routes, not tabs (reached via a header button on Rooms/Plots).

Because `IndexedStack` never disposes inactive tabs, a `showModalBottomSheet` opened from a tab-root
screen's own `context` (e.g. `LocationSwitchSheet`, `LocationSearchSheet`, the listing/plot detail
sheets) resolves to that tab's *local* Navigator and stays pushed on its stack in the background if
the user switches tabs without dismissing it — reappearing exactly as left when they switch back
(`showDialog` is unaffected; it defaults to the root navigator). `MainScreen` guards against this with
an `ever(_auth.tabIndex, ...)` worker (`_tabLeaveWorker`) that pops any stray route off the tab being
left via `tabKeys[...]`. This reacts to `tabIndex` itself rather than patching individual tab-switch
call sites (bottom nav taps, back-press, push-notification routing, Home screen CTAs all mutate
`tabIndex.value` directly), so it covers all of them by construction — keep it that way rather than
adding one-off dismiss calls at new call sites.

**Networking**: a single `Dio` instance wrapped in the static `ApiService`
(`lib/services/api_service.dart`) — no repository-per-Dio-instance pattern. An `InterceptorsWrapper`
auto-attaches the bearer token from `StorageService` on every request and auto-logs-out on a 401
(guarded by an `_isHandlingUnauthorized` flag to prevent repeat logout storms). A second `Dio`
instance (`_nominatimDio`) hits a self-hosted Nominatim reverse-geocoding proxy. `AppConstants.baseUrl`
(`lib/config/app_constants.dart`) is the single source of truth for the backend origin
(`https://developerbymistake.tech/api/v1`) — commented-out local/emulator URLs are left there for
switching during local backend dev. Real-time features (chat, per-district promotional banners) use
SignalR (`signalr_netcore`) via two independent hub services, not Dio: `ChatHubService` (lazy —
callers explicitly connect/disconnect around opening the Chats list or a conversation) and
`BannerHubService` (connects for the user's current district whenever `LocationController
.selectedDistrict` changes, stays connected while browsing). Both hubs pass a fresh JWT via
`accessTokenFactory` so token refresh is handled transparently, and both fall back silently to REST
polling if the hub connection fails.

**Data flow / caching**: `lib/repositories/*` wrap `ApiService` calls with simple in-memory
TTL-based caches (e.g. `ListingRepository` caches `/listings/plans` for 5 min and membership status
for 60s) and expose `invalidate()`/`invalidateAll()` for controllers to bust the cache after a
mutation. `lib/controllers/*` (all `GetxController`) hold UI-facing reactive state and orchestrate
calls to repositories/`ApiService`; `AuthController` in particular is the hub for session state
(`user`, `tabIndex`, granular profile Rx fields) and owns login/OTP/logout/account-deletion flows.

**Storage**: `lib/services/storage_service.dart` is a static facade over two backends — 
`flutter_secure_storage` for the auth token only (with an in-memory `_cachedToken` to avoid async
reads on every request), and `get_storage` (`GetStorage`, a fast local JSON box) for everything else:
cached user profile, FCM token, per-conversation chat-notification-stacking buffers, and
location/reference-data caches (districts/cities, with their own TTL — see `AppConstants
.locationsCacheTtl`). Read the comments in `StorageService` around the district-switch and
chat-notification-stacking sections before touching them — they explain non-obvious invariants (e.g.
the user's manually browsed district is *never* persisted, only the reference lists are).

**Location/district model**: the app is geofenced by "district" (an admin-defined service area).
`LocationController` (`lib/controllers/location_controller.dart`) is the single source of truth for:
live GPS (`userLocation`), the user's real GPS-resolved district/city (`selectedDistrict`/
`autoCity`), a *temporary* manually-browsed district/city (`browsingDistrict`/`browsingCity`, never
persisted, reset on every resume/cold start), and a precise map-search pin override shared between
the Rooms and Plots explore screens. `effectiveDistrict`/`effectiveCity`/`effectiveSearchCenter` are
the derived getters screens should read rather than picking through the raw fields. `MainScreen`
gates the whole app behind full-screen states driven by this controller: offline, GPS-disabled, and
"district not supported yet" — see `_buildOfflineGate`/`_buildGpsGate`/`_buildDistrictGate`.

**Maps**: `maplibre_gl` (not Google Maps) using a custom style at `assets/map_style.json`. Map-related
tuning constants (clustering radius, max markers, fallback center coordinates for Uttarakhand) live in
`AppConstants`. `lib/config/app_map_state.dart` exposes a single global `mapShouldPause` `RxBool` that
full-screen map routes (add listing/plot) flip so the explore screens can swap their live map for a
shimmer placeholder instead of running two maps at once; `MapPauseObserver`
(`lib/services/map_pause_observer.dart`) is registered as a `navigatorObservers` entry in
`GetMaterialApp` to drive this automatically off route push/pop.

**Push notifications**: Firebase Cloud Messaging + `flutter_local_notifications`, wired in
`lib/services/notification_service.dart`. Chat pushes are data-only (rendered client-side, not
auto-displayed by FCM) so the app can build WhatsApp-style stacked/grouped notifications with a
generated circular initial-avatar (`MessagingStyleInformation`); recent per-conversation message
lines are persisted via `StorageService` so a killed-app background isolate can keep stacking onto
what a previous isolate invocation already showed. District-scoped broadcast notifications use FCM
topic subscriptions (`district_<id>`), kept in sync with `LocationController.selectedDistrict` via an
`ever()` worker in `MainScreen`. Notification-tap routing has to distinguish several app states
(cold start / already on `main` / a detail screen pushed on top of main) — see the routing logic and
comments in `NotificationService._handleNotificationTap`/`_navigateToChatConversation` before changing
navigation-on-tap behavior.

**Feature flags & listing limits**: `AppFeatureController` polls `/admin/features` for
server-controlled flags (`room_payment`/`plot_payment` enabled + free-tier limits).
`ListingPermissionService` (and its plot equivalent) is the single place that decides, given feature
flags + the user's current listing count + membership/plan state, whether posting a new listing is
allowed, should show a "limit reached" dialog, or should show an upgrade sheet — don't duplicate this
gating logic in screens.

**Payments**: Razorpay (`razorpay_flutter`) via `RazorpayPaymentService`
(`lib/services/razorpay_service.dart`), a thin callback-based wrapper instantiated per payment flow
(not a `GetxService` singleton) — order creation and verification happen server-side, this class only
drives the native checkout UI and reports success/failure back via callbacks.

**Folder layout** (`lib/`):
- `config/` — constants, colors, theme, insets, route table, tab indices, map-pause flag
- `controllers/` — `GetxController`s holding reactive UI state per feature area
- `repositories/` — thin TTL-caching wrappers around `ApiService` calls
- `services/` — cross-cutting singletons (`GetxService`s) and static facades: API/storage/auth-token
  plumbing, SignalR hubs, FCM/local notifications, Razorpay, permission-gating logic
- `models/` — plain Dart classes with hand-written `fromJson`/`toJson` (no code generation/freezed)
- `screens/` — one file per full-screen route; mixins (e.g.
  `explore_location_search_mixin.dart`) factor out logic shared between the Rooms and Plots explore
  screens rather than a common base class
- `widgets/` — reusable presentational components (cards, sheets, pins, bottom-sheet action bars)
- `navigation/` — the per-tab nested-Navigator machinery described above
- `utils/` — small helpers (e.g. `app_toast.dart` wraps `toastification` for consistent toast styling;
  `input_formatters.dart` exports `noEmojiInputFormatters`, applied to every genuine free-text
  `TextField`/`TextFormField` in the app — city search, descriptions, addresses, report details, chat
  search, name fields — apply it to any new free-text field too. Numeric fields (price, area,
  phone/OTP) use their own digit-only formatters instead and don't need it)

**Theming**: single fixed light theme (`lib/config/app_theme.dart` + `app_colors.dart`), Material 3,
Poppins font family declared in `pubspec.yaml`. No dark mode, no localization/i18n setup — all UI
strings are hard-coded English inline in widgets.

**Conventions worth matching**:
- Long, precise "why" comments are the norm in controllers/services, especially around ordering,
  race conditions, and state-invalidation subtleties (`AuthController`, `LocationController`,
  `NotificationService`, `StorageService` are dense with these) — read them before changing adjacent
  logic, and preserve that style in new code touching the same areas.
- Error handling in controllers typically translates `DioException` status codes into user-facing
  strings via small private static `_xxxError`/`_dioMessage` helpers (see `AuthController`) rather
  than surfacing raw exceptions.
- Git commit messages follow Conventional Commits style: `feat:`, `fix:`, `chore:`, with an optional
  scope, e.g. `fix(chat): ...`, `feat(home): ...`.
