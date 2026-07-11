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
  final String listingType; // "Room" | "Plot" | "Both"
  final String questionText;
  final List<AnswerOption> answerOptions;
  final int sortOrder;
  final bool isActive;

  QuestionTemplateModel({
    required this.id,
    required this.key,
    required this.listingType,
    required this.questionText,
    required this.answerOptions,
    required this.sortOrder,
    required this.isActive,
  });

  bool appliesTo(String targetListingType) => listingType == 'Both' || listingType == targetListingType;

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
      questionText: json['questionText'] as String? ?? '',
      answerOptions: options,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 999,
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}
