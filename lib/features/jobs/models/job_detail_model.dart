import 'job_summary_model.dart';

class JobDetailModel extends JobSummaryModel {
  final String description;
  final String jobDepartmentId;
  final String jobRoleId;
  final String jobExperienceLevelId;
  final String? jobTypeId;
  final String? jobShiftTypeId;
  final String? jobSalaryTypeId;
  final String status;
  final String ownerUserId;
  final bool isOwner;

  JobDetailModel.fromJson(Map<String, dynamic> json)
      : description = json['description'] as String? ?? '',
        jobDepartmentId = json['jobDepartmentId'] as String? ?? '',
        jobRoleId = json['jobRoleId'] as String? ?? '',
        jobExperienceLevelId = json['jobExperienceLevelId'] as String? ?? '',
        jobTypeId = json['jobTypeId'] as String?,
        jobShiftTypeId = json['jobShiftTypeId'] as String?,
        jobSalaryTypeId = json['jobSalaryTypeId'] as String?,
        status = json['status'] as String? ?? 'Active',
        ownerUserId = json['ownerUserId'] as String? ?? '',
        isOwner = json['isOwner'] as bool? ?? false,
        super(
          id: json['id'] as String,
          stayListingId: json['stayListingId'] as String? ?? '',
          stayName: json['stayName'] as String? ?? 'Stay',
          stayTypeName: json['stayTypeName'] as String?,
          coverPhotoUrl: json['coverPhotoUrl'] as String?,
          title: json['title'] as String? ?? '',
          departmentName: json['departmentName'] as String? ?? '',
          roleName: json['roleName'] as String? ?? '',
          experienceLevelName: json['experienceLevelName'] as String? ?? '',
          jobTypeName: json['jobTypeName'] as String?,
          shiftTypeName: json['shiftTypeName'] as String?,
          salaryTypeName: json['salaryTypeName'] as String?,
          minimumExperienceYears: (json['minimumExperienceYears'] as num?)?.toInt(),
          minSalary: (json['minSalary'] as num?)?.toInt() ?? 0,
          maxSalary: (json['maxSalary'] as num?)?.toInt() ?? 0,
          districtId: json['districtId'] as String? ?? '',
          districtName: json['districtName'] as String?,
          cityName: json['cityName'] as String?,
          createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        );

  bool get isActive => status == 'Active';
}
