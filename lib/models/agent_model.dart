/// A field agent an Inquiry can be assigned to — GET /agents. Phone and
/// WhatsAppNumber are deliberately separate fields (confirmed design) so
/// Inquiry Detail can render two distinct Call/WhatsApp buttons. Not
/// consumed by the catalog-browsing screens yet — wired in once the Inquiry
/// flow (next step) needs it for the Agent card.
class AgentModel {
  final String id;
  final String name;
  final String phone;
  final String whatsAppNumber;
  final String photoUrl;
  final bool isActive;
  final List<String> serviceCategoryIds;
  final List<String> serviceCategoryNames;

  AgentModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.whatsAppNumber,
    required this.photoUrl,
    required this.isActive,
    required this.serviceCategoryIds,
    required this.serviceCategoryNames,
  });

  factory AgentModel.fromJson(Map<String, dynamic> json) => AgentModel(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        whatsAppNumber: json['whatsAppNumber'] as String? ?? '',
        photoUrl: json['photoUrl'] as String? ?? '',
        isActive: json['isActive'] == true,
        serviceCategoryIds: (json['serviceCategoryIds'] as List? ?? []).map((e) => e as String).toList(),
        serviceCategoryNames: (json['serviceCategoryNames'] as List? ?? []).map((e) => e as String).toList(),
      );
}
