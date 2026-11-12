import 'package:get/get.dart';
import '../../config/app_routes.dart';
import '../../design/design.dart';
import 'screens/job_detail_screen.dart';
import 'v2/jobs_landing_screen_v2.dart';
import 'screens/my_jobs_screen.dart';
import 'screens/post_job_screen.dart';

final List<GetPage> jobPages = [
  GetPage(
    name: AppRoutes.jobs,
    page: () => const JobsLandingScreenV2(),
    customTransition: TemplateTransition(),
    transitionDuration: templateTransitionDuration,
  ),
  GetPage(
    name: AppRoutes.myJobs,
    page: () => const MyJobsScreen(),
    customTransition: TemplateTransition(),
    transitionDuration: templateTransitionDuration,
  ),
  GetPage(
    name: AppRoutes.postJob,
    page: () => const PostJobScreen(),
    customTransition: TemplateTransition(),
    transitionDuration: templateTransitionDuration,
  ),
  GetPage(
    name: AppRoutes.jobDetail,
    page: () => const JobDetailScreen(),
    customTransition: TemplateTransition(),
    transitionDuration: templateTransitionDuration,
  ),
];
