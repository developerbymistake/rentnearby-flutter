import 'package:flutter/material.dart';

class BookingExpenseLine extends StatelessWidget {
  const BookingExpenseLine({super.key, required this.tripId, required this.kind, required this.id});

  final String tripId;
  final String kind;
  final String id;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
