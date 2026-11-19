import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import '../../../../utils/contact_message.dart';
import '../../../../widgets/listing_contact_actions.dart';

const stayCallKey = ValueKey('stay-card-call');
const stayWhatsAppKey = ValueKey('stay-card-whatsapp');

List<WideAction> stayContactActions(BuildContext context, String stayId) => [
      WideAction(
        itemKey: stayCallKey,
        icon: Icons.call_rounded,
        label: ContactMessage.call,
        busy: ListingContactActions.isBusy(ListingKind.stay, stayId, action: ListingContactActions.actionCall),
        onTap: () => ListingContactActions.call(context, kind: ListingKind.stay, id: stayId),
      ),
      WideAction(
        itemKey: stayWhatsAppKey,
        icon: Icons.chat_rounded,
        label: ContactMessage.whatsApp,
        busy: ListingContactActions.isBusy(ListingKind.stay, stayId, action: ListingContactActions.actionWhatsApp),
        onTap: () => ListingContactActions.whatsApp(context, kind: ListingKind.stay, id: stayId),
      ),
    ];
