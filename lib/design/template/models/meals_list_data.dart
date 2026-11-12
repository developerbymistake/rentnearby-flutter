import 'package:bakhli/design/tokens/template_tokens.dart';
import 'package:flutter/material.dart';

class MealsListData {
  MealsListData({
    this.imagePath = '',
    this.titleTxt = '',
    this.startColor = Colors.transparent,
    this.endColor = Colors.transparent,
    this.meals,
    this.kacl = 0,
  });

  String imagePath;
  String titleTxt;
  Color startColor;
  Color endColor;
  List<String>? meals;
  int kacl;

  static List<MealsListData> tabIconsList = <MealsListData>[
    MealsListData(
      imagePath: 'assets/images/design/fitness_app/breakfast.png',
      titleTxt: 'Breakfast',
      kacl: 525,
      meals: <String>['Bread,', 'Peanut butter,', 'Apple'],
      startColor: TemplateTokens.mealBreakfastStart,
      endColor: TemplateTokens.mealBreakfastEnd,
    ),
    MealsListData(
      imagePath: 'assets/images/design/fitness_app/lunch.png',
      titleTxt: 'Lunch',
      kacl: 602,
      meals: <String>['Salmon,', 'Mixed veggies,', 'Avocado'],
      startColor: TemplateTokens.mealLunchStart,
      endColor: TemplateTokens.mealLunchEnd,
    ),
    MealsListData(
      imagePath: 'assets/images/design/fitness_app/snack.png',
      titleTxt: 'Snack',
      kacl: 0,
      meals: <String>['Recommend:', '800 kcal'],
      startColor: TemplateTokens.mealSnackStart,
      endColor: TemplateTokens.mealSnackEnd,
    ),
    MealsListData(
      imagePath: 'assets/images/design/fitness_app/dinner.png',
      titleTxt: 'Dinner',
      kacl: 0,
      meals: <String>['Recommend:', '703 kcal'],
      startColor: TemplateTokens.mealDinnerStart,
      endColor: TemplateTokens.mealDinnerEnd,
    ),
  ];
}
