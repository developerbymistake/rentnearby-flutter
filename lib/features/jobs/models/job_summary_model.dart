import '../../../config/app_constants.dart';
import '../../../models/browse_item.dart';

String? jobPhotoUrl(Object? raw) {
  final u = raw as String?;
  if (u == null || u.isEmpty) return null;
  return u.startsWith('http') ? u : '${AppConstants.serverUrl}$u';
}

String jobSalaryLabel(int min, int max) =>
    min == max ? BrowseItem.inr(min) : '${BrowseItem.inr(min)} - ${BrowseItem.inr(max).substring(1)}';

String _thousands(int v) {
  final k = v / 1000;
  return k == k.roundToDouble() ? '${k.round()}k' : '${k.toStringAsFixed(1)}k';
}

String jobSalaryCompact(int min, int max) {
  if (min <= 0 && max <= 0) return 'Negotiable';
  if (min == max || min <= 0 || max <= 0) {
    final v = max > 0 ? max : min;
    return v >= 1000 ? '₹${_thousands(v)}' : BrowseItem.inr(v);
  }
  if (min >= 1000 && max >= 1000) {
    final a = _thousands(min);
    return '₹${a.substring(0, a.length - 1)}-${_thousands(max)}';
  }
  final a = min >= 1000 ? _thousands(min) : '$min';
  final b = max >= 1000 ? _thousands(max) : '$max';
  return '₹$a - $b';
}

String jobExperienceLabel(int years) => years == 0 ? 'Fresher' : '$years+ yrs';

String jobPostedAgoLong(DateTime dt) {
  final diff = DateTime.now().difference(dt.toLocal());
  String unit(int n, String word) => '$n $word${n == 1 ? '' : 's'} ago';
  if (diff.inMinutes < 1) return 'Posted just now';
  if (diff.inMinutes < 60) return 'Posted ${unit(diff.inMinutes, 'minute')}';
  if (diff.inHours < 24) return 'Posted ${unit(diff.inHours, 'hour')}';
  if (diff.inDays < 7) return 'Posted ${unit(diff.inDays, 'day')}';
  if (diff.inDays < 30) return 'Posted ${unit((diff.inDays / 7).floor(), 'week')}';
  if (diff.inDays < 365) return 'Posted ${unit((diff.inDays / 30).floor(), 'month')}';
  return 'Posted ${unit((diff.inDays / 365).floor(), 'year')}';
}

String jobPostedAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt.toLocal());
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
  return '${(diff.inDays / 365).floor()}y ago';
}

class JobSummaryModel {
  final String id;
  final String stayListingId;
  final String stayName;
  final String? stayTypeName;
  final String? coverPhotoUrl;
  final String title;
  final String departmentName;
  final String roleName;
  final String jobTypeName;
  final String shiftTypeName;
  final String salaryTypeName;
  final int minimumExperienceYears;
  final int minSalary;
  final int maxSalary;
  final String districtId;
  final String? districtName;
  final String? cityName;
  final DateTime createdAt;

  const JobSummaryModel({
    required this.id,
    required this.stayListingId,
    required this.stayName,
    this.stayTypeName,
    this.coverPhotoUrl,
    required this.title,
    required this.departmentName,
    required this.roleName,
    required this.jobTypeName,
    required this.shiftTypeName,
    required this.salaryTypeName,
    required this.minimumExperienceYears,
    required this.minSalary,
    required this.maxSalary,
    required this.districtId,
    this.districtName,
    this.cityName,
    required this.createdAt,
  });

  factory JobSummaryModel.fromJson(Map<String, dynamic> json) => JobSummaryModel(
        id: json['id'] as String,
        stayListingId: json['stayListingId'] as String? ?? '',
        stayName: json['stayName'] as String? ?? 'Stay',
        stayTypeName: json['stayTypeName'] as String?,
        coverPhotoUrl: jobPhotoUrl(json['coverPhotoUrl']),
        title: json['title'] as String? ?? '',
        departmentName: json['departmentName'] as String? ?? '',
        roleName: json['roleName'] as String? ?? '',
        jobTypeName: json['jobTypeName'] as String? ?? '',
        shiftTypeName: json['shiftTypeName'] as String? ?? '',
        salaryTypeName: json['salaryTypeName'] as String? ?? '',
        minimumExperienceYears: (json['minimumExperienceYears'] as num?)?.toInt() ?? 0,
        minSalary: (json['minSalary'] as num?)?.toInt() ?? 0,
        maxSalary: (json['maxSalary'] as num?)?.toInt() ?? 0,
        districtId: json['districtId'] as String? ?? '',
        districtName: json['districtName'] as String?,
        cityName: json['cityName'] as String?,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      );

  String get salaryLabel => jobSalaryLabel(minSalary, maxSalary);

  String get salaryCompact => jobSalaryCompact(minSalary, maxSalary);

  String get salaryUnit => salaryTypeName == 'Monthly' ? '/month' : '';

  String get experienceLabel => jobExperienceLabel(minimumExperienceYears);

  bool get isFresher => minimumExperienceYears == 0;

  String get postedAgo => jobPostedAgo(createdAt);

  String get postedAgoLong => jobPostedAgoLong(createdAt);

  String get placeLabel => {cityName, districtName}.whereType<String>().where((e) => e.isNotEmpty).join(', ');

  String get localityLabel => (cityName?.isNotEmpty == true ? cityName : districtName) ?? '';

  String get locationLabel => localityLabel.isEmpty ? stayName : '$stayName · $localityLabel';
}
