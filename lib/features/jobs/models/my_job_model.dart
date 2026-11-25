import '../../owner_core/json/owner_json.dart';
import '../../stay_owner/strings/stay_gate_strings_work.dart';
import '../../stay_owner/strings/stay_work_strings.dart';
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
  final bool foodAndStay;

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
    this.foodAndStay = false,
  });

  factory MyJobModel.fromJson(Map<String, dynamic> json) => MyJobModel(
        id: OwnerJson.str(json['id']),
        title: OwnerJson.str(json['title']),
        departmentName: OwnerJson.str(json['departmentName']),
        roleName: OwnerJson.str(json['roleName']),
        minimumExperienceYears: OwnerJson.integer(json['minimumExperienceYears']),
        salaryTypeName: OwnerJson.strOrNull(json['salaryTypeName']),
        stayName: OwnerJson.strOrNull(json['stayName']),
        minSalary: OwnerJson.integer(json['minSalary']),
        maxSalary: OwnerJson.integer(json['maxSalary']),
        status: OwnerJson.str(json['status'], 'Active'),
        createdAt: OwnerJson.time(json['createdAt']) ?? DateTime.now(),
        updatedAt: OwnerJson.time(json['updatedAt']),
        closedAt: OwnerJson.time(json['closedAt']),
        foodAndStay: OwnerJson.boolean(json['foodAndStay']),
      );

  bool get isActive => status == 'Active';

  bool get isInactive => status == 'Inactive';

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
  final bool paymentEnabled;
  final bool canUpgrade;
  final bool overCap;

  static String limitMessage(int max, {bool canUpgrade = true}) =>
      canUpgrade ? StayGateStringsWork.jobsCap(max) : StayWorkStrings.jobsPlusCap(max);

  bool get limitReached => !canPost && stayStatus == 'Approved';

  bool get atCap => stayStatus == 'Approved' && activeCount >= maxActive;

  String? get blockMessage {
    if (canPost) return null;
    if (stayStatus != 'Approved') return StayWorkStrings.stayNotLive;
    return limitMessage(maxActive, canUpgrade: canUpgrade);
  }

  const MyJobsPage({
    required this.items,
    required this.activeCount,
    required this.maxActive,
    this.stayStatus,
    required this.canPost,
    this.paymentEnabled = false,
    this.canUpgrade = false,
    this.overCap = false,
  });

  factory MyJobsPage.fromJson(Map<String, dynamic> json) {
    final active = OwnerJson.integer(json['activeCount']);
    final max = OwnerJson.integer(json['maxActive'], 1);
    final payment = OwnerJson.boolean(json['paymentEnabled']);
    return MyJobsPage(
      items: OwnerJson.list(json['items'], MyJobModel.fromJson).where((j) => j.id.isNotEmpty).toList(),
      activeCount: active,
      maxActive: max,
      stayStatus: OwnerJson.strOrNull(json['stayStatus']),
      canPost: OwnerJson.boolean(json['canPost']),
      paymentEnabled: payment,
      canUpgrade: OwnerJson.boolOrNull(json['canUpgrade']) ?? payment,
      overCap: OwnerJson.boolOrNull(json['overCap']) ?? active > max,
    );
  }
}
