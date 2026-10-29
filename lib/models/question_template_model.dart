import 'dart:convert';

class AnswerOption {
  final String key;
  final String text;
  final String sentiment; // "positive" | "negative" | "neutral"

  AnswerOption({required this.key, required this.text, this.sentiment = 'neutral'});

  factory AnswerOption.fromJson(Map<String, dynamic> json) => AnswerOption(
        key: json['key'] as String,
        text: json['text'] as String,
        sentiment: json['sentiment'] as String? ?? 'neutral',
      );
}

class QuestionTemplateModel {
  final String id;
  final String key;
  final String listingType; // "Room" | "Plot" | "Stay" | "Both" (Both = Room and Plot)
  final String? roomTypeId; // further scoping within "Room" — null means all room types
  final String? plotTypeId; // further scoping within "Plot" — null means all plot types
  final String? stayTypeId;
  final String questionText;
  final List<AnswerOption> answerOptions;
  final int sortOrder;
  final bool isActive;

  QuestionTemplateModel({
    required this.id,
    required this.key,
    required this.listingType,
    this.roomTypeId,
    this.plotTypeId,
    this.stayTypeId,
    required this.questionText,
    required this.answerOptions,
    required this.sortOrder,
    required this.isActive,
  });

  bool appliesTo(String targetListingType,
      {String? targetRoomTypeId, String? targetPlotTypeId, String? targetStayTypeId}) {
    if (listingType == 'Both') return targetListingType == 'Room' || targetListingType == 'Plot';
    if (listingType != targetListingType) return false;
    if (listingType == 'Room' && roomTypeId != null) return roomTypeId == targetRoomTypeId;
    if (listingType == 'Plot' && plotTypeId != null) return plotTypeId == targetPlotTypeId;
    if (listingType == 'Stay' && stayTypeId != null) return stayTypeId == targetStayTypeId;
    return true;
  }

  factory QuestionTemplateModel.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['answerOptionsJson'] as String? ?? '[]';
    List<AnswerOption> options = [];
    try {
      options = (jsonDecode(rawOptions) as List)
          .map((e) => AnswerOption.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {}

    return QuestionTemplateModel(
      id: json['id'] as String,
      key: json['key'] as String,
      listingType: json['listingType'] as String? ?? 'Both',
      roomTypeId: json['roomTypeId'] as String?,
      plotTypeId: json['plotTypeId'] as String?,
      stayTypeId: json['stayTypeId'] as String?,
      questionText: json['questionText'] as String? ?? '',
      answerOptions: options,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 999,
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}
