import 'package:bakhli/design/extra/art_3d.dart';
import 'package:bakhli/design/extra/k1_forms.dart';
import 'package:bakhli/design/tokens/listing_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/real_phone.dart';

Widget _page(ListingPalette p, List<Widget> body, {Widget? bottom}) => Scaffold(
      backgroundColor: p.page,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [...body, const SizedBox(height: 24)])),
      ),
      bottomNavigationBar: bottom,
    );

Widget _stayDetails({bool errors = false, bool long = false}) {
  final t = ListingTone.forest;
  const types = [
    OptionTileItem(label: 'Homestay', art: ListingArt.bed),
    OptionTileItem(label: 'Hotel', art: ListingArt.hotel),
    OptionTileItem(label: 'Resort', art: ListingArt.beach),
    OptionTileItem(label: 'Camp', art: ListingArt.tent),
    OptionTileItem(label: 'Cottage', art: ListingArt.mountain),
    OptionTileItem(label: 'Hostel', art: ListingArt.backpack),
  ];
  return _page(
    ListingPalette.forest,
    [
      PageHeader3D(tone: t, title: long ? 'Basic Details of your stay' : 'Basic Details', art: ListingArt.hotel, onBack: () {}),
      StepProgressHeader(tone: t, labels: const ['Details', 'Location', 'Address', 'Photos'], current: 0),
      FormSectionCard(
        tone: t,
        art: ListingArt.hotel,
        title: 'Stay Name',
        tag: 'Required',
        child: PillField(
          tone: t,
          controller: TextEditingController(text: errors ? '' : 'Deodar Cottage'),
          hint: 'e.g. Himalayan Home',
          maxLength: 80,
          errorText: errors ? 'Please enter your stay name' : null,
        ),
      ),
      FormSectionCard(
        tone: t,
        art: ListingArt.bed,
        title: 'Stay Type',
        tag: 'Required',
        child: errors
            ? PillStatusBox.retry(tone: t, text: "Couldn't load stay types. Tap to retry.", onTap: () {})
            : OptionTileGrid(tone: t, items: types, isSelected: (i) => i == 0, onTap: (_) {}),
      ),
      FormSectionCard(
        tone: t,
        art: ListingArt.clipboard,
        title: 'Registration',
        tag: 'Required',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            errors ? PillStatusBox.loading(tone: t) : PillPickerField(tone: t, label: 'Registration type', hint: 'Select type', leadingArt: ListingArt.clipboard, onTap: () {}),
            PillField(tone: t, label: 'Registration number', firstLabel: false, hint: 'UDYAM-XX-00-0000000', suffixText: 'Saved', helperText: 'Only Bakhli admin sees this'),
          ],
        ),
      ),
      FormSectionCard(
        tone: t,
        art: ListingArt.moneyBag,
        title: 'GSTIN',
        tag: 'Optional',
        tagMuted: true,
        child: OptionTileGrid(tone: t, items: types.sublist(0, 3), isSelected: (_) => false, onTap: (_) {}, errorText: 'Please select a stay type'),
      ),
    ],
    bottom: FormFooter(tone: t, primaryLabel: 'Next: Location', onPrimary: () {}),
  );
}

Widget _stayRooms() {
  final t = ListingTone.forest;
  return _page(
    ListingPalette.forest,
    [
      PageHeader3D(tone: t, title: 'Rooms', subtitle: 'Add rooms, up to 2', art: ListingArt.bed, onBack: () {}),
      FormSectionCard(
        tone: t,
        art: ListingArt.bed,
        title: 'Room 2',
        tag: 'Required',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PillPickerField(tone: t, label: 'Room Type', value: 'Family Room', leadingArt: ListingArt.bed, onTap: () {}),
            PillField(tone: t, label: 'Price per Night (₹)', firstLabel: false, prefixText: '₹', controller: TextEditingController(text: '2,400')),
            const FieldLabel('Max Guests'),
            OptionTileGrid(
              tone: t,
              columns: 4,
              items: const [
                OptionTileItem(label: 'guests', art: ListingArt.backpack, big: '1'),
                OptionTileItem(label: 'guests', art: ListingArt.backpack, big: '2'),
                OptionTileItem(label: 'guests', art: ListingArt.backpack, big: '3'),
                OptionTileItem(label: 'guests', art: ListingArt.backpack, big: '4+'),
              ],
              isSelected: (i) => i == 3,
              onTap: (_) {},
            ),
            const FieldLabel('Meals'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoicePill(tone: t, label: 'Breakfast', selected: true, check: true, onTap: () {}),
                ChoicePill(tone: t, label: 'Lunch', selected: false, onTap: () {}),
                ChoicePill(tone: t, label: 'Dinner', selected: false, onTap: () {}),
              ],
            ),
          ],
        ),
      ),
      DashedAddRow3D(tone: t, label: 'Add another room', trailing: '1 of 2', onTap: () {}),
      DashedAddRow3D(tone: t, label: 'Add another room', trailing: '2 of 2', onTap: () {}, enabled: false),
    ],
    bottom: FormFooter(tone: t, primaryLabel: 'Save', onPrimary: () {}, primaryLoading: true),
  );
}

Widget _stayRules() {
  final t = ListingTone.forest;
  return _page(
    ListingPalette.forest,
    [
      PageHeader3D(tone: t, title: 'Rules', art: ListingArt.clipboard, onBack: () {}),
      FormSectionCard(
        tone: t,
        art: ListingArt.key,
        title: 'Check-in and Check-out',
        tag: 'Required',
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: PillPickerField(tone: t, label: 'Check-in', value: '12:00 PM', leadingArt: ListingArt.key, trailing: const SizedBox.shrink(), onTap: () {})),
            const SizedBox(width: 12),
            Expanded(child: PillPickerField(tone: t, label: 'Check-out', value: '11:00 AM', leadingArt: ListingArt.key, trailing: const SizedBox.shrink(), onTap: () {})),
          ],
        ),
      ),
      FormSectionCard(
        tone: t,
        art: ListingArt.clipboard,
        title: 'House Rules',
        tag: 'Required',
        child: Column(
          children: [
            ToggleRow(tone: t, art: ListingArt.backpack, label: 'Pets allowed', value: false, onChanged: (_) {}, divider: true),
            ToggleRow(tone: t, art: ListingArt.camping, label: 'Smoking allowed', value: false, onChanged: (_) {}, divider: true),
            ToggleRow(tone: t, art: ListingArt.star, label: 'Alcohol allowed', value: true, onChanged: (_) {}, divider: true),
            ToggleRow(tone: t, art: ListingArt.key, label: 'Unmarried couples allowed', value: true, onChanged: (_) {}, divider: true),
            ToggleRow(tone: t, label: 'GST invoice', value: true, onChanged: (_) {}, filled: true),
            ToggleRow(tone: t, label: 'Locked row', sublabel: 'Set by admin', value: true, onChanged: null, divider: true),
          ],
        ),
      ),
      FormSectionCard(
        tone: t,
        art: ListingArt.speechBalloon,
        title: 'Other rules',
        tag: 'Optional',
        tagMuted: true,
        child: PillField(tone: t, hint: 'Anything guests should know', maxLines: 4, maxLength: 500),
      ),
    ],
    bottom: FormFooter(tone: t, primaryLabel: 'Save', onPrimary: () {}, note: 'You can change rules later.'),
  );
}

Widget _stayHub() {
  final t = ListingTone.forest;
  return _page(ListingPalette.forest, [
    PageHeader3D(tone: t, title: 'Set up your stay', art: ListingArt.hotel, leadingIcon: Icons.more_vert_rounded, onLeading: () {}, leadingSemantics: 'Menu'),
    FormNoteCard(tone: t, art: ListingArt.clipboard, title: 'Licence details needed', titleColor: Form3D.amber, onTap: () {}),
    StepCard3D(tone: t, art: ListingArt.hotel, eyebrow: 'Step 1', title: 'Basic details', subtitle: 'Deodar Cottage · 4 photos', trailingLabel: 'Edit', state: StepCardState.done, onTap: () {}),
    StepCard3D(tone: t, art: ListingArt.bed, eyebrow: 'Step 2', title: 'Rooms', subtitle: '2 rooms · from ₹1,500 / night', trailingLabel: 'Edit', state: StepCardState.done, onTap: () {}),
    StepCard3D(tone: t, art: ListingArt.clipboard, eyebrow: 'Step 3', title: 'Rules', subtitle: 'Check-in, house rules, cancellation policy and more', trailingLabel: 'Start ›', state: StepCardState.current, onTap: () {}),
    StepCard3D(tone: t, art: ListingArt.star, eyebrow: 'Step 4', title: 'Review and submit', subtitle: 'Complete step 3 first', trailingLabel: 'Locked', state: StepCardState.locked, onTap: () {}),
    StepCard3D(tone: ListingTone.indigo, art: ListingArt.moneyBag, eyebrow: 'Optional', title: 'Advance details', subtitle: 'Add licence and date of birth', subtitleBad: true, trailingIcon: Icons.edit_rounded, state: StepCardState.current, onTap: () {}),
  ]);
}

Widget _taxi({bool errors = false}) {
  final t = ListingTone.coral;
  return _page(
    ListingPalette.coral,
    [
      PageHeader3D(tone: t, title: 'Vehicle', art: ListingArt.taxi, onBack: () {}, inlineTitle: true),
      StepProgressHeader(tone: t, labels: const ['Vehicle', 'Driver', 'Base'], current: errors ? 1 : 0),
      FormSectionCard(
        tone: t,
        art: ListingArt.taxi,
        artSide: FormArtSide.right,
        title: 'Vehicle Type',
        requiredMark: true,
        child: PillPickerField(tone: t, value: errors ? null : 'Innova Crysta', hint: 'Select vehicle', leadingArt: ListingArt.taxi, helperText: 'Pick from the list. Admin keeps the list updated.', errorText: errors ? 'Select your vehicle type' : null, onTap: () {}),
      ),
      FormSectionCard(
        tone: t,
        art: ListingArt.bus,
        artSide: FormArtSide.right,
        title: 'Seats',
        requiredMark: true,
        child: SegmentPills(tone: t, labels: const ['4', '6', '7', '12+'], selected: errors ? null : 2, errorRing: errors, onTap: (_) {}),
      ),
      FormSectionCard(
        tone: t,
        art: ListingArt.clipboard,
        artSide: FormArtSide.right,
        title: 'Driving Licence',
        requiredMark: true,
        hint: 'Only Bakhli admin sees this',
        child: PillField(
          tone: t,
          controller: TextEditingController(text: 'UK07 2015001'),
          style: PillField.textStyle.copyWith(letterSpacing: 1.5, fontWeight: FontWeight.w600),
          errorText: errors ? 'Enter a valid licence number' : null,
          helperText: 'As on your licence, e.g. UK07 20150012345',
        ),
      ),
      FormSectionCard(
        tone: t,
        art: ListingArt.speechBalloon,
        artSide: FormArtSide.right,
        title: 'Contact',
        requiredMark: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PillField(tone: t, label: 'Phone Number', prefixText: '+91', controller: TextEditingController(text: '9876543210'), enabled: false),
            PillField(tone: t, label: 'WhatsApp Number', firstLabel: false, prefixText: '+91', controller: TextEditingController(text: '91234 5678'), errorRing: errors, reserveMessage: true),
            ToggleRow(tone: t, label: 'Same as my login number', value: false, onChanged: (_) {}),
          ],
        ),
      ),
    ],
    bottom: FormFooter(tone: t, primaryLabel: 'Next: Driver', onPrimary: () {}, secondaryLabel: 'Back', onSecondary: () {}),
  );
}

Widget _jobs() {
  final t = ListingTone.indigo;
  return _page(
    ListingPalette.indigo,
    [
      PageHeader3D(tone: t, title: 'Post a Job', art: ListingArt.luggage, onBack: () {}, inlineTitle: true),
      StepProgressHeader(tone: t, labels: const ['Basics', 'Details', 'Extras'], current: 1, activeLabelColor: Ink3D.title),
      FormSectionCard(
        tone: t,
        art: ListingArt.calendar,
        title: 'Salary Type',
        requiredMark: true,
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ChoicePill(tone: t, label: 'Monthly', selected: true, outlined: true, height: 40, onTap: () {}),
            ChoicePill(tone: t, label: 'Daily', selected: false, outlined: true, height: 40, onTap: () {}),
            ChoicePill(tone: t, label: 'Hourly', selected: false, outlined: true, height: 40, onTap: () {}),
          ],
        ),
      ),
      FormSectionCard(
        tone: t,
        art: ListingArt.moneyBag,
        title: 'Salary Range (₹)',
        requiredMark: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: PillField(tone: t, label: 'Min', controller: TextEditingController(text: '12000'))),
            const SizedBox(width: 10),
            Expanded(child: PillField(tone: t, label: 'Max', controller: TextEditingController(text: '9000'), autofocus: true)),
          ],
        ),
      ),
      FormSectionCard(
        tone: t,
        art: ListingArt.pushpin,
        title: 'Description',
        requiredMark: true,
        child: PillField(tone: t, hint: 'Duties, timings, food or stay', maxLines: 5, counterText: ''),
      ),
    ],
    bottom: FormFooter(tone: t, primaryLabel: 'Next: Extras', onPrimary: () {}, secondaryLabel: 'Back', onSecondary: () {}),
  );
}

Widget _sheetBits() {
  final t = ListingTone.indigo;
  final f = ListingTone.forest;
  Widget pad(Widget c) => Padding(padding: const EdgeInsets.fromLTRB(18, 14, 18, 0), child: c);
  return Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader3D(tone: t, title: 'Nainital to Delhi', subtitle: 'Sat, 14 Nov · 2 cars', onBack: () {}, surface: true, bottom: pad(const Text('bottom row'))),
            pad(PillPickerField(tone: t, label: 'Start date', value: 'Fri, 13 Nov 2026', leadingArt: ListingArt.calendar, raised: true, trailing: const SizedBox.shrink(), helperText: '3 days · back Sun, 15 Nov', onTap: () {})),
            pad(Row(children: [
              Expanded(child: StepperField(tone: t, label: 'Adults', value: 2, min: 1, onChanged: (_) {})),
              const SizedBox(width: 12),
              Expanded(child: StepperField(tone: t, label: 'Children', value: 0, onChanged: (_) {})),
            ])),
            pad(StepperField(tone: f, label: 'Units', leadingArt: ListingArt.bed, value: 1, min: 1, filled: true, onChanged: (_) {})),
            pad(StepperField(tone: f, label: 'Guests', leadingArt: ListingArt.backpack, value: 2, filled: true, onChanged: (_) {})),
            pad(PillPickerField(tone: f, sublabel: 'Price per night', value: '₹3,600', leadingArt: ListingArt.moneyBag, trailing: const SizedBox.shrink(), onTap: () {})),
            pad(Row(children: [
              Expanded(child: GradientOptionCard(tone: ListingTone.cE, art: ListingArt.sunrise, label: 'All', selected: false, onTap: () {})),
              const SizedBox(width: 10),
              Expanded(child: GradientOptionCard(tone: ListingTone.cA, art: ListingArt.bed, label: 'Homestay', selected: true, onTap: () {})),
              const SizedBox(width: 10),
              Expanded(child: GradientOptionCard(tone: ListingTone.cD, art: ListingArt.moneyBag, label: 'Price: high to low', selected: false, onTap: () {})),
            ])),
            pad(Wrap(spacing: 8, children: [
              ChoicePill(tone: t, topLabel: 'Sat', label: '14', selected: true, onTap: () {}),
              ChoicePill(tone: t, topLabel: 'Sun', label: '15', selected: false, onTap: () {}),
              ChoicePill(tone: t, topLabel: 'Mon', label: '16', selected: false, enabled: false, onTap: () {}),
            ])),
            pad(PillButtonRow(children: [WhitePillButton(tone: f, label: 'Clear', onTap: () {}), GradientPillButton(tone: f, label: 'Apply', onTap: () {})])),
            pad(PillButtonRow(children: [WhitePillButton(tone: t, label: 'Keep', danger: true, onTap: () {}), GradientPillButton(tone: t, label: 'Delete', danger: true, onTap: () {})])),
            pad(PillButtonRow(children: [WhitePillButton(tone: t, label: 'Not now', enabled: false, onTap: () {}), GradientPillButton(tone: t, label: 'Saving', loading: true, onTap: () {})])),
            pad(PillButtonRow(children: [WhitePillButton(tone: t, label: 'I will arrange myself', onTap: () {}), GradientPillButton(tone: t, label: 'Send request to driver', onTap: () {})])),
            pad(GradientPillButton(tone: t, label: 'Send offer', enabled: false, onTap: () {})),
            pad(DecoratedBox(
              decoration: BoxDecoration(gradient: f.gradient, borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Expanded(child: WhitePillButton(tone: f, label: 'Open', onGradient: true, icon: Icons.arrow_forward_rounded, onTap: () {})),
                  const SizedBox(width: 12),
                  Switch3D(tone: f, value: true, onGradient: true, onChanged: (_) {}),
                  const SizedBox(width: 8),
                  Switch3D(tone: f, value: false, onGradient: true, onChanged: (_) {}),
                ]),
              ),
            )),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() => shotsDir = r'F:\Dhasu\UI_Template_resume\Mock_Final\shots\kit_k1');

  final pages = <String, (Widget Function(), double)>{
    'stay_details': (() => _stayDetails(), 1500),
    'stay_errors': (() => _stayDetails(errors: true, long: true), 1500),
    'stay_rooms': (_stayRooms, 1300),
    'stay_rules': (_stayRules, 1500),
    'stay_hub': (_stayHub, 1250),
    'taxi_vehicle': (() => _taxi(), 1500),
    'taxi_errors': (() => _taxi(errors: true), 1500),
    'jobs_post': (_jobs, 1200),
    'sheet_bits': (_sheetBits, 1500),
  };

  for (final cfg in [(1.0, 360.0), (1.3, 360.0), (1.0, 300.0)]) {
    final tag = '${cfg.$1}_${cfg.$2.toInt()}';
    for (final e in pages.entries) {
      testWidgets('k1 ${e.key} $tag', (t) async {
        debugDisableShadows = false;
        await pumpPhone(t, e.value.$1(), size: Size(cfg.$2, e.value.$2 * (cfg.$1 > 1 ? 1.2 : 1)), textScale: cfg.$1);
        await settlePhone(t);
        await shot(t, '${e.key}_$tag');
        debugDisableShadows = true;
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('k1 phone 360x800 as the mock', (t) async {
    debugDisableShadows = false;
    await pumpPhone(t, _stayDetails());
    await settlePhone(t);
    await shot(t, 'phone_stay_details');
    await pumpPhone(t, _taxi(errors: true));
    await settlePhone(t);
    await shot(t, 'phone_taxi_errors');
    debugDisableShadows = true;
    expect(t.takeException(), isNull);
  });

  testWidgets('k1 taps, limits and validators', (t) async {
    final hits = <String>[];
    final tone = ListingTone.forest;
    final form = GlobalKey<FormState>();
    await pumpPhone(
      t,
      Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                children: [
                  PageHeader3D(tone: tone, title: 'T', onBack: () => hits.add('back')),
                  StepProgressHeader(tone: tone, labels: const ['A', 'B'], current: 0, onStepTap: (i) => hits.add('step$i')),
                  StepCard3D(tone: tone, art: ListingArt.bed, title: 'Open card', state: StepCardState.current, onTap: () => hits.add('card')),
                  StepCard3D(tone: tone, art: ListingArt.bed, title: 'Locked card', state: StepCardState.locked, onTap: () => hits.add('locked')),
                  PillField(tone: tone, fieldKey: const Key('f'), validator: (v) => (v ?? '').isEmpty ? 'Required here' : null),
                  PillPickerField(tone: tone, value: 'Pick me', onTap: () => hits.add('pick')),
                  StepperField(tone: tone, value: 1, min: 1, max: 2, minusKey: const Key('minus'), plusKey: const Key('plus'), onChanged: (v) => hits.add('v$v')),
                  ToggleRow(tone: tone, label: 'Toggle me', value: false, onChanged: (v) => hits.add('toggle$v')),
                  ToggleRow(tone: tone, label: 'Locked toggle', value: false, onChanged: (v) => hits.add('no'), enabled: false),
                  OptionTileGrid(tone: tone, items: const [OptionTileItem(label: 'Tile', art: ListingArt.bed)], isSelected: (_) => false, onTap: (i) => hits.add('tile$i')),
                  SegmentPills(tone: tone, labels: const ['S1', 'S2'], selected: 0, onTap: (i) => hits.add('seg$i')),
                  ChoicePill(tone: tone, label: 'Chip', selected: false, onTap: () => hits.add('chip')),
                  GradientOptionCard(tone: tone, art: ListingArt.bed, label: 'Option', selected: false, onTap: () => hits.add('option')),
                  DashedAddRow3D(tone: tone, label: 'Add row', onTap: () => hits.add('add')),
                  GradientPillButton(tone: tone, label: 'Busy', loading: true, onTap: () => hits.add('busy')),
                  GradientPillButton(tone: tone, label: 'Off', enabled: false, onTap: () => hits.add('off')),
                  FormFooter(tone: tone, primaryLabel: 'Go', onPrimary: () => hits.add('go'), secondaryLabel: 'Back2', onSecondary: () => hits.add('back2'), primaryKey: const Key('pk')),
                ],
              ),
            ),
          ),
        ),
      ),
      size: const Size(360, 1700),
    );
    await t.tap(find.byTooltip('Back'));
    await t.tap(find.text('B'));
    await t.tap(find.text('Open card'));
    await t.tap(find.text('Locked card'));
    await t.tap(find.text('Pick me'));
    await t.tap(find.byKey(const Key('minus')));
    await t.tap(find.byKey(const Key('plus')));
    await t.tap(find.byTooltip('Increase'));
    await t.tap(find.text('Toggle me'));
    await t.tap(find.text('Locked toggle'));
    await t.tap(find.text('Tile'));
    await t.tap(find.text('S2'));
    await t.tap(find.text('Chip'));
    await t.tap(find.text('Option'));
    await t.tap(find.text('Add row'));
    await t.tap(find.text('Busy'));
    await t.tap(find.text('Off'));
    await t.tap(find.byKey(const Key('pk')));
    await t.tap(find.text('Back2'));
    expect(hits, ['back', 'step1', 'card', 'pick', 'v2', 'v2', 'toggletrue', 'tile0', 'seg1', 'chip', 'option', 'add', 'go', 'back2']);
    expect(form.currentState!.validate(), isFalse);
    await t.pump();
    expect(find.text('Required here'), findsOneWidget);
    await t.pump(const Duration(seconds: 1));
    expect(t.takeException(), isNull);
  });

  testWidgets('k1 button row stacks when labels do not fit', (t) async {
    final tone = ListingTone.indigo;
    await pumpPhone(
      t,
      Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(children: [
            PillButtonRow(children: [WhitePillButton(tone: tone, label: 'Back', onTap: () {}), GradientPillButton(tone: tone, label: 'Next', onTap: () {})]),
            const SizedBox(height: 20),
            PillButtonRow(children: [WhitePillButton(tone: tone, label: 'I will arrange this myself', onTap: () {}), GradientPillButton(tone: tone, label: 'Send request to the driver now', onTap: () {})]),
          ]),
        ),
      ),
    );
    expect(t.getTopLeft(find.text('Back')).dy, moreOrLessEquals(t.getTopLeft(find.text('Next')).dy, epsilon: 1));
    expect(t.getSize(find.byType(WhitePillButton).first).width, moreOrLessEquals(t.getSize(find.byType(GradientPillButton).first).width, epsilon: 0.5));
    expect(t.getTopLeft(find.text('Send request to the driver now')).dy, lessThan(t.getTopLeft(find.text('I will arrange this myself')).dy));
    expect(t.takeException(), isNull);
  });
}
