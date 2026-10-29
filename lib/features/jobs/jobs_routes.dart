import 'package:get/get.dart';
import '../../config/app_routes.dart';
import 'screens/job_detail_screen.dart';
import 'screens/my_jobs_screen.dart';
import 'screens/post_job_screen.dart';

final List<GetPage> jobPages = [
  GetPage(
    name: AppRoutes.myJobs,
    page: () => const MyJobsScreen(),
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: 300),
  ),
  GetPage(
    name: AppRoutes.postJob,
    page: () => const PostJobScreen(),
    transition: Transition.rightToLeft,
    transitionDuration: const Duration(milliseconds: 300),
  ),
  GetPage(
    name: AppRoutes.jobDetail,
    page: () => const JobDetailScreen(),
    transition: Transition.downToUp,
    transitionDuration: const Duration(milliseconds: 350),
  ),
];
