import '../../nearby/data/nearby_repository_base.dart';
import '../../nearby/models/nearby_models.dart';
import '../models/job_summary_model.dart';

class JobFeedItem {
  final JobSummaryModel job;
  final NearbyDistance? distance;

  const JobFeedItem(this.job, this.distance);

  String get id => job.id;

  factory JobFeedItem.fromJson(Map<String, dynamic> json) =>
      JobFeedItem(JobSummaryModel.fromJson(json), NearbyDistance.fromJson(json));
}

class JobsFeedRepository extends NearbyRepositoryBase<JobFeedItem> {
  const JobsFeedRepository();

  Future<NearbyPage<JobFeedItem>> getFeed({
    int? cityKey,
    double? lat,
    double? lng,
    String? departmentId,
    int? minExperience,
    int? maxExperience,
    int? minSalary,
    String? pageToken,
    int pageSize = 20,
  }) {
    return getPage(
      '/stay-jobs/feed',
      {
        if (cityKey != null) 'cityKey': cityKey else ...{'lat': ?lat, 'lng': ?lng},
        'departmentId': ?departmentId,
        'minExperience': ?minExperience,
        'maxExperience': ?maxExperience,
        'minSalary': ?minSalary,
        'pageToken': ?pageToken,
        'pageSize': pageSize,
      },
      JobFeedItem.fromJson,
    );
  }
}
