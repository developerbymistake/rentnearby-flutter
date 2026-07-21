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
(`AppRoutes.routes`, a flat `List<GetPage>` with per-route transitions). The bottom-nav tabs
(`lib/config/app_tabs.dart`: `home(0) / rooms(1) / plots(2) / explore(3) / profile(4)` — index 3 was
`chats` and is commented as repurposed for the local-services marketplace, see below; Chat is no longer
a bottom-nav tab, reached instead via a header icon on Home) are NOT part of this
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
auto-attaches the bearer token from `StorageService` on every request and auto-logs-out on a 401 by
calling `AuthController.forceLogout(reason: LogoutReason.sessionExpired)` through
`ApiService.runExclusiveLogout` — a shared single-flight `Future` guard so concurrent 401s (and
explicit logout/account-deletion, which route through the same `forceLogout`) all await one cleanup
instead of racing. `LogoutReason` (`explicitLogout`/`accountDeleted`/`sessionExpired`) decides whether
the server-side revoke call fires and which toast, if any, is shown. A second `Dio`
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
"district not supported yet" — see `_buildOfflineGate`/`_buildGpsGate`/`_buildDistrictGate`. This gate
wraps the whole app above the `IndexedStack`, regardless of tab count/order.

**Pin/radius mechanics** (client-side only — the backend does not currently re-validate either of these,
see the Backend repo's CLAUDE.md "Known gap" note): new-listing pin placement is capped to 500m from the
user's live GPS fix, enforced in `add_listing_screen.dart`/`add_plot_screen.dart` against a client-computed
distance. Explore radius is a fixed 3-value chip selector, `AppConstants.radiusOptions = [1.0, 5.0, 10.0]`
(km) — not a slider — used identically by `explore_screen.dart`/`explore_plots_screen.dart`.

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

**Coin economy (replaces the old membership/payment model)**: there is no more per-listing membership
entity and no more free-vs-paid tier on listing *creation*. Users buy coins (Razorpay packs, redeem
codes, or admin credit) into a wallet, then spend coins to "Go Live" on a specific Room/Plot listing.
A listing's own `isActive`/`validUntil` fields are the only per-listing state — deactivating and
reactivating within the same paid window is free (`ListingController.toggleActive`/
`PlotController.toggleActive`, deactivation only now — the backend 400s a PUT that tries to set
`isActive: true`, directing callers to Go Live instead); going live after expiry (or for the first
time) costs coins per a chosen plan (`GET /listings/plans` or `/plots/plans`, unchanged endpoints, now
priced in coins not rupees) via `ListingController.goLive`/`PlotController.goLivePlot`
(`POST /{listings|plots}/{id}/go-live`). Both return a `GoLiveResult` (`lib/models/go_live_result.dart`)
so callers can branch on `GoLiveInsufficientBalance` specifically to open the shared
`InsufficientBalanceSheet` (`lib/widgets/insufficient_balance_sheet.dart`) rather than just toasting.

- **Listing-creation limits**: `ConfigController`/`ConfigRepository` (`lib/repositories/config_repository.dart`)
  wrap `GET /config/listing-limits` (anonymous, 1h TTL) — the single, flat, admin-configured cap on how
  many rooms/plots a user may *create*, with no per-user tier distinction anymore. `ListingPermissionService`
  (and its plot equivalent, `lib/services/listing_permission_service.dart` / `plot_permission_service.dart`)
  is the single place that decides, given this cap and the user's current listing count, whether posting a
  new listing is `Allowed`, `NeedsDistrict`, or `LimitReached(cap)` — a 3-case sealed result, don't duplicate
  this gating logic in screens. This is entirely separate from whether a listing is *live* (see above).
- **Wallet**: `WalletController`/`WalletRepository` (`lib/controllers/wallet_controller.dart`,
  `lib/repositories/wallet_repository.dart`) are the single source of truth for the user's live coin
  balance (`GET /wallet/balance`, 30s TTL), the coin-pack catalog (`GET /coin-packs/`, 5min TTL), and the
  paginated transaction ledger (`GET /wallet/transactions`, uncached). `WalletController` also owns the
  reusable purchase flow (create-order → Razorpay → verify-payment → cancel-order, same Razorpay SDK
  mechanism the old payment flow used, just pointed at coin packs) and `redeemCode()`. Call
  `WalletController.loadBalance()` (or let `goLive`/`goLivePlot`/`verifyPayment`/`redeemCode` do it for
  you — they already do) after anything that credits or debits coins so the balance stays live everywhere;
  nothing else should cache balance separately. `CoinBalanceChip` (`lib/widgets/coin_balance_chip.dart`) is
  the reusable balance pill dropped into My Rooms and My Plots. Profile has its own bespoke wallet card
  (`ProfileScreen._buildWalletCard`) instead — balance + Buy Coins button + a "more ways to spend coins are
  coming soon" note that doesn't fit the shared chip's shape.
- **Screens**: `CoinPacksScreen` (buy coins + entry points to redeem/history), `RedeemCodeScreen`,
  `WalletLedgerScreen` — reachable via `AppRoutes.coinPacks`/`redeemCode`/`walletLedger`.
- Both `Get.put(ConfigRepository())`/`Get.put(ConfigController())` and
  `Get.put(WalletRepository())`/`Get.put(WalletController())` are registered in `MainScreen.initState()`
  alongside `ListingRepository`/`PlotRepository`.

**Local services marketplace, Agents & Leads (separate vertical from Room/Plot)**: `local_services_screen.dart`
is the `services` tab's content, and Home shows the same rails. **Categories are the catalog's top
level** (the old ServiceSection layer was removed backend-wide): each active `ServiceCategory` renders
as one color-zoned rail of rich `ServiceRailCard`s via the shared `ServiceCategoryRail` widget
(`lib/widgets/service_category_rail.dart` + `service_rail_card.dart` + `service_zone.dart` — zones are
assigned by index rotation over the sorted active list, NEVER by category name, so an admin-added
category needs no app release). Card tap goes straight to Service Detail (packages/plans inline);
"View all" opens `ServiceCategoryGridScreen` — a 2-column grid of the same cards sliced client-side
from the already-loaded catalog (`servicesForCategory`), no intermediate list screens exist anymore.
Detail's "Plan" vs "Package" noun switches on `serviceCategoryFormType == kFormTypeConsultation`
(`utils/inquiry_form_fields.dart`). `InquiryModel` (`serviceName`/`serviceCategoryName`/
`servicePackageName`) powers the category badge on inquiry/lead rows. A consumer submits an `Inquiry`
(a "lead") against a `Service`/`ServicePackage` via `InquiryController.submitInquiry()`, which has
**no coin/wallet parameter** — this is a free lead-generation flow, unrelated to the coin economy
below; every Consultation (Yoga & Diet) package renders "Get Custom Quote" (the team quotes offline).
`InquiryContactSheet` lets a consumer submit under a different name/mobile (e.g. booking for someone
else).
- **`AgentController`** (`lib/controllers/agent_controller.dart`) checks `isAgent` once per session via
  `GET /agents/me` — false for ~all consumer users, never surfaced as an error. `AgentModel` is
  identity-only (id/name/photo, deliberately no phone — contact is one-directional, agent reaches
  customer, never the reverse). `MyLeadsScreen`/`LeadDetailScreen` mirror `MyInquiriesScreen`/
  `InquiryDetailScreen` but scoped server-side to `GET /agents/me/leads`, with a status-update action.
  Profile screen has an agent-only "My Leads" tile, badge-counted.
- **`EscalateInquirySheet`**/`InquiryEscalationModel` let a **consumer** (not the agent) report an issue
  with their assigned agent (Not responding/Unhelpful/Wrong info/Other) — visible only to that consumer
  and Admin, never the agent.
- **`InquiryHubService`** (`lib/services/inquiry_hub_service.dart`) is a push-only, session-lifetime
  SignalR connection delivering live `InquiryStatusChanged` events; falls back silently to pull-to-refresh
  if it never connects. `hub_session_manager.dart` added a single teardown point,
  `disconnectAllHubs()`, concurrently disconnecting all four hubs (Banner/Chat/Wallet/Inquiry) on logout or
  a forced 401 — a revoked session previously left hubs retrying forever with an empty token.

**Notification inbox**: `NotificationController` (`lib/controllers/notification_controller.dart`) fetches
`unreadCount` once at `onInit` and exposes a paginated list (`GET /notifications`) with a `_requestId`
guard against refresh/load-more races. `NotificationModel` carries generic `actionRoute`/`actionArguments`
so tap-routing is generic, not a per-type switch. This inbox is refreshed on-demand/app-resume, not pushed
live over SignalR — a deliberate choice per its own code comment (keeping a 5th hub connection out of the
lazy-hub pattern above wasn't judged worth it for this feature yet).

**Payments**: Razorpay (`razorpay_flutter`) — the coin-pack purchase flow drives the `Razorpay()` SDK
directly inline from `CoinPacksScreen._purchase`, calling `WalletController.createOrder`/`verifyPayment`/
`cancelOrder` around it (order creation and verification happen server-side; the SDK only drives the
native checkout UI and reports success/failure via callbacks). `lib/services/razorpay_service.dart`
(`RazorpayPaymentService`) predates this and is unused by both the old and new flow — a callback wrapper
that was never wired up; leave it alone unless you're specifically consolidating the two Razorpay call
sites.

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
