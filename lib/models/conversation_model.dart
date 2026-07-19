class ConversationModel {
  final String id;
  final String listingType; // "Room" | "Plot"
  final String listingId;
  final String? roomTypeId; // set when listingType == "Room"
  final String? plotTypeId; // set when listingType == "Plot"
  final String listingTitle;
  // Concise locality label (city, falling back to district) — same precedence
  // listing_detail_screen.dart's _locationStr() already uses for room/plot detail pages.
  final String? area;
  final String? listingThumbnailUrl;
  final String otherPartyId;
  final String otherPartyName;
  final bool isOwner;
  final String status; // "Active" | "Blocked" | "ListingRemoved" | "ListingInactive"
  // Only meaningful when status == 'Blocked' — true if the CURRENT user did the blocking,
  // false if they're the one who got blocked. Backend-derived from UserBlocks(BlockerId,
  // BlockedId); never infer this from isOwner/status alone — either party can block the
  // other regardless of listing ownership.
  final bool isBlockedByMe;
  final DateTime lastMessageAt;
  final String? lastMessagePreview;
  final int unreadCount;

  ConversationModel({
    required this.id,
    required this.listingType,
    required this.listingId,
    this.roomTypeId,
    this.plotTypeId,
    required this.listingTitle,
    this.area,
    this.listingThumbnailUrl,
    required this.otherPartyId,
    required this.otherPartyName,
    required this.isOwner,
    required this.status,
    this.isBlockedByMe = false,
    required this.lastMessageAt,
    this.lastMessagePreview,
    required this.unreadCount,
  });

  bool get isActive => status == 'Active';

  factory ConversationModel.fromJson(Map<String, dynamic> json) => ConversationModel(
        id: json['id'] as String,
        listingType: json['listingType'] as String,
        listingId: json['listingId'] as String,
        roomTypeId: json['roomTypeId'] as String?,
        plotTypeId: json['plotTypeId'] as String?,
        listingTitle: json['listingTitle'] as String? ?? '',
        area: json['area'] as String?,
        listingThumbnailUrl: json['listingThumbnailUrl'] as String?,
        otherPartyId: json['otherPartyId'] as String,
        otherPartyName: json['otherPartyName'] as String? ?? 'User',
        isOwner: json['isOwner'] as bool? ?? false,
        status: json['status'] as String? ?? 'Active',
        isBlockedByMe: json['isBlockedByMe'] as bool? ?? false,
        lastMessageAt: DateTime.parse(json['lastMessageAt'] as String),
        lastMessagePreview: json['lastMessagePreview'] as String?,
        unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      );
}
