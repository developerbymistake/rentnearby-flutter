import 'package:flutter/widgets.dart';

import '../home/owner_home_models.dart';

class HomePlanCard extends StatelessWidget {
  const HomePlanCard({super.key, required this.card, required this.taxi});

  final OwnerPlanCard? card;
  final bool taxi;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
