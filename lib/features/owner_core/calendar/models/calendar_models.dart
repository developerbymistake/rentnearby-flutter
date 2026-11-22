import '../../json/owner_dates.dart';
import '../../json/owner_json.dart';
import '../../money/money_note_math.dart';
import '../../money/money_wire.dart';

enum EntryKind { auto, manual, unknown }

enum PriceDirection { lower, higher, unknown }

class CalendarEntry {
  const CalendarEntry({
    required this.id,
    this.kind = EntryKind.unknown,
    this.sourceType,
    this.sourceId,
    this.sourceAvailable,
    this.travellerRemoved = false,
    this.dateFrom,
    this.dateTo,
    this.timeOfDay,
    this.fromPlace,
    this.toPlace,
    this.label = '',
    this.detail,
    this.note,
    this.listedTotal,
    this.agreedTotal,
    this.finalAmount,
    this.receivedSoFar,
    this.paidInFull = false,
    this.received = 0,
    this.balance,
    this.chip = MoneyChip.none,
    this.chipAmount = 0,
    this.cancelled = false,
    this.version = 0,
    this.guests,
    this.seats,
    this.roomNames,
    this.places = const [],
    this.cancelledBy,
    this.cancelledOn,
  });

  final String id;
  final EntryKind kind;
  final String? sourceType;
  final String? sourceId;
  final bool? sourceAvailable;
  final bool travellerRemoved;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? timeOfDay;
  final String? fromPlace;
  final String? toPlace;
  final String label;
  final String? detail;
  final String? note;
  final int? listedTotal;
  final int? agreedTotal;
  final int? finalAmount;
  final int? receivedSoFar;
  final bool paidInFull;
  final int received;
  final int? balance;
  final MoneyChip chip;
  final int chipAmount;
  final bool cancelled;
  final int version;
  final int? guests;
  final int? seats;
  final String? roomNames;
  final List<String> places;
  final String? cancelledBy;
  final DateTime? cancelledOn;

  bool get isAuto => kind == EntryKind.auto;
  bool get isManual => kind == EntryKind.manual;
  bool get valid => id.isNotEmpty && kind != EntryKind.unknown && dateFrom != null;
  DateTime? get lastDay => dateTo ?? dateFrom;

  MoneyNote get money => MoneyNote(finalAmount: finalAmount, receivedSoFar: receivedSoFar, paidInFull: paidInFull);

  static const Map<String, EntryKind> kinds = {'Auto': EntryKind.auto, 'Manual': EntryKind.manual};

  factory CalendarEntry.fromJson(Map<String, dynamic> j) => CalendarEntry(
        id: OwnerJson.str(j['id']),
        kind: OwnerJson.pick(j['kind'], kinds, EntryKind.unknown),
        sourceType: OwnerJson.strOrNull(j['sourceType']),
        sourceId: OwnerJson.strOrNull(j['sourceId']),
        sourceAvailable: OwnerJson.boolOrNull(j['sourceAvailable']),
        travellerRemoved: OwnerJson.boolean(j['travellerRemoved']),
        dateFrom: OwnerDates.day(j['dateFrom']),
        dateTo: OwnerDates.day(j['dateTo']),
        timeOfDay: OwnerDates.time(j['timeOfDay']) == null ? null : OwnerJson.strOrNull(j['timeOfDay']),
        fromPlace: OwnerJson.strOrNull(j['fromPlace']),
        toPlace: OwnerJson.strOrNull(j['toPlace']),
        label: OwnerJson.strOrNull(j['label']) ?? '',
        detail: OwnerJson.strOrNull(j['detail']),
        note: OwnerJson.strOrNull(j['note']),
        listedTotal: OwnerJson.intOrNull(j['listedTotal']),
        agreedTotal: OwnerJson.intOrNull(j['agreedTotal']),
        finalAmount: OwnerJson.intOrNull(j['finalAmount']),
        receivedSoFar: OwnerJson.intOrNull(j[MoneyWire.receivedKey]),
        paidInFull: OwnerJson.boolean(j['paidInFull']),
        received: OwnerJson.integer(j['received']),
        balance: OwnerJson.intOrNull(j['balance']),
        chip: OwnerJson.pick(j['chip'], MoneyNoteMath.chipWire, MoneyChip.none),
        chipAmount: OwnerJson.integer(j['chipAmount']),
        cancelled: OwnerJson.boolean(j['cancelled']),
        version: OwnerJson.integer(j['version']),
        guests: OwnerJson.intOrNull(j['guests']),
        seats: OwnerJson.intOrNull(j['seats']),
        roomNames: OwnerJson.strOrNull(j['roomNames']),
        places: OwnerJson.strings(j['places']),
        cancelledBy: OwnerJson.strOrNull(j['cancelledBy']),
        cancelledOn: OwnerDates.day(j['cancelledOn']),
      );

  static List<CalendarEntry> listOf(Object? raw) => OwnerJson.list(raw, CalendarEntry.fromJson).where((e) => e.valid).toList();
}

class CalendarBlock {
  const CalendarBlock({required this.id, this.dateFrom, this.dateTo, this.reason, this.version = 0});

  final String id;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? reason;
  final int version;

  bool get valid => id.isNotEmpty && dateFrom != null && dateTo != null;

  factory CalendarBlock.fromJson(Map<String, dynamic> j) => CalendarBlock(
        id: OwnerJson.str(j['id']),
        dateFrom: OwnerDates.day(j['dateFrom']),
        dateTo: OwnerDates.day(j['dateTo']),
        reason: OwnerJson.strOrNull(j['reason']),
        version: OwnerJson.integer(j['version']),
      );

  static List<CalendarBlock> listOf(Object? raw) => OwnerJson.list(raw, CalendarBlock.fromJson).where((e) => e.valid).toList();
}

class SpecialPriceBand {
  const SpecialPriceBand({
    required this.id,
    this.dateFrom,
    this.dateTo,
    this.nights = 0,
    this.direction = PriceDirection.unknown,
    this.percent = 0,
    this.label,
    this.isPaused = false,
    this.pausedByPlan = false,
    this.live = false,
    this.version = 0,
  });

  final String id;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final int nights;
  final PriceDirection direction;
  final int percent;
  final String? label;
  final bool isPaused;
  final bool pausedByPlan;
  final bool live;
  final int version;

  bool get valid => id.isNotEmpty && dateFrom != null && dateTo != null;
  bool get active => !isPaused && !pausedByPlan && direction != PriceDirection.unknown;

  static const Map<String, PriceDirection> directions = {'Lower': PriceDirection.lower, 'Higher': PriceDirection.higher};

  factory SpecialPriceBand.fromJson(Map<String, dynamic> j) => SpecialPriceBand(
        id: OwnerJson.str(j['id']),
        dateFrom: OwnerDates.day(j['dateFrom']),
        dateTo: OwnerDates.day(j['dateTo']),
        nights: OwnerJson.integer(j['nights']),
        direction: OwnerJson.pick(j['direction'], directions, PriceDirection.unknown),
        percent: OwnerJson.integer(j['percent']),
        label: OwnerJson.strOrNull(j['label']),
        isPaused: OwnerJson.boolean(j['isPaused']),
        pausedByPlan: OwnerJson.boolean(j['pausedByPlan']),
        live: OwnerJson.boolean(j['live']),
        version: OwnerJson.integer(j['version']),
      );

  static List<SpecialPriceBand> listOf(Object? raw) => OwnerJson.list(raw, SpecialPriceBand.fromJson).where((e) => e.valid).toList();
}

class FestivalRow {
  const FestivalRow({required this.id, required this.name, this.dateFrom, this.dateTo, this.stateName, this.daysAway});

  final String id;
  final String name;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? stateName;
  final int? daysAway;

  bool get valid => id.isNotEmpty && name.isNotEmpty && dateFrom != null && dateTo != null;

  factory FestivalRow.fromJson(Map<String, dynamic> j) => FestivalRow(
        id: OwnerJson.str(j['id']),
        name: OwnerJson.str(j['name']),
        dateFrom: OwnerDates.day(j['dateFrom']),
        dateTo: OwnerDates.day(j['dateTo']),
        stateName: OwnerJson.strOrNull(j['stateName']),
        daysAway: OwnerJson.intOrNull(j['daysAway']),
      );

  static FestivalRow? maybe(Object? raw) {
    final m = OwnerJson.mapOrNull(raw);
    if (m == null) return null;
    final f = FestivalRow.fromJson(m);
    return f.valid ? f : null;
  }

  static List<FestivalRow> listOf(Object? raw) => OwnerJson.list(raw, FestivalRow.fromJson).where((e) => e.valid).toList();
}

class Meter {
  const Meter({required this.key, this.used = 0, this.limit = 0});

  final String key;
  final int used;
  final int limit;

  bool get full => used >= limit;

  factory Meter.fromJson(Map<String, dynamic> j) =>
      Meter(key: OwnerJson.str(j['key']), used: OwnerJson.integer(j['used']), limit: OwnerJson.integer(j['limit']));

  static Meter? maybe(Object? raw) {
    final m = OwnerJson.mapOrNull(raw);
    if (m == null) return null;
    return Meter(key: OwnerJson.str(m['key']), used: OwnerJson.integer(m['used']), limit: OwnerJson.integer(m['limit']));
  }

  static List<Meter> listOf(Object? raw) => OwnerJson.list(raw, Meter.fromJson).where((m) => m.key.isNotEmpty).toList();

  static Meter? find(List<Meter> meters, String key) {
    for (final m in meters) {
      if (m.key == key) return m;
    }
    return null;
  }
}

class CalendarWindow {
  const CalendarWindow({this.upcomingTo, this.monthFrom, this.monthTo, this.manualFrom, this.manualTo, this.locked = false});

  final DateTime? upcomingTo;
  final DateTime? monthFrom;
  final DateTime? monthTo;
  final DateTime? manualFrom;
  final DateTime? manualTo;
  final bool locked;

  factory CalendarWindow.fromJson(Map<String, dynamic> j) => CalendarWindow(
        upcomingTo: OwnerDates.day(j['upcomingTo']),
        monthFrom: OwnerDates.day(j['monthFrom']),
        monthTo: OwnerDates.day(j['monthTo']),
        manualFrom: OwnerDates.day(j['manualFrom']),
        manualTo: OwnerDates.day(j['manualTo']),
        locked: OwnerJson.boolean(j['locked']),
      );

  List<DateTime> months(DateTime today) {
    final from = OwnerDates.firstOfMonth(monthFrom ?? today);
    final to = OwnerDates.firstOfMonth(monthTo ?? today);
    final out = <DateTime>[];
    var m = from;
    while (!m.isAfter(to) && out.length < 13) {
      out.add(m);
      m = OwnerDates.addMonths(m, 1);
    }
    return out.isEmpty ? [OwnerDates.firstOfMonth(today)] : out;
  }

  bool allowsManual(DateTime d) {
    final from = manualFrom;
    final to = manualTo;
    if (from == null || to == null) return true;
    return OwnerDates.within(d, from, to);
  }
}

class CalendarReminder {
  const CalendarReminder({this.allowed = false, this.on = false});

  final bool allowed;
  final bool on;

  factory CalendarReminder.fromJson(Map<String, dynamic> j) =>
      CalendarReminder(allowed: OwnerJson.boolean(j['allowed']), on: OwnerJson.boolean(j['on']));
}

class CalendarMonth {
  const CalendarMonth({
    this.entries = const [],
    this.blocks = const [],
    this.specialPrices = const [],
    this.festivals = const [],
    this.meters = const [],
    this.window = const CalendarWindow(),
    this.hiddenCount = 0,
    this.reminder = const CalendarReminder(),
    this.summaryAllowed = false,
    this.paymentEnabled = false,
    this.today,
    this.raw = const {},
  });

  final Map<String, dynamic> raw;
  final List<CalendarEntry> entries;
  final List<CalendarBlock> blocks;
  final List<SpecialPriceBand> specialPrices;
  final List<FestivalRow> festivals;
  final List<Meter> meters;
  final CalendarWindow window;
  final int hiddenCount;
  final CalendarReminder reminder;
  final bool summaryAllowed;
  final bool paymentEnabled;
  final DateTime? today;

  factory CalendarMonth.fromJson(Map<String, dynamic> j) => CalendarMonth(
        entries: CalendarEntry.listOf(j['entries']),
        blocks: CalendarBlock.listOf(j['blocks']),
        specialPrices: SpecialPriceBand.listOf(j['specialPrices']),
        festivals: FestivalRow.listOf(j['festivals']),
        meters: Meter.listOf(j['meters']),
        window: CalendarWindow.fromJson(OwnerJson.map(j['window'])),
        hiddenCount: OwnerJson.integer(j['hiddenCount']),
        reminder: CalendarReminder.fromJson(OwnerJson.map(j['reminder'])),
        summaryAllowed: OwnerJson.boolean(j['summaryAllowed']),
        paymentEnabled: OwnerJson.boolean(j['paymentEnabled']),
        today: OwnerDates.day(j['today']),
        raw: j,
      );
}

class UpcomingPage {
  const UpcomingPage({this.items = const [], this.nextCursor, this.hiddenCount = 0, this.beyondWindowAppCount = 0, this.beyondWindowFirstDate});

  final List<CalendarEntry> items;
  final String? nextCursor;
  final int hiddenCount;
  final int beyondWindowAppCount;
  final DateTime? beyondWindowFirstDate;

  factory UpcomingPage.fromJson(Map<String, dynamic> j) => UpcomingPage(
        items: CalendarEntry.listOf(j['items']),
        nextCursor: OwnerJson.strOrNull(j['nextCursor']),
        hiddenCount: OwnerJson.integer(j['hiddenCount']),
        beyondWindowAppCount: OwnerJson.integer(j['beyondWindowAppCount']),
        beyondWindowFirstDate: OwnerDates.day(j['beyondWindowFirstDate']),
      );
}

class MoneySummary {
  const MoneySummary({
    this.month,
    this.booked = 0,
    this.received = 0,
    this.toCollect = 0,
    this.entryCount = 0,
    this.dueCount = 0,
    this.top = const [],
    this.raw = const {},
  });

  final Map<String, dynamic> raw;

  final DateTime? month;
  final int booked;
  final int received;
  final int toCollect;
  final int entryCount;
  final int dueCount;
  final List<CalendarEntry> top;

  factory MoneySummary.fromJson(Map<String, dynamic> j) => MoneySummary(
        month: OwnerDates.month(j['month']),
        booked: OwnerJson.integer(j['finalTotal']),
        received: OwnerJson.integer(j['receivedTotal']),
        toCollect: OwnerJson.integer(j['balanceTotal']),
        entryCount: OwnerJson.integer(j['entryCount']),
        dueCount: OwnerJson.integer(j['dueCount']),
        top: CalendarEntry.listOf(j['topBalances']),
        raw: j,
      );

  MoneySummary paid(int amount) => MoneySummary(
        month: month,
        booked: booked,
        received: received + amount,
        toCollect: toCollect - amount,
        entryCount: entryCount,
        dueCount: dueCount > 0 ? dueCount - 1 : 0,
        top: top,
      );
}

class EntryOverlap {
  const EntryOverlap({this.bookings = 0, this.blocked = 0});

  final int bookings;
  final int blocked;

  factory EntryOverlap.fromJson(Map<String, dynamic> j) =>
      EntryOverlap(bookings: OwnerJson.integer(j['bookings']), blocked: OwnerJson.integer(j['blocked']));
}

class EntryWriteResult {
  const EntryWriteResult({this.entry, this.meters = const [], this.overlap = const EntryOverlap()});

  final CalendarEntry? entry;
  final List<Meter> meters;
  final EntryOverlap overlap;

  factory EntryWriteResult.ofEntry(CalendarEntry e) => EntryWriteResult(entry: e.valid ? e : null);

  factory EntryWriteResult.fromJson(Map<String, dynamic> j) {
    final raw = OwnerJson.mapOrNull(j['entry']);
    final e = raw == null ? null : CalendarEntry.fromJson(raw);
    return EntryWriteResult(
      entry: e != null && e.valid ? e : null,
      meters: Meter.listOf(j['meters']),
      overlap: EntryOverlap.fromJson(OwnerJson.map(j['overlap'])),
    );
  }
}
