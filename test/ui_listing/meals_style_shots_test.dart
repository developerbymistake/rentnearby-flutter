import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/real_phone.dart';

MealsListData _m(String icon, String title, List<String> lines, int n, String unit, Color a, Color b) => MealsListData(
      imagePath: 'assets/images/design/travel3d/$icon.png',
      titleTxt: title,
      meals: lines,
      kacl: n,
      unit: unit,
      startColor: a,
      endColor: b,
    );

class _Scene extends StatefulWidget {
  const _Scene();
  @override
  State<_Scene> createState() => _SceneState();
}

class _SceneState extends State<_Scene> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1))..value = 1;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _grid(List<MealsListData> items) => Wrap(
        children: [for (final m in items) SizedBox(height: 216, child: MealsView(mealsListData: m, animationController: _c, animation: _c))],
      );

  @override
  Widget build(BuildContext context) {
    final taxis = [
      _m('taxi', 'Pradeep', ['Dzire', '4 seats', 'Haldwani'], 2400, 'to Nainital', TemplateTokens.mealBreakfastStart, TemplateTokens.mealBreakfastEnd),
      _m('taxi', 'Rakesh', ['Innova', '7 seats', 'Nainital'], 16, '/km', TemplateTokens.mealLunchStart, TemplateTokens.mealLunchEnd),
      _m('bus', 'Sunil', ['Traveller', '12 seats', 'Almora'], 22, '/km', TemplateTokens.mealSnackStart, TemplateTokens.mealSnackEnd),
      _m('taxi', 'Mohan', ['Sedan', '4 seats', 'Bhimtal'], 0, '', TemplateTokens.mealDinnerStart, TemplateTokens.mealDinnerEnd),
    ];
    final stays = [
      _m('hotel', 'Deodar Cottage', ['Kausani', '3 rooms', 'Breakfast'], 1500, '/night', TemplateTokens.mealLunchStart, TemplateTokens.mealLunchEnd),
      _m('bed', 'Pine Ridge', ['Mukteshwar', '6 rooms', 'Parking'], 2400, '/night', TemplateTokens.mealBreakfastStart, TemplateTokens.mealBreakfastEnd),
      _m('hotel', 'Lakeside', ['Nainital', '8 rooms', 'Lake view'], 3200, '/night', TemplateTokens.mealSnackStart, TemplateTokens.mealSnackEnd),
      _m('bed', 'Himalayan View', ['Bhimtal', '4 rooms', 'Garden'], 1800, '/night', TemplateTokens.mealDinnerStart, TemplateTokens.mealDinnerEnd),
    ];
    return Scaffold(
      backgroundColor: FitnessAppTheme.background,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 36, 16, 32),
        children: [
          Text('Taxis near you', style: TextStyle(fontFamily: FitnessAppTheme.fontName, fontWeight: FontWeight.w700, fontSize: 18, color: FitnessAppTheme.darkerText)),
          _grid(taxis),
          const SizedBox(height: 8),
          Text('Stays near you', style: TextStyle(fontFamily: FitnessAppTheme.fontName, fontWeight: FontWeight.w700, fontSize: 18, color: FitnessAppTheme.darkerText)),
          _grid(stays),
        ],
      ),
    );
  }
}

void main() {
  setUp(() => shotsDir = r'F:\Dhasu\UI_Template_resume\Mock_Listing\shots');
  testWidgets('meals style taxi and stay', (t) async {
    await pumpPhone(t, const _Scene(), size: const Size(360, 1100));
    await settlePhone(t);
    await shot(t, 'meals_style_taxi_stay');
    expect(t.takeException(), isNull);
  });
}
