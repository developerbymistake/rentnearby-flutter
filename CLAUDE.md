# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Flutter app for the "Bakhli" travel planner (north-India launch states: Uttarakhand, Himachal Pradesh; the Flutter project name
`bakhli` and internal branding are current — the repo directory name, Android `applicationId`
(`com.rentnearby.rentnearby`), and iOS bundle id are legacy `rentnearby` naming that was never
renamed). Plan trips, find stays and taxis, stay jobs, in-app chat between guest and host,
and owner plans (free by default, paid via Google Play subscriptions).

## Commands

```bash
flutter pub get                 # install dependencies

flutter analyze --no-pub        # lint/static analysis (flutter_lints, see analysis_options.yaml); 0 errors at build 56

flutter run                     # run on a connected device/emulator (debug)
flutter run -d chrome           # run on web
flutter run --release           # run in release mode

flutter clean && flutter pub get && flutter build apk --release   # release APK (clean first); output build/app/outputs/flutter-apk/app-release.apk, signed with the upload keystore
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

Current version is `1.0.0+56` (2026-11-02, Trip Planner build). Never bump the `pubspec.yaml` build number unless the user explicitly asks. Project state: `F:\Dhasu\PROJECT_STATUS_2026_11_02.md`.

Only `flutter analyze *` is pre-approved in `.claude/settings.json`; other commands may prompt for
permission.

## Architecture

**State management: GetX (`get` package)** — used for reactive state (`.obs` / `Rx` + `Obx`/`GetX`
widgets), dependency injection (`Get.put`/`Get.find`), and navigation (`GetMaterialApp`,
`Get.toNamed`/`offAllNamed`). There is no `Bindings` layer — dependencies are registered eagerly and
explicitly:
- App-wide singletons (`ConfigRepository`, `TabConfigController`, `NotificationService`, `AuthController`) are
  `Get.put(permanent: true)` in `main()` before `runApp`, in that order: tab state exists before any routing decision.
- Everything else (feature controllers, repositories, hub services) is `Get.put` in
  `MainScreen.initState()` (`lib/screens/main_screen.dart`) in a specific dependency order — read the
  comments there before reordering (e.g. `HomeController.onInit()` looks up `LocationController`, so
  it must be put after it).
- Controllers are looked up elsewhere via `Get.find<T>()`; there is no constructor injection.

**Navigation**: `GetMaterialApp` + named routes declared in `lib/config/app_routes.dart`
(`AppRoutes.routes`, a flat `List<GetPage>` with per-route transitions). The bottom-nav tabs
(`lib/config/app_tabs.dart`: `home(0) / stays(1) / trips(2) / taxi(3) / profile(4)`; Jobs is no longer a tab, it opens from Profile > Activity > Jobs via `/jobs`, `count = 5`; Chat is not a
bottom-nav tab, reached instead via a header icon on Home) are NOT part of this
route table: `MainScreen` renders them as an `IndexedStack` of `TabNavigator` widgets
(`lib/navigation/tab_router.dart`), each wrapping its tab root screen in its own nested `Navigator`
keyed via `lib/navigation/tab_keys.dart`. This isolates keyboard/layout/MediaQuery changes per tab.
The root sits in an `Obx` and is a `SizedBox.shrink()` while `TabConfigController.isActiveForIndex` is false, so an
admin-disabled tab is never built and makes no API call.
The bottom-nav row order is Home, Stays, Trips, Taxi, Profile and matches the index order (Trips root = `MyTripsScreen(root: true)`, always active, not in the backend master table). `_screens` must list the TabNavigators in index order.
Deep/detail screens (payment, chat conversation, etc.) still go through
the global `Get.toNamed` navigator on top of everything, unaffected by which tab is active.

**Home tab root**: Rooms and Plots were removed on 2026-11-06 (no Rooms/Plots tabs, explore screens, listing screens or Go Live). Home shows the Trip card, the Stays and Taxis rails and recently added stays; its banner is an auto-sliding Stay/Taxi owner carousel (`home_owner_carousel.dart`) whose slides and copy follow the role (see "Roles").

Because `IndexedStack` never disposes inactive tabs, a `showModalBottomSheet` opened from a tab-root
screen's own `context` (e.g. `LocationSwitchSheet`, `LocationSearchSheet`, the stay/taxi detail
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
instead of racing. `LogoutReason` (`explicitLogout`/`accountDeleted`/`sessionExpired`/`roleChanged`) decides whether
the server-side revoke call fires and which toast, if any, is shown. A second `Dio`
instance (`_nominatimDio`) hits a self-hosted Nominatim reverse-geocoding proxy. `AppConstants.baseUrl`
(`lib/config/app_constants.dart`) is the single source of truth for the backend origin
(`https://developerbymistake.tech/api/v1`) — commented-out local/emulator URLs are left there for
switching during local backend dev. Real-time features (chat, per-district promotional banners) use
SignalR (`signalr_netcore`) via independent hub services, not Dio: `ChatHubService` (connected
unconditionally from `MainScreen.initState()`, session-lifetime — same shape as `NotificationHubService`, not scoped to any one conversation screen) and `BannerHubService` (connects for
the user's current district whenever `LocationController.selectedDistrict` changes, stays connected while
browsing). All hubs pass a fresh JWT via `accessTokenFactory` so token refresh is handled transparently,
and they fall back silently to REST polling / pull-to-refresh if the hub connection fails.

**Data flow / caching**: `lib/repositories/*` wrap `ApiService` calls with simple in-memory
TTL-based caches (e.g. `PlanRepository` caches `/plans/catalog` for 5 min and `/plans/me`
for 30s) and expose `invalidate()`/`invalidateAll()` for controllers to bust the cache after a
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
persisted, reset on cold start and after a real (>2 min) background resume), and a precise map-search pin override shared between
the Stay and Taxi screens. `effectiveDistrict`/`effectiveCity`/`effectiveSearchCenter` are
the derived getters screens should read rather than picking through the raw fields. `MainScreen`
gates the whole app behind full-screen states driven by this controller: offline, GPS-disabled, and
"district not supported yet" — see `_buildOfflineGate`/`_buildGpsGate`/`_buildDistrictGate`. This gate
wraps the whole app above the `IndexedStack`, regardless of tab count/order.
Business onboarding (Stay/Taxi only): `DistrictModel.businessOnboardingEnabled` (null = unknown) comes from the context call; `stay_basic_details_screen.dart`/`taxi_vehicle_screen.dart` opt in via `initLocationTracking(onOnboardingClosed:, onboardingGrandfathered:)` and show `OnboardingClosedDialog` (`lib/widgets/onboarding_closed_dialog.dart`, title "Not open here yet", with a Change role action when the one-time correction is available) at the pin step on `false` (skipped for the saved pin of an `everApproved` row in the same district) and on a server 400 `OnboardingClosed` at basic save/Submit. Spec `F:\Dhasu\District_resume\ONBOARDING_CONTRACT.md`.

**Pin/radius mechanics** (client-side only; shared by Stay/Taxi/Jobs setup): pin placement is capped to 500m from the
user's live GPS fix (`add_listing_location_mixin.dart`, kept as the shared pin mixin) against a client-computed
distance. Radius is a fixed 3-value chip selector, `AppConstants.radiusOptions = [1.0, 6.0, 12.0]`
(km), not a slider. `explore_location_search_mixin.dart` and `LocationSearchSheet` are shared by Stay, Taxi and Jobs search.

**Maps**: `maplibre_gl` (not Google Maps) using a custom style at `assets/map_style.json`. Map-related
tuning constants (clustering radius, max markers, last-resort fallback centre) live in
`AppConstants`. `lib/config/app_map_state.dart` exposes a single global `mapShouldPause` `RxBool` that
full-screen map routes (stay/taxi setup, trip map) flip so the list screens can swap their live map for a
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
navigation-on-tap behavior. A push with an `action_route` goes through `AuthController.canOpenRoute`; a route the
role cannot open lands on the notifications screen instead (same guard in `notifications_screen.dart`).

**Roles (Seeker / Stay Owner / Taxi Driver)**: one account, one role; spec in `F:\Dhasu\ROLE_FEATURE.md` (Rent Owner and Property Owner were removed on 2026-11-06; an old `RENT_OWNER`/`PROPERTY_OWNER` claim falls back to `RoleCapabilities.none` and the Seeker look, and the DB reset forces a re-login).
- **Stay Owner**: `UserRoleKeys.stayOwner`/`canListStays`; `AppTabs.stays = 1`; gated owner goes to `/stay-setup` until submit (`postLoginRoute`). Code in `lib/features/stay/`. Rooms have a fixed room name (no bathroom). Jobs (`lib/features/jobs/`, Jobs tab `AppTabs.jobs`): all fields required, own phone + WhatsApp on the job, detail bar is the shared `DetailActionBar` with `showDirections: false`, `whatsAppPhone`, `callLabel`, `reportLabel`, `safetyText` (defaults keep Stay unchanged), no Chat; experience is years with Fresher / N+ yrs tags and filter buckets. Seeker push opens `/job-detail` through the generic `action_route` path. Spec: `F:\Dhasu\STAY_FEATURE.md`, `F:\Dhasu\STAY_JOBS_FEATURE.md`.
- **Taxi Driver**: `UserRoleKeys.taxiDriver`/`canListTaxis` (counts as owner everywhere); Taxi tab `AppTabs.taxi` (root `TaxiListScreen(root: true)`, tag `taxi`; pushed copy tag `taxi-push`), no Taxi tile on the Stays landing. The stay detail "Getting there" row searches From = traveller's current GPS city (`travellerCity`, never the browsing city) to To = stay city centroid; See all pushes the Taxi list prefilled. Gated driver goes to `/taxi-setup` until submit (`postLoginRoute`). Code in `lib/features/taxi/`. Taxi list From/To use `LocationSwitchSheet.pick`; driver route From/To use `LocationSearchSheet` (Photon, no bbox; results ranked by place type and the user's state). Share link type `t` opens `/taxi-detail` directly. Spec: `F:\Dhasu\TAXI_FEATURE.md`.
- **Trip Planner v2 (any role, not a tab; flow rebuilt 2026-11-07, contract `F:\Dhasu\TripV2_resume\CONTRACT_V2.md`, mock `F:\Dhasu\Mode\trip_flow_v2_mockup.html`)**: code in `lib/features/trip/`.
  Entry: Home `TripHomeCard` (opens `TripCitySheet.pick`) and the Profile `My Trips` tile.
  Flow: cities (multi-select, ordered) -> `/trip-days` (days stepper, hint `Up to D x 6 places`) -> `/trip-spots` once per city with a live limit -> plan -> `Make it easy` card.
  Routes (all pushed on the global navigator, all in `MapPauseObserver._pauseRoutes`): `/trip-days`, `/trip-spots`, `/trip-plan`, `/trip-stay`, `/trip-taxi`, `/trip-map`, `/my-trips`, `/trip-replies`, `/trip-taxi-replies`, `/trip-summary`.
  Deleted screens: the Basic details sheet before the plan, `/trip-step` and the step pages, the wizard controller and rules, own booking and own travel sheets, night chooser, shortlist bar, no-taxi flow, hero and milestone cards. Never bring them back.
  Hard cap: 6 places a day (`TripConstants.maxSpotsPerDay`, `TripDaysRules`), enforced in the app and by the server (`TooManySpotsPerDay`, `TooManySpotsForDays`, shown through `DioErrorMapper`).
  Plan JSON is v6 (`TripConstants.planVersion`): `TripDay` = day, leg, restDay, spots only; `TripSettings` = pace, startDate, adults, kids, maxDays (dates and people may be null); marks `stayMark` (per leg), `travelMark` (legs 2+), `taxiMark` with status `own` or `skipped` and nothing else; `TripTravel` is journey-only.
  Pace: default Relaxed 300, Normal 450, set from the plan header chip (`setPace`), not asked up front.
  Make it easy rows (`TripEasyRowKey`): `gettingThere`, `stay:k` (per city), `between:k`, `taxi` (one row), `comingBack`. States `TripRowState`: todo, asked, offer, confirmed, booked ("Booked by you": traveller phone booking or "I booked" taxi/car, counts as done, host/driver need not confirm), own, saved, skipped, attention. Partial stay cover: `TripEasyRowInfo.nightsTotal/nightsCovered/uncoveredDays/partial/isDone` (subtitle `Asked · 2 of 3 nights`, link `Ask last night`/`Ask N more nights` -> `TripNavigation.openStay(leg, onlyDays:)`; a partial row is not done). Row menu (more_vert) on asked/offer rows = "I'll arrange myself"; Skip also on attention rows (blocked while an open or confirmed ask exists). Day header shows an amber `Long day` chip over the pace limit; the spots bar says `Pick at least one place` at creation with 0 picked. City sheet: a listed NotReady city is pickable at creation and reads `No places yet`. `TripEasyRules` (app) mirrors server `TripEasyRows`; progress is `done of total arranged`, skipped rows leave the total.
  Actions: Help me find (asks dates and people once in `TripDatesSheet`, then stay, taxi or ways), I'll arrange myself (`TripArrangeConfirm`, one confirm, stores only the mark, `markOwn`/`undoMark`), Skip (`skipRow`). Call + WhatsApp + Ask on every stay and driver card.
  Plan header: pace chip, progress ring, state pill, menu (Save & exit, Edit days, Edit dates and people, Mute, Mark complete, Delete). Edit state: drag, remove with Undo, Add a place, rest day, Add a day, Remove day.
  Date change after asking: `TripUpdateAskSheet` (Update ask / Keep as is; shown after a dates edit and after any days edit through `TripUpdateAskSheet.afterDaysEdit`); server closes open asks outside the new dates, confirmed bookings keep their dates.
  Unchanged: chat, ask, offer, counter, revised offer, change request, advance, phone booking, I booked (taxi), ask both drivers, journeys, reminders, problem report, summary share.
  City pick = `TripCitySheet` (Atlas cities via `GET /trips/cities`, NotReady rows "No places yet", still pickable) over its own cache `TripCityCatalog` (keys `trip_cities_cache*`, 24 h, revalidated by `GET /trips/cities/version` every 10 min, local search). Spots come from `GET /trips/cities/{cityKey}/spots` (`NotReady` or 404 `CityNotFound` = "Not ready yet").
  `TripPlanController` (lazy `to`, deleted by `releaseIfIdle()` when `openPages == 0`) holds the working `TripPlan`; the draft is created at Make my plan and autosaved (debounced); a failed save keeps the plan and shows `Not saved yet` + Retry. `/trips/plan` splits days (`auto`) or recomputes times (`recalculate`, never reorders).
  Stay and taxi lists reuse `TaxiCard`, `NearbyItemRow`, district-wide `/taxis/browse` and `/stays/nearby`; a 403 `TabInactive` hides that option; 403 `TripPlannerDisabled` shows "Not available right now".
  Offline: banner `Offline. Your plan is saved on this phone.`; asks need a connection (no queue); failed rows show `Could not load.` + Retry.
  Status look comes only from `TripDisplayStatus` / `TripStatusVisuals` / `TripStatusPill` / `TripStatusCard`; copy from `TripStrings*` (v2 copy in `trip_strings_v2_*.dart`); limits in `TripConstants`. No payment UI; wording is "host says", never "verified".
  Tests: `trip_plan_model_test`, `trip_model_test`, `trip_easy_rules_test`, `trip_days_rules_test`, `trip_summary_text_test`, `trip_plan_controller_test`, `trip_bar_rules_test`, `dio_error_mapper_test`, `trip_spot_model_test`.
  Spots list = photo cards (`trip_spot_row.dart`) + `TripSpotDetailSheet` (swipeable gallery); `TripSpotModel.images` (cover first, `gallery` falls back to `imageUrl`), `photoFirst` sorts photo spots first inside the same rank; no image credit or licence anywhere.
  Spots extras: Must see rail, Quick starts (`TripSpotPicks`, deterministic bundles), inline "Goes well together" suggestion, route strip in the bar, offline list cache (`TripSpotsCache`, 24 h); road minutes from `POST /trips/cities/{cityKey}/spots/minutes` (`TripRepository.spotMinutes`, `available:false` = show km, never km as minutes). Test: `trip_spot_picks_test`.
  Search text is matched through `SearchFold` (`lib/utils/search_fold.dart`, same rule as Atlas `SearchKeys.Fold`: accents stripped, ASCII a-z/0-9 only). Photon rows read `Type · District, State` and are ranked by `preferState` then place type. Atlas `isPopularDestination` drives the Trip picker "Popular" section and the Home `TripPopularRail` (user state first).
- `lib/config/user_roles.dart` is the single capability map: `UserRoleKeys` (`SEEKER`/`STAY_OWNER`/
  `TAXI_DRIVER`, `claim = 'role'`; names via `RoleVisuals.displayName` in `role_option_card.dart`), `RoleCapabilities.byRole` (role key -> `canListStays`,
  `canListTaxis`; Seeker has neither, an unknown key falls back to none), `RoleRequestErrorTypes` and
  `RoleRequestStatus`. Add a role there, never as scattered `== 'STAY_OWNER'` checks.
- `AuthController` reads the `role` claim from the stored JWT (`_syncRoleFromToken`, via `JwtClaims.role`) and
  exposes reactive `roleKey`, `canListStays`, `canListTaxis`, plus `isOwner` (derived convenience only) and
  `canOpenRoute(route)` (returns false for a route with no `GetPage` in `AppRoutes.routes`, via `AppRoutes.isRegistered`, so a stale `/my-listings` push falls back to the inbox; also checks the tab key). `chooseRole` calls `PUT /users/me/role-choice` and stores the returned token;
  `requestRoleChange` posts `/users/me/role-request` and shows the server's cooldown/live-listing message.
  `roleChangeLocked` = `user.roleLocked` (server: Stay/Taxi Approved, under review or ever approved) OR the status check.
  `correctRole(key)` (one-time Draft correction) calls `PUT /users/me/role-correction`, `_applySession`, clears `StaySetupController`/`TaxiSetupController` (`clear()`), then `Get.offAllNamed(postLoginRoute)`; 409s show the server message and run `_recoverChosenRole()`; never goes through `LogoutReason.roleChanged`.
  `UserModel` carries `roleCorrectionUsed`, `canCorrectRole`, `roleLocked` (all default false).
- Correction link: the Stay/Taxi setup hub shows a small "Wrong role? Change it" link (accent dark) only while the stay/taxi is a Draft and `user.canCorrectRole`, and hides the menu "Change role" while it shows. `StayOwnerModel.setupPercent` (40/30/20/10, also used by the hub) and `TaxiOwnerModel.percent` feed the dialog text.
- `RoleSelectScreen` registers `LocationController` (permanent) like the setup hubs, so the offline/GPS/district gates cover the role page.
- **Taxi identity (DL + DOB)**: `taxi_vehicle_screen.dart` step Driver collects the driving licence number and date of birth (picker, no free text); rules in `features/taxi/setup/taxi_identity_validators.dart` mirror `TaxiIdentityRules` on the server (strict 15-char DL, age ≥ `minAgeYears`, DL year ≥ DOB year + 18). The owner DTO only carries `hasDrivingLicence`/`hasDateOfBirth`; empty field with `Saved` = keep (`null` in the payload). Submit returns 400 `TaxiIdentityRequired` until both exist; a DL/DOB change on an Approved taxi goes back to review.
- **Stay registration**: `stay_basic_details_screen.dart` collects a registration type (from `GET /stays/registration-types`, `StayRegistrationTypesController`, 1 h TTL, never hardcoded), a document name for a `requiresOtherName` type, a registration number (Udyam format when `code == 'UDYAM'`, else generic) and an optional GSTIN (Luhn mod 36 check); rules in `features/stay/setup/stay_registration_validators.dart` mirror `StayRegistrationRules`. Owner DTO carries `registrationTypeId/Name`, `registrationOtherName`, `hasRegistrationNumber`, `hasGstin` only; `null` = keep, `''` clears the GSTIN. Submit returns 400 `StayRegistrationRequired` until done.
- Post-login routing: `AuthController.postLoginRoute` = `AppRoutes.main` once `user.roleConfirmed`, else
  `AppRoutes.roleSelect`; splash and the login/OTP flows navigate to it, and a cold-start notification tap is ignored while it is `roleSelect`.
- Pages: `RoleSelectScreen` (first login, 3 cards from `GET /roles`, Seeker preselected, applies immediately; with arguments `{"correction": true, "percent": p}` it is in correction mode: Back, current role hidden, subtitle "One-time change.", Continue opens a confirm dialog "Delete draft and change role?" then `correctRole`) and
  `RoleChangeScreen` (from the Profile Account row 'Change role'; the row reads 'Current role' + role name, no arrow and no tap when `roleChangeLocked`; sends an admin-approval request); cards and per-role colors/icons
  live in `widgets/role_option_card.dart` (`RoleVisuals`, `RoleOptionCard`). Approval revokes the session: the
  `role_request_approved` push or hub event calls `forceLogout(reason: LogoutReason.roleChanged)`.
- Gating (hide the entry point AND guard the choke point): Home banner shows both slides (Stay, Taxi) to a Seeker and only the
  own-kind slide to an owner; the Home leads tile (stays: My Stays, taxis: My Taxi) renders only for an
  owner and only for the kind they list; `tour_registry.dart` skips
  owner steps. All of these use the effective (role AND tab) getters, see "Tab gating".

**Plans (replace the coin/credit economy, 2026-10-30)**: coins, the wallet and credit packs are gone. Owners (Stay, Taxi) have a free default plan per feature and may buy a paid plan (auto-renewing Google Play subscription, 1 / 3 / 12 month base plans); Seeker has no plans. Spec: `F:\Dhasu\PLAN_PAYMENT_MODEL.md` sections 19 and 22, contract `F:\Dhasu\PLAY_BILLING_CONTRACT.md`.

- **`PlanController` / `PlanRepository`** (`lib/controllers/plan_controller.dart`, `lib/repositories/plan_repository.dart`) are the single owner of plan state. `GET /plans/catalog` (5 min TTL) and `GET /plans/me` (30 s TTL, the single source for limits `{listingLimit, used, live, priority, featured, jobsPosts}`, plan, `endsAt`, `trialAvailable`, `openPurchaseId`, `pausedByPlanCount`, `paymentEnabled`, `paymentProvider`, `carryOverDays`, `manageUrl`, `play`). Invalidate `/plans/me` after purchase, trial, create, delete and on a `plan_*` push. Screens and cards read it via `Obx`; never fetch plan data per card or per screen. Also quote, create purchase, verify-play, restore, poll `GET /plans/purchases/{id}`, `GET /plans/purchases/open` (killed-app recovery on start/resume), history and trial.
- **`PlansBillingScreen`** (route `/plans`, from the Profile 'Plans & Billing' tile, owners only): current-plan card (included list), Free-vs-paid compare table built from `PlanModel.features` (`ListingLimit`, `Priority`, `Featured`, `JobsPosts`), duration radio rows (`PlanCycleOption`) with per-month price and Save % from Play store prices, a sticky bottom bar with the price and one CTA (Continue / Switch / Renew / Resubscribe / Current plan / Retry) plus the trial button, a 'Have a coupon?' link that reveals the coupon field, Restore purchases, and a History button in the header opening `PlanHistoryScreen` (`/plans/history`, same list as before, 'No payments yet' empty state, `historyLoadFailed` flag). The purchase status sheet polls until Granted. Prices shown are the store `formattedPrice` from Play, never the backend mirror. The current-subscription block (`PlanSubscriptionCard`) renders from `myPlan.play`: renews on / ends on + Resubscribe / payment issue / on hold / paused / ended / scheduled change / carry-over days, plus a Manage in Google Play link. With `paymentEnabled` OFF the screen shows the Free card plus 'Paid plans are coming'. Short English copy, heading first, module accent tokens only.
- **Profile**: header (name, phone), then the Plans & Billing tile (plan name only; Upgrade/Manage, chevron when payment is off), then Account (phone, contact visibility, role row). The old role card and header chip are gone.
- `ConfigRepository` has no `getListingLimits`; it keeps `payment-feature` (with `freeModeListingLimit`, inert). Go Live, Swap and the Room/Plot permission services were removed on 2026-11-06.
- Stay Jobs cap (`maxActive`/`canPost`) now comes from the plan; the over-limit message carries an Upgrade hint.
- `ConfigRepository` is put permanently in `main()`; `ConfigController`, `PlanRepository`/`PlanController` are registered in `MainScreen.initState()`.

**Hubs**: `NotificationHubService` (`lib/services/notification_hub_service.dart`, `/hubs/notification`) is a
push-only, session-lifetime SignalR connection connected unconditionally from `MainScreen.initState()`/
app-resume (same shape as Chat, not lazily via a screen or business check), delivering a generic
`NotificationReceived` envelope; it falls back silently to pull-to-refresh if it never connects.
`hub_session_manager.dart` is the single teardown point, `disconnectAllHubs()`, concurrently disconnecting
all three hubs (Banner/Chat/Notification) on logout or a forced 401 — a revoked session previously
left hubs retrying forever with an empty token.

**Notification inbox**: `NotificationController` (`lib/controllers/notification_controller.dart`) fetches
`unreadCount` once at `onInit` and again on app resume (the REST anchor that keeps cold-start/reopen
correct) and exposes a paginated list (`GET /notifications`) with a `_requestId` guard against
refresh/load-more races. `NotificationModel` carries generic `actionRoute`/`actionArguments` so
tap-routing is generic, not a per-type switch. `NotificationHubService`'s `NotificationReceived` push also
reaches this controller live (`applyLiveNotification` — increments `unreadCount` and prepends into
`notifications` if already loaded), so the bell updates immediately in foreground instead of only on the
next resume/pull-to-refresh.

**Payments (Google Play Billing, auto-renewing subscriptions)**: spec `F:\Dhasu\PLAY_BILLING_CONTRACT.md`, setup `F:\Dhasu\PLAY_CONSOLE_SETUP.md`, tests `F:\Dhasu\PLAY_BILLING_TEST_PLAN.md`.
- **Gateway**: `lib/services/billing/billing_gateway.dart` (interface), `play_billing_gateway.dart` (`in_app_purchase`, Billing Library 8+ via `in_app_purchase_android`) and `razorpay_gateway.dart` (dormant wrapper of the old checkout code). `PlanController` picks the gateway from `myPlan.paymentProvider` (`'Play'` default, `'Razorpay'` only when the admin flips the backend flag); gateways are plain objects owned by the controller, not `GetxService`s, and `onClose`/`clear()` cancel the purchase stream and dispose them. `razorpay_flutter` stays in pubspec.
- **Flow**: load products by `plan.playProductId`, quote, `POST /plans/purchases` (returns `playProductId`, `playBasePlanId`, `playOfferId`, `obfuscatedAccountId`), `buyNonConsumable` with `applicationUserName = obfuscatedAccountId` and the offer token, stream `purchased` -> `POST /plans/purchases/{id}/verify-play {purchaseToken, productId}` (retry on network/503, then poll). Routing is on `order.provider == 'Play'`, never on `requiresPayment` (a trial is a Play order with amount 0; only a FreePlan coupon is an inline Rs 0 grant). The backend is the only caller of Google (`subscriptionsv2.get`) and the only one that acknowledges: the app NEVER calls `completePurchase` for Play purchases.
- **Restore**: `restorePurchases({force, userInitiated})` posts owned tokens to `POST /plans/purchases/restore` (max 10, results matched by `index`). The automatic call (init, app resume) is throttled to once per 2 min and silent: it refreshes `me` and records `otherAccountProducts` / `detachedProducts`, but never sets `activePurchase`. Only `userInitiated` calls (Restore button, `launch()==false`, `error` after launch, e.g. ITEM_ALREADY_OWNED) may open the `OtherAccount` / `Detached` / pending sheet. A `purchased`/`restored` event that does not match the in-flight order's `productId` goes to restore (one item), not verify-play.
- **Switch** (cycle/plan change on a Play-owned plan): quote returns `playReplacementMode` (`chargeFullPrice` | `withoutProration` | `deferred`); the order carries `playOldPurchaseToken`; the app finds the owned purchase by that token (one `restore()` if missing) and passes `ChangeSubscriptionParam`. Deferred changes keep the current plan until renewal (`play.scheduledPlanName`).
- **Controller API** used by UI: `storeState`, `storeProducts`, `ownedPurchases`, `otherAccountProducts`, `detachedProducts`, `isRestoring`, `paymentProvider`/`isPlay`, `storePriceFor(plan, cycle)`, `trialOfferFor(plan)`, `loadStore`/`reloadStore`, `quote`, `purchase(..., useTrial)`, `restorePurchases`, `openManageSubscription()` (`myPlan.manageUrl`, external `url_launcher`). UI never imports `in_app_purchase`. The trial button needs `myPlan.trialAvailable && trialOfferFor(plan) != null`.
- **States** from `myPlan.play` (`PlaySubInfo`): active (auto-renew) shows "Renews on X" and no Home nudge; cancelled shows "Ends on X" + Resubscribe; grace shows "Payment issue" + Fix; on hold / paused show a strip even while the user is on the free plan; ended shows "Subscription ended - Resubscribe". Non-Play rows keep "N days left" + "Renew". Pushes `plan_renewed`, `plan_on_hold`, `plan_paused`, `plan_carry_over_activated` invalidate `/plans/me`; `plan_payment_issue` only invalidates `/plans/me`.
- **Android platform**: no `BILLING` permission in the manifest (the Billing Library merges it), `minSdk = flutter.minSdkVersion` (24, the plugin needs 23), `queries` unchanged (the manage link is `https`, already declared). ProGuard has `-keep class com.android.vending.billing.** { *; }` and `-dontwarn com.android.billingclient.**` (need unverified, harmless). Purchases only work from a Play-published build (Internal testing track) with a license-tester account; a sideloaded APK cannot buy.
- `paymentEnabled` is OFF by default and is flipped last in the admin app, after the Console setup.

**Folder layout** (`lib/`):
- `config/` — constants, colors, theme, insets, route table, tab indices, map-pause flag
- `controllers/` — `GetxController`s holding reactive UI state per feature area
- `repositories/` — thin TTL-caching wrappers around `ApiService` calls
- `services/` — cross-cutting singletons (`GetxService`s) and static facades: API/storage/auth-token
  plumbing, SignalR hubs, FCM/local notifications, billing gateways (`services/billing/`), permission-gating logic
- `models/` — plain Dart classes with hand-written `fromJson`/`toJson` (no code generation/freezed)
- `screens/` — one file per full-screen route; mixins (e.g.
  `explore_location_search_mixin.dart`) factor out logic shared by Stay, Taxi and Jobs
  screens rather than a common base class
- `widgets/` — reusable presentational components (cards, sheets, pins, bottom-sheet action bars)
- `navigation/` — the per-tab nested-Navigator machinery described above
- `utils/` — small helpers (e.g. `app_toast.dart` wraps `toastification` for consistent toast styling;
  `input_formatters.dart` exports `noEmojiInputFormatters`, applied to every genuine free-text
  `TextField`/`TextFormField` in the app — city search, descriptions, addresses, report details, chat
  search, name fields — apply it to any new free-text field too. Numeric fields (price, area,
  phone/OTP) use their own digit-only formatters instead and don't need it)

**Tab gating (admin turns a tab off)**: spec `F:\Dhasu\TAB_GATING_FEATURE.md`; the backend is the real gate
(403 `TabInactive` on `/stays`, `/taxis`, `/stay-jobs`). `TabConfigController` is the one
client snapshot: seeded from storage, fetched once in `onInit`, `ready` (splash waits on it with the version check),
`version` (bumped only on a real change; its getters read it, so any `Obx` using them rebuilds), single-flight `load`,
`isActiveForIndex` (Jobs needs JOBS and STAYS), `activeSectionKeys` for `/home/feed`. `AuthController` exposes
effective capabilities `staysEnabled`/`taxisEnabled`/`jobsEnabled`/`effectiveIsOwner`
(role AND tab) and `roleTabActive`; `postLoginRoute`, `canOpenRoute` (also checks `AppRoutes.tabKeyForRoute`), add
flows, tiles, tours and my-list loads use them, raw `canListX` stay for role change and contact visibility.
`StayTypesController` loads from `StayLandingController.refreshIfNeeded`.
`MainScreen` has one `ever(version)` worker that leaves an inactive current tab for Home. The `ApiService` error
interceptor calls `TabConfigController.load(forceRefresh: true)` on a 403 `TabInactive`. Deep links check the tab
before the by-slug call. Role screens trust the server-filtered `GET /roles`; `chooseRole`/`requestRoleChange`
return `RoleActionResult.unavailable` on 400 `RoleUnavailable` and the screen reloads. App-wide location calls use
the ungated `/locations/context`, `/locations/districts`, `/locations/districts/{id}/boundary`, `/locations/cities`.

**Theming**: single fixed light theme (`lib/config/app_theme.dart` + `app_colors.dart`), Material 3,
Poppins font family declared in `pubspec.yaml`. No dark mode, no localization/i18n setup — all UI
strings are hard-coded English inline in widgets. Module palettes (`ModulePalette.rooms` is a kept legacy name still used by Home and the location sheets; stays / jobs / taxi) live in
`config/app_colors.dart` + `config/module_palette.dart`; `LocationSwitchSheet`, `LocationSearchSheet` and `LocationPill`
take a `ModulePalette` (the tab they open from), and `LocationSwitchSheet.pick` returns a `PickedPlace` without
touching the browsing city. No raw hex outside `app_colors.dart`.

**Conventions worth matching**:
- Older controllers/services (`AuthController`, `LocationController`, `NotificationService`,
  `StorageService`) are dense with long "why" comments around ordering, race conditions, and
  state-invalidation subtleties — read them before changing adjacent logic, they still explain real
  non-obvious constraints. But for new code and edits anywhere in this repo (UI or not), the project
  owner has repeatedly asked for minimal comments — do not add multi-line rationale blocks or explain
  what a change does; at most one short line, only for a genuinely non-obvious hidden constraint. Do
  not extend the old dense-comment style into new work.
- Error handling in controllers typically translates `DioException` status codes into user-facing
  strings via small private static `_xxxError`/`_dioMessage` helpers (see `AuthController`) rather
  than surfacing raw exceptions.
- Git commit messages follow Conventional Commits style: `feat:`, `fix:`, `chore:`, with an optional
  scope, e.g. `fix(chat): ...`, `feat(home): ...`.
