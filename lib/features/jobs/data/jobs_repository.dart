import '../../../services/api_service.dart';
import '../models/job_detail_model.dart';
import '../models/job_lookups_model.dart';
import '../models/job_summary_model.dart';
import '../models/my_job_model.dart';

class JobsRepository {
  const JobsRepository();

  Map<String, dynamic> _data(Map<String, dynamic> res) {
    final data = res['data'];
    return data is Map<String, dynamic> ? data : const {};
  }

  Future<JobLookups> getLookups() async =>
      JobLookups.fromJson(_data(await ApiService.get('/stay-jobs/lookups')));

  Future<({List<JobSummaryModel> items, bool hasMore})> browse({
    required String districtId,
    String? departmentId,
    String? experienceLevelId,
    int? minSalary,
    int page = 1,
    int pageSize = 20,
  }) async {
    final data = _data(await ApiService.get('/stay-jobs', params: {
      'districtId': districtId,
      if (departmentId != null) 'departmentId': departmentId,
      if (experienceLevelId != null) 'experienceLevelId': experienceLevelId,
      if (minSalary != null) 'minSalary': minSalary,
      'page': page,
      'pageSize': pageSize,
    }));
    final list = (data['items'] as List?) ?? const [];
    return (
      items: list.map((e) => JobSummaryModel.fromJson(e as Map<String, dynamic>)).toList(),
      hasMore: data['hasMore'] == true,
    );
  }

  Future<JobDetailModel> getById(String id) async =>
      JobDetailModel.fromJson(_data(await ApiService.get('/stay-jobs/$id')));

  Future<MyJobsPage> getMine() async => MyJobsPage.fromJson(_data(await ApiService.get('/stay-jobs/me')));

  Future<void> create(Map<String, dynamic> body) => ApiService.post('/stay-jobs/me', body);

  Future<void> close(String id) => ApiService.put('/stay-jobs/me/$id/close', {});
}
