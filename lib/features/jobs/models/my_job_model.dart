import 'job_summary_model.dart';

class MyJobModel {
  final String id;
  final String title;
  final String departmentName;
  final String roleName;
  final int minimumExperienceYears;
  final String? salaryTypeName;
  final String? stayName;
  final int minSalary;
  final int maxSalary;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? closedAt;

  const MyJobModel({
    required this.id,
    required this.title,
    required this.departmentName,
    required this.roleName,
    required this.minimumExperienceYears,
    this.salaryTypeName,
    this.stayName,
    required this.minSalary,
    required this.maxSalary,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.closedAt,
  });

  factory MyJobModel.fromJson(Map<String, dynamic> json) => MyJobModel(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        departmentName: json['departmentName'] as String? ?? '',
        roleName: json['roleName'] as String? ?? '',
        minimumExperienceYears: (json['minimumExperienceYears'] as num?)?.toInt() ?? 0,
        salaryTypeName: json['salaryTypeName'] as String?,
        stayName: json['stayName'] as String?,
        minSalary: (json['minSalary'] as num?)?.toInt() ?? 0,
        maxSalary: (json['maxSalary'] as num?)?.toInt() ?? 0,
        status: json['status'] as String? ?? 'Active',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
        closedAt: DateTime.tryParse(json['closedAt'] as String? ?? ''),
      );

  bool get isActive => status == 'Active';

  String get salaryLabel => jobSalaryLabel(minSalary, maxSalary);

  String get salaryUnit => salaryTypeName == 'Monthly' ? '/month' : '';

  String get experienceLabel => jobExperienceLabel(minimumExperienceYears);

  String get metaLabel {
    final ago = jobPostedAgo(createdAt);
    final stay = stayName;
    return stay == null || stay.isEmpty ? ago : '$stay · $ago';
  }
}

class MyJobsPage {
  final List<MyJobModel> items;
  final int activeCount;
  final int maxActive;
  final String? stayStatus;
  final bool canPost;

  static String limitMessage(int max) => 'Your plan allows $max active jobs. Close one or upgrade.';

  bool get limitReached => !canPost && stayStatus == 'Approved';

  String? get blockMessage {
    if (canPost) return null;
    if (stayStatus != 'Approved') return 'Your stay must be live to post a job.';
    return limitMessage(maxActive);
  }

  const MyJobsPage({
    required this.items,
    required this.activeCount,
    required this.maxActive,
    this.stayStatus,
    required this.canPost,
  });

  factory MyJobsPage.fromJson(Map<String, dynamic> json) => MyJobsPage(
        items: (json['items'] as List? ?? const [])
            .map((e) => MyJobModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        activeCount: (json['activeCount'] as num?)?.toInt() ?? 0,
        maxActive: (json['maxActive'] as num?)?.toInt() ?? 0,
        stayStatus: json['stayStatus'] as String?,
        canPost: json['canPost'] as bool? ?? false,
      );
}
