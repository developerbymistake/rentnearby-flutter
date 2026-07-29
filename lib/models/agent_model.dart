/// Identity-only view of the Agent assigned to an Enquiry — GET /enquiries/{id}'s AssignedAgent.
/// Deliberately has no phone/WhatsApp fields: contact is one-directional (the agent reaches out to
/// the customer, never the other way around), so Enquiry Detail only ever needs to show who the
/// agent is, not how to reach them. Mirrors RentNearBy.Core.DTOs.Responses.AssignedAgentDto.
class AgentModel {
  final String id;
  final String name;
  final String photoUrl;
  // Years of experience, admin-entered — shown to build trust; null if not set.
  final int? experience;
  final String? companyName;

  AgentModel({
    required this.id,
    required this.name,
    required this.photoUrl,
    this.experience,
    this.companyName,
  });

  factory AgentModel.fromJson(Map<String, dynamic> json) => AgentModel(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        photoUrl: json['photoUrl'] as String? ?? '',
        experience: (json['experience'] as num?)?.toInt(),
        companyName: json['companyName'] as String?,
      );
}
