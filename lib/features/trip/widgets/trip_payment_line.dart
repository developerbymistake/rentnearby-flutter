import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_trip_replies.dart';
import '../trip_strings.dart';

class TripPaymentLine extends StatelessWidget {
  const TripPaymentLine({super.key, this.text = TripStrings.stayPayLine});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Image.asset(ListingArt.moneyBag, width: DS.s(22), height: DS.s(22), fit: BoxFit.contain),
        Gap.h(8),
        Expanded(child: Text(text, maxLines: 3, overflow: TextOverflow.ellipsis, style: RepliesLook.foot)),
      ],
    );
  }
}
