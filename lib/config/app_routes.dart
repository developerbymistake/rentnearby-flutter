import 'package:get/get.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/phone_verify_screen.dart';
import '../screens/main_screen.dart';
import '../screens/listing_detail_screen.dart';
import '../screens/add_listing_screen.dart';
import '../screens/add_plot_screen.dart';
import '../screens/my_listings_screen.dart';
import '../screens/my_plots_screen.dart';
import '../screens/plot_detail_screen.dart';
import '../screens/chat_conversation_screen.dart';
import '../screens/listing_reports_screen.dart';
import '../screens/report_detail_screen.dart';
import '../screens/my_filed_reports_screen.dart';
import '../screens/view_all_screen.dart';
import '../screens/coin_packs_screen.dart';
import '../screens/redeem_code_screen.dart';
import '../screens/wallet_ledger_screen.dart';
import '../screens/service_catalog_list_screen.dart';
import '../screens/service_detail_screen.dart';
import '../screens/inquiry_form_screen.dart';
import '../screens/inquiry_confirmation_screen.dart';
import '../screens/my_inquiries_screen.dart';
import '../screens/inquiry_detail_screen.dart';
import '../screens/my_leads_screen.dart';
import '../screens/lead_detail_screen.dart';
import '../controllers/view_all_controller.dart' show ViewAllListingType;

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
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
  static const String listingReports = '/listing-reports';
  static const String reportDetail = '/report-detail';
  static const String myFiledReports = '/my-filed-reports';
  static const String viewAllRooms = '/view-all-rooms';
  static const String viewAllPlots = '/view-all-plots';
  static const String coinPacks = '/coin-packs';
  static const String redeemCode = '/redeem-code';
  static const String walletLedger = '/wallet-ledger';

  // Local Services Marketplace / Expert Consultations — Consumer catalog +
  // Inquiry submission flow. Service Detail renders every package/plan
  // inline (no separate Package List route).
  static const String serviceCategoryList = '/service-category-list';
  static const String serviceList = '/service-list';
  static const String serviceDetail = '/service-detail';
  static const String inquiryForm = '/inquiry-form';
  static const String inquiryConfirmation = '/inquiry-confirmation';
  static const String myInquiries = '/my-inquiries';
  static const String inquiryDetail = '/inquiry-detail';

  // Agent-as-User — conditional "My Leads" section in Profile, only visible when
  // the logged-in account is linked to an Agent.
  static const String myLeads = '/my-leads';
  static const String leadDetail = '/lead-detail';

  static final routes = [
    GetPage(name: splash, page: () => const SplashScreen()),
    GetPage(
      name: login,
      page: () => const LoginScreen(),
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
      name: coinPacks,
      page: () => const CoinPacksScreen(),
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
      name: serviceCategoryList,
      page: () => const ServiceCatalogListScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: serviceList,
      page: () => const ServiceCatalogListScreen(),
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
      name: inquiryForm,
      page: () => const InquiryFormScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: inquiryConfirmation,
      page: () => const InquiryConfirmationScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: myInquiries,
      page: () => const MyInquiriesScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: inquiryDetail,
      page: () => const InquiryDetailScreen(),
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
  ];
}
