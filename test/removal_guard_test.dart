import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/config/app_tabs.dart';
import 'package:bakhli/config/module_palette.dart';
import 'package:bakhli/config/user_roles.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/report_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/models/home_feed_model.dart';
import 'package:bakhli/models/question_template_model.dart';
import 'package:bakhli/utils/listing_kind_visuals.dart';
import 'package:bakhli/utils/notification_visuals.dart';
import 'package:bakhli/widgets/role_option_card.dart';
import 'package:flutter_test/flutter_test.dart';

const _removedRoutes = [
  '/my-listings',
  '/my-plots',
  '/listing-detail',
  '/plot-detail',
  '/add-listing',
  '/add-plot',
];

QuestionTemplateModel _template({String listingType = 'Stay', String? stayTypeId}) => QuestionTemplateModel(
      id: 't1',
      key: 'is_available',
      listingType: listingType,
      stayTypeId: stayTypeId,
      questionText: 'Is it available?',
      answerOptions: const [],
      sortOrder: 1,
      isActive: true,
    );

void main() {
  group('G18 tab alignment', () {
    test('five tabs with the new indexes', () {
      expect(AppTabs.home, 0);
      expect(AppTabs.stays, 1);
      expect(AppTabs.trips, 2);
      expect(AppTabs.taxi, 3);
      expect(AppTabs.profile, 4);
      expect(AppTabs.count, 5);
    });

    test('tabKeys map every index to the backend key', () {
      expect(AppTabs.tabKeys, {0: 'HOME', 1: 'STAYS', 2: 'TRIPS', 3: 'TAXI', 4: 'PROFILE'});
      expect(AppTabs.tabKeys.keys.toList()..sort(), List.generate(AppTabs.count, (i) => i));
    });

    test('tab keys match TabConfigController keys', () {
      expect(AppTabs.tabKeys[AppTabs.home], AppTabKeys.home);
      expect(AppTabs.tabKeys[AppTabs.stays], AppTabKeys.stays);
      expect(AppTabs.tabKeys[AppTabs.taxi], AppTabKeys.taxi);
      expect(AppTabs.tabKeys[AppTabs.profile], AppTabKeys.profile);
    });

    test('home feed section keys are stay and taxi only', () {
      expect(HomeSectionKeys.stays, 'stays');
      expect(HomeSectionKeys.taxis, 'taxis');
      expect(HomeSectionKeys.recentStays, 'recentStays');
    });
  });

  group('G20 route registration', () {
    test('removed room and plot routes are not registered', () {
      for (final route in _removedRoutes) {
        expect(AppRoutes.isRegistered(route), isFalse, reason: route);
      }
    });

    test('kept routes are registered', () {
      for (final route in [
        AppRoutes.listingReports,
        AppRoutes.reportDetail,
        AppRoutes.myFiledReports,
        AppRoutes.notifications,
        AppRoutes.main,
        AppRoutes.myStays,
        AppRoutes.myTaxi,
        AppRoutes.stayRooms,
        AppRoutes.stayEnquiries,
        AppRoutes.tripLeads,
        AppRoutes.myTrips,
        AppRoutes.plansBilling,
        AppRoutes.chatConversation,
      ]) {
        expect(AppRoutes.isRegistered(route), isTrue, reason: route);
      }
      expect(AppRoutes.listingReports, '/listing-reports');
    });

    test('route tab keys stay on stays, jobs and taxi', () {
      expect(AppRoutes.tabKeyForRoute(AppRoutes.myStays), AppTabKeys.stays);
      expect(AppRoutes.tabKeyForRoute(AppRoutes.stayRooms), AppTabKeys.stays);
      expect(AppRoutes.tabKeyForRoute(AppRoutes.myJobs), AppTabKeys.jobs);
      expect(AppRoutes.tabKeyForRoute(AppRoutes.myTaxi), AppTabKeys.taxi);
      expect(AppRoutes.tabKeyForRoute(AppRoutes.notifications), isNull);
      for (final route in _removedRoutes) {
        expect(AppRoutes.tabKeyForRoute(route), isNull, reason: route);
      }
    });

    test('owner route sets are unchanged', () {
      expect(AppRoutes.ownerOnly, {AppRoutes.plansBilling, AppRoutes.planHistory});
      expect(AppRoutes.stayOwnerOnly.contains(AppRoutes.myStays), isTrue);
      expect(AppRoutes.stayOwnerOnly.contains(AppRoutes.stayRooms), isTrue);
      expect(AppRoutes.taxiDriverOnly.contains(AppRoutes.myTaxi), isTrue);
      expect(AppRoutes.taxiDriverOnly.contains(AppRoutes.tripLeads), isTrue);
    });

    test('canOpenRoute refuses unregistered routes and keeps role checks', () {
      final auth = AuthController();
      for (final route in _removedRoutes) {
        expect(auth.canOpenRoute(route), isFalse, reason: route);
      }
      expect(auth.canOpenRoute(AppRoutes.notifications), isTrue);
      expect(auth.canOpenRoute(AppRoutes.listingReports), isTrue);
      expect(auth.canOpenRoute(AppRoutes.plansBilling), isFalse);
      expect(auth.canOpenRoute(AppRoutes.myStays), isFalse);
      expect(auth.canOpenRoute(AppRoutes.myTaxi), isFalse);
    });
  });

  group('G10 report base path', () {
    test('Stay and Taxi keep their paths', () {
      expect(ReportController.basePath('Stay'), '/stays');
      expect(ReportController.basePath('Taxi'), '/taxis');
    });

    test('any other kind throws', () {
      for (final kind in ['Room', 'Plot', 'TripEnquiry', '', 'stay']) {
        expect(() => ReportController.basePath(kind), throwsArgumentError, reason: kind);
      }
    });
  });

  group('G13 removed role fails soft', () {
    test('capabilities of kept roles', () {
      expect(identical(RoleCapabilities.of(UserRoleKeys.seeker), RoleCapabilities.none), isTrue);
      expect(RoleCapabilities.of(UserRoleKeys.stayOwner).canListStays, isTrue);
      expect(RoleCapabilities.of(UserRoleKeys.stayOwner).canListTaxis, isFalse);
      expect(RoleCapabilities.of(UserRoleKeys.taxiDriver).canListTaxis, isTrue);
      expect(RoleCapabilities.of(UserRoleKeys.taxiDriver).canListStays, isFalse);
      expect(RoleCapabilities.byRole.keys.toSet(), {'SEEKER', 'STAY_OWNER', 'TAXI_DRIVER'});
    });

    test('RENT_OWNER and PROPERTY_OWNER get no capabilities and the Seeker look', () {
      for (final key in ['RENT_OWNER', 'PROPERTY_OWNER']) {
        expect(identical(RoleCapabilities.of(key), RoleCapabilities.none), isTrue, reason: key);
        expect(RoleCapabilities.of(key).isOwner, isFalse, reason: key);
        expect(RoleCapabilities.of(key).deletionLine, isNull, reason: key);
        expect(RoleVisuals.displayName(key), 'Seeker', reason: key);
        expect(RoleVisuals.displayName(key), RoleVisuals.displayName(UserRoleKeys.seeker), reason: key);
        expect(RoleVisuals.icon(key), RoleVisuals.icon(UserRoleKeys.seeker), reason: key);
        expect(UserRoleKeys.tabKeyOf(key), isNull, reason: key);
      }
    });

    test('kept role names and tab keys', () {
      expect(RoleVisuals.displayName(UserRoleKeys.stayOwner), 'Stay Owner');
      expect(RoleVisuals.displayName(UserRoleKeys.taxiDriver), 'Taxi Driver');
      expect(UserRoleKeys.tabKeyOf(UserRoleKeys.stayOwner), AppTabKeys.stays);
      expect(UserRoleKeys.tabKeyOf(UserRoleKeys.taxiDriver), AppTabKeys.taxi);
      expect(UserRoleKeys.tabKeyOf(UserRoleKeys.seeker), isNull);
    });

    test('deletion lines for kept owner roles', () {
      expect(RoleCapabilities.of(UserRoleKeys.stayOwner).deletionLine, 'Your stay and jobs will be deleted.');
      expect(RoleCapabilities.of(UserRoleKeys.taxiDriver).deletionLine, 'Your taxi will be deleted.');
    });
  });

  group('G22 home feed parse', () {
    test('stays, taxis and recentStays parse; room and plot keys are ignored', () {
      final feed = HomeFeedModel.fromJson({
        'tabs': {'stays': true, 'jobs': true, 'taxi': false, 'rooms': true},
        'stays': [
          {'id': 's1', 'name': 'Hill View', 'districtName': 'Nainital', 'createdAt': '2026-11-01T10:00:00Z'},
        ],
        'taxis': <dynamic>[],
        'recentStays': [
          {'id': 's2', 'districtName': 'Almora'},
        ],
        'rooms': [
          {'id': 'r1'},
        ],
        'plots': [
          {'id': 'p1'},
        ],
      });

      expect(feed.stays, hasLength(1));
      expect(feed.stays!.single.item.id, 's1');
      expect(feed.stays!.single.districtName, 'Nainital');
      expect(feed.stays!.single.createdAt, DateTime.utc(2026, 11, 1, 10));
      expect(feed.taxis, isEmpty);
      expect(feed.recentStays, hasLength(1));
      expect(feed.recentStays!.single.item.title, 'Stay');
      expect(feed.isSectionTabOff('stays'), isFalse);
      expect(feed.isSectionTabOff('recentStays'), isFalse);
      expect(feed.isSectionTabOff('taxis'), isTrue);
      expect(feed.isSectionTabOff('rooms'), isFalse);
    });

    test('a missing section stays null', () {
      final feed = HomeFeedModel.fromJson({'tabs': {'stays': true}});

      expect(feed.stays, isNull);
      expect(feed.taxis, isNull);
      expect(feed.recentStays, isNull);
      expect(feed.isSectionTabOff('taxis'), isFalse);
    });
  });

  group('G9 question templates', () {
    test('Stay template without a type applies to every stay', () {
      expect(_template().appliesTo('Stay'), isTrue);
      expect(_template().appliesTo('Stay', targetStayTypeId: 'x'), isTrue);
    });

    test('Stay template with a type applies only to that type', () {
      final t = _template(stayTypeId: 'type-1');
      expect(t.appliesTo('Stay', targetStayTypeId: 'type-1'), isTrue);
      expect(t.appliesTo('Stay', targetStayTypeId: 'type-2'), isFalse);
      expect(t.appliesTo('Stay'), isFalse);
    });

    test('Stay template never applies to other kinds', () {
      expect(_template().appliesTo('Room'), isFalse);
      expect(_template().appliesTo('Plot'), isFalse);
    });

    test('listingType defaults to Stay when missing', () {
      final t = QuestionTemplateModel.fromJson({'id': 't1', 'key': 'k'});
      expect(t.listingType, 'Stay');
    });
  });

  group('G14 notification kinds', () {
    test('owner routes map to STAY and TAXI only', () {
      expect(NotificationVisuals.listingKind(AppRoutes.myStays), 'STAY');
      expect(NotificationVisuals.listingKind(AppRoutes.myTaxi), 'TAXI');
      expect(NotificationVisuals.listingKind('/my-listings'), isNull);
      expect(NotificationVisuals.listingKind('/my-plots'), isNull);
      expect(NotificationVisuals.listingKind(null), isNull);
    });

    test('listing kind labels', () {
      expect(ListingKindVisuals.labelOf('Stay'), 'STAY');
      expect(ListingKindVisuals.labelOf('Taxi'), 'TAXI');
      expect(ListingKindVisuals.labelOf('Job'), 'JOB');
      expect(ListingKindVisuals.labelOf('Plot'), 'PLOT');
    });

    test('kept module palettes per kind', () {
      expect(identical(ModulePalette.forListingKind('Stay'), ModulePalette.stays), isTrue);
      expect(identical(ModulePalette.forListingKind('Taxi'), ModulePalette.taxi), isTrue);
      expect(identical(ModulePalette.forListingKind('Job'), ModulePalette.jobs), isTrue);
      expect(identical(ModulePalette.forListingKind('Plot'), ModulePalette.rooms), isTrue);
    });
  });

  group('trip v2 routes', () {
    test('the days page and the step page are gone', () {
      expect(AppRoutes.isRegistered('/trip-days'), isFalse);
      expect(AppRoutes.isRegistered('/trip-step'), isFalse);
    });

    test('every trip page of the flow is registered', () {
      for (final route in [
        AppRoutes.tripSpots,
        AppRoutes.tripPlan,
        AppRoutes.tripStay,
        AppRoutes.tripTaxi,
        AppRoutes.tripMap,
        AppRoutes.myTrips,
        AppRoutes.tripReplies,
        AppRoutes.tripTaxiReplies,
        AppRoutes.tripSummary,
      ]) {
        expect(AppRoutes.isRegistered(route), isTrue, reason: route);
      }
    });
  });
}
