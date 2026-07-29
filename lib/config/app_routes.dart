import 'package:get/get.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/app_intro_screen.dart';
import '../screens/phone_verify_screen.dart';
import '../screens/main_screen.dart';
import '../screens/listing_detail_screen.dart';
import '../screens/add_listing_screen.dart';
import '../screens/add_plot_screen.dart';
import '../screens/my_listings_screen.dart';
import '../screens/my_plots_screen.dart';
import '../screens/plot_detail_screen.dart';
import '../screens/chat_conversation_screen.dart';
import '../screens/chats_list_screen.dart';
import '../screens/listing_reports_screen.dart';
import '../screens/report_detail_screen.dart';
import '../screens/my_filed_reports_screen.dart';
import '../screens/view_all_screen.dart';
import '../screens/credit_packs_screen.dart';
import '../screens/redeem_code_screen.dart';
import '../screens/wallet_ledger_screen.dart';
import '../screens/service_category_grid_screen.dart';
import '../screens/service_detail_screen.dart';
import '../screens/enquiry_form_screen.dart';
import '../screens/enquiry_confirmation_screen.dart';
import '../screens/my_enquiries_screen.dart';
import '../screens/enquiry_detail_screen.dart';
import '../screens/my_leads_screen.dart';
import '../screens/lead_detail_screen.dart';
import '../screens/agent_dashboard_screen.dart';
import '../screens/notifications_screen.dart';
import '../controllers/view_all_controller.dart' show ViewAllListingType;

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String intro = '/intro';
  static const String onboarding = '/onboarding';
  static const String phoneVerify = '/phone-verify';
  // keep /otp as alias for phone-verify (backward compat for any deep links)
  static const String otp = '/otp';
  static const String main = '/main';
  static const String listingDetail = '/listing-detail';
  static const String plotDetail = '/plot-detail';
  static const String addListing = '/add-listing';
  static const String addPlot = '/add-plot';
  static const String myListings = '/my-listings';
  static const String myPlots = '/my-plots';
  static const String chatConversation = '/chat-conversation';
  static const String chatsList = '/chats-list';
  static const String listingReports = '/listing-reports';
  static const String reportDetail = '/report-detail';
  static const String myFiledReports = '/my-filed-reports';
  static const String viewAllRooms = '/view-all-rooms';
  static const String viewAllPlots = '/view-all-plots';
  static const String creditPacks = '/credit-packs';
  static const String redeemCode = '/redeem-code';
  static const String walletLedger = '/wallet-ledger';

  // Local Services Marketplace — Consumer catalog + Enquiry submission flow.
  // Categories are the top level: rail card -> Service Detail directly, and
  // "View all" -> the card grid (no intermediate list screens). Service
  // Detail renders every package/plan inline (no separate Package List route).
  static const String serviceCategoryGrid = '/service-category-grid';
  static const String serviceDetail = '/service-detail';
  static const String enquiryForm = '/enquiry-form';
  static const String enquiryConfirmation = '/enquiry-confirmation';
  static const String myEnquiries = '/my-enquiries';
  static const String enquiryDetail = '/enquiry-detail';

  // Agent-as-User — conditional "My Leads" section in Profile, only visible when
  // the logged-in account is linked to an Agent.
  static const String myLeads = '/my-leads';
  static const String leadDetail = '/lead-detail';
  static const String agentDashboard = '/agent-dashboard';

  // Notification inbox — backs the Home-screen bell icon.
  static const String notifications = '/notifications';

  static final routes = [
    GetPage(name: splash, page: () => const SplashScreen()),
    GetPage(
      name: login,
      page: () => const LoginScreen(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 400),
    ),
    GetPage(
      name: intro,
      page: () => const AppIntroScreen(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 400),
    ),
    GetPage(
      name: onboarding,
      page: () => const OnboardingScreen(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 400),
    ),
    GetPage(
      name: phoneVerify,
      page: () => const PhoneVerifyScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: otp,
      page: () => const PhoneVerifyScreen(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 400),
    ),
    GetPage(
      name: main,
      page: () => const MainScreen(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 400),
    ),
    GetPage(
      name: listingDetail,
      page: () => const ListingDetailScreen(),
      transition: Transition.downToUp,
      transitionDuration: const Duration(milliseconds: 350),
    ),
    GetPage(
      name: plotDetail,
      page: () => const PlotDetailScreen(),
      transition: Transition.downToUp,
      transitionDuration: const Duration(milliseconds: 350),
    ),
    GetPage(
      name: addListing,
      page: () => const AddListingScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: addPlot,
      page: () => const AddPlotScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: myListings,
      page: () => const MyListingsScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: myPlots,
      page: () => const MyPlotsScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: viewAllRooms,
      page: () => const ViewAllScreen(listingType: ViewAllListingType.rooms),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: viewAllPlots,
      page: () => const ViewAllScreen(listingType: ViewAllListingType.plots),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: creditPacks,
      page: () => const CreditPacksScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: redeemCode,
      page: () => const RedeemCodeScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: walletLedger,
      page: () => const WalletLedgerScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: chatConversation,
      page: () => const ChatConversationScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: chatsList,
      page: () => const ChatsListScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: listingReports,
      page: () => const ListingReportsScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: reportDetail,
      page: () => const ReportDetailScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: myFiledReports,
      page: () => const MyFiledReportsScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: serviceCategoryGrid,
      page: () => const ServiceCategoryGridScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: serviceDetail,
      page: () => const ServiceDetailScreen(),
      transition: Transition.downToUp,
      transitionDuration: const Duration(milliseconds: 350),
    ),
    GetPage(
      name: enquiryForm,
      page: () => const EnquiryFormScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: enquiryConfirmation,
      page: () => const EnquiryConfirmationScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: myEnquiries,
      page: () => const MyEnquiriesScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: enquiryDetail,
      page: () => const EnquiryDetailScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: myLeads,
      page: () => const MyLeadsScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: leadDetail,
      page: () => const LeadDetailScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: agentDashboard,
      page: () => const AgentDashboardScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: notifications,
      page: () => const NotificationsScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
  ];
}
