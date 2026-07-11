class ConversationModel {
  final String id;
  final String listingType; // "Room" | "Plot"
  final String listingId;
  final String listingTitle;
  final String? listingThumbnailUrl;
  final String otherPartyId;
  final String otherPartyName;
  final bool isOwner;
  final String status; // "Active" | "Blocked" | "ListingRemoved" | "ListingInactive"
  final DateTime lastMessageAt;
  final String? lastMessagePreview;
  final int unreadCount;

  ConversationModel({
    required this.id,
    required this.listingType,
    required this.listingId,
    required this.listingTitle,
    this.listingThumbnailUrl,
    required this.otherPartyId,
    required this.otherPartyName,
    required this.isOwner,
    required this.status,
    required this.lastMessageAt,
    this.lastMessagePreview,
    required this.unreadCount,
  });

  bool get isActive => status == 'Active';

  factory ConversationModel.fromJson(Map<String, dynamic> json) => ConversationModel(
        id: json['id'] as String,
        listingType: json['listingType'] as String,
        listingId: json['listingId'] as String,
        listingTitle: json['listingTitle'] as String? ?? '',
        listingThumbnailUrl: json['listingThumbnailUrl'] as String?,
        otherPartyId: json['otherPartyId'] as String,
        otherPartyName: json['otherPartyName'] as String? ?? 'User',
        isOwner: json['isOwner'] as bool? ?? false,
        status: json['status'] as String? ?? 'Active',
        lastMessageAt: DateTime.parse(json['lastMessageAt'] as String),
        lastMessagePreview: json['lastMessagePreview'] as String?,
        unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      );
}
