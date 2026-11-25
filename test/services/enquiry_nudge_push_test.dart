import 'dart:convert';

import 'package:bakhli/services/enquiry_nudge_push.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _data({String route = '/stay-enquiries', Object? actions = const ['reply', 'notAvailable'], String id = 'e1'}) => {
      'notification_type': 'stay_enquiry_nudge',
      'action_route': route,
      'action_args_json': jsonEncode({'enquiryId': id, 'actions': actions}),
    };

void main() {
  test('tryParse accepts a nudge and rejects bad ones', () {
    expect(EnquiryNudgePush.tryParse(_data(), title: 'Waiting 2 h', body: 'b')?.enquiryId, 'e1');
    expect(EnquiryNudgePush.tryParse(_data(route: '/x'), title: 't'), isNull);
    expect(EnquiryNudgePush.tryParse(_data(actions: ['reply']), title: 't'), isNull);
    expect(EnquiryNudgePush.tryParse(_data(id: ''), title: 't'), isNull);
    expect(EnquiryNudgePush.tryParse(_data(), title: ''), isNull);
    expect(EnquiryNudgePush.tryParse(_data()), isNull);
  });

  test('idFor is stable per enquiry', () {
    expect(EnquiryNudgePush.idFor('abc'), EnquiryNudgePush.idFor('abc'));
    expect(EnquiryNudgePush.idFor('abc'), isNot(EnquiryNudgePush.idFor('abd')));
  });

  test('payload round trip and tapData', () {
    final push = EnquiryNudgePush.tryParse(_data(), title: 't', body: 'b')!;
    final decoded = jsonDecode(EnquiryNudgePush.payload(push)) as Map<String, dynamic>;
    expect(EnquiryNudgePush.isPayload(decoded), isTrue);
    expect(EnquiryNudgePush.isPayload(_data()), isFalse);

    Map<String, dynamic> args(String? a) =>
        jsonDecode(EnquiryNudgePush.tapData(decoded, a)['action_args_json'] as String) as Map<String, dynamic>;
    expect(args(null), {'enquiryId': 'e1', 'bucket': 'New'});
    expect(args(EnquiryNudgePush.replyAction), {'enquiryId': 'e1', 'bucket': 'New'});
    expect(args(EnquiryNudgePush.notAvailableAction), {'enquiryId': 'e1', 'bucket': 'New', 'action': 'notAvailable'});
    expect(EnquiryNudgePush.tapData(decoded, null)['action_route'], '/stay-enquiries');
  });
}
