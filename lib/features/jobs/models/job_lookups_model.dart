class JobLookupItem {
  final String id;
  final String name;
  final int sortOrder;
  final bool isActive;
  final String? jobDepartmentId;

  const JobLookupItem({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.isActive,
    this.jobDepartmentId,
  });

  factory JobLookupItem.fromJson(Map<String, dynamic> json) => JobLookupItem(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
        isActive: json['isActive'] as bool? ?? true,
        jobDepartmentId: json['jobDepartmentId'] as String?,
      );
}

class JobLookups {
  final List<JobLookupItem> departments;
  final List<JobLookupItem> roles;
  final List<JobLookupItem> jobTypes;
  final List<JobLookupItem> shiftTypes;
  final List<JobLookupItem> salaryTypes;

  const JobLookups({
    required this.departments,
    required this.roles,
    required this.jobTypes,
    required this.shiftTypes,
    required this.salaryTypes,
  });

  static List<JobLookupItem> _list(dynamic v) =>
      (v as List? ?? const []).map((e) => JobLookupItem.fromJson(e as Map<String, dynamic>)).toList();

  factory JobLookups.fromJson(Map<String, dynamic> json) => JobLookups(
        departments: _list(json['departments']),
        roles: _list(json['roles']),
        jobTypes: _list(json['jobTypes']),
        shiftTypes: _list(json['shiftTypes']),
        salaryTypes: _list(json['salaryTypes']),
      );

  List<JobLookupItem> rolesFor(String? deptId) =>
      deptId == null ? const [] : roles.where((r) => r.jobDepartmentId == deptId).toList();

  static String? nameOf(List<JobLookupItem> list, String? id) {
    if (id == null) return null;
    for (final e in list) {
      if (e.id == id) return e.name;
    }
    return null;
  }
}
