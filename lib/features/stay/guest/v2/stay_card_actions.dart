import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import '../../../../widgets/listing_contact_actions.dart';

List<WideAction> stayContactActions(BuildContext context, String stayId) {
  final busy = ListingContactActions.isBusy(ListingKind.stay, stayId);
  return [
    WideAction(
      icon: Icons.phone_rounded,
      label: 'Call',
      busy: busy,
      onTap: () => ListingContactActions.call(context, kind: ListingKind.stay, id: stayId),
    ),
    WideAction(
      icon: Icons.mail_rounded,
      label: 'Enquiry',
      busy: busy,
      onTap: () => ListingContactActions.chat(context, kind: ListingKind.stay, id: stayId),
    ),
  ];
}
