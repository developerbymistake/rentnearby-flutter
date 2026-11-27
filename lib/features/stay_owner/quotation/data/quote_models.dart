import '../../../owner_core/data/owner_result.dart';
import '../../../owner_core/json/owner_json.dart';

enum QuoteKind {
  quotation('Quotation', 'Q-'),
  proforma('Proforma', 'PI-');

  const QuoteKind(this.wire, this.prefix);

  final String wire;
  final String prefix;

  static const int numberPad = 4;

  static QuoteKind fromWire(Object? v) => v == proforma.wire ? proforma : quotation;

  String display(int number) => '$prefix${number.toString().padLeft(numberPad, '0')}';
}

enum QuoteImageKind {
  logo('logo'),
  signature('signature');

  const QuoteImageKind(this.wire);

  final String wire;
}

enum QuoteBankMode {
  keep('Keep'),
  set('Set'),
  clear('Clear');

  const QuoteBankMode(this.wire);

  final String wire;
}

abstract final class QuoteErrorTypes {
  static const validation = 'ValidationError';
  static const gstinMismatch = 'QuoteGstinMismatch';
  static const termsVersionUnknown = 'QuoteTermsVersionUnknown';
  static const photoInvalid = 'PhotoInvalid';
  static const photoTooLarge = 'PhotoTooLarge';
  static const roleMismatch = 'RoleMismatch';
  static const stayNotFound = 'StayNotFound';
  static const imageMissing = 'QuoteImageMissing';
  static const stayNotApproved = 'StayNotApproved';
  static const termsNotAccepted = 'QuoteTermsNotAccepted';
  static const monthLimit = 'QuotationMonthLimit';
  static const rateLimited = 'RateLimited';
  static const bankUnavailable = 'QuoteBankUnavailable';
  static const photoBusy = 'PhotoBusy';

  static const planKeyWire = 'StayQuotationsPerMonth';
}

// Every user-scoped name on the phone (ARCHITECTURE 9.5); one place so the wipe and both lanes agree.
abstract final class QuoteStorageNames {
  static String indexBox(String userId) => 'quote_index_$userId';
  static String cacheBox(String userId) => 'quote_cache_$userId';
  static String bankKey(String userId) => 'quote_bank_$userId';
  static String imageFile(QuoteImageKind kind, int version) => '${kind.wire}_$version.jpg';
}

abstract final class QuoteTime {
  static const Duration ist = Duration(hours: 5, minutes: 30);

  static DateTime toIst(DateTime t) => t.toUtc().add(ist);

  static bool sameIstMonth(DateTime a, DateTime b) {
    final x = toIst(a);
    final y = toIst(b);
    return x.year == y.year && x.month == y.month;
  }
}

class QuoteStay {
  const QuoteStay({required this.name, required this.approved, this.pendingName, this.lastNameResult, this.hasGstin = false});

  final String name;
  final bool approved;
  final String? pendingName;
  final String? lastNameResult;
  final bool hasGstin;

  factory QuoteStay.fromJson(Map<String, dynamic> j) => QuoteStay(
        name: OwnerJson.str(j['name']),
        approved: OwnerJson.boolean(j['approved']),
        pendingName: OwnerJson.strOrNull(j['pendingName']),
        lastNameResult: OwnerJson.strOrNull(j['lastNameResult']),
        hasGstin: OwnerJson.boolean(j['hasGstin']),
      );

  Map<String, dynamic> toJson() =>
      {'name': name, 'approved': approved, 'pendingName': pendingName, 'lastNameResult': lastNameResult, 'hasGstin': hasGstin};

  QuoteStay withPendingName(String? value) =>
      QuoteStay(name: name, approved: approved, pendingName: value, lastNameResult: lastNameResult, hasGstin: hasGstin);
}

// Masked summary only; the full block comes from GET /profile/bank and lives in secure storage.
class QuoteBankSummary {
  const QuoteBankSummary({this.has = false, this.bank, this.branch, this.accountLast4, this.ifsc, this.upiMasked});

  final bool has;
  final String? bank;
  final String? branch;
  final String? accountLast4;
  final String? ifsc;
  final String? upiMasked;

  static const none = QuoteBankSummary();

  bool get hasAccount => accountLast4 != null;
  bool get hasUpi => upiMasked != null;

  factory QuoteBankSummary.fromJson(Map<String, dynamic> j) => QuoteBankSummary(
        has: OwnerJson.boolean(j['has']),
        bank: OwnerJson.strOrNull(j['bank']),
        branch: OwnerJson.strOrNull(j['branch']),
        accountLast4: OwnerJson.strOrNull(j['accountLast4']),
        ifsc: OwnerJson.strOrNull(j['ifsc']),
        upiMasked: OwnerJson.strOrNull(j['upiMasked']),
      );

  Map<String, dynamic> toJson() =>
      {'has': has, 'bank': bank, 'branch': branch, 'accountLast4': accountLast4, 'ifsc': ifsc, 'upiMasked': upiMasked};
}

class QuoteProfile {
  const QuoteProfile({
    this.slogan,
    this.address,
    this.phone,
    this.email,
    this.gstin,
    this.bank = QuoteBankSummary.none,
    this.termsText,
    this.cancellationText,
    this.hasLogo = false,
    this.hasSignature = false,
    this.assetsVersion = 0,
    this.updatedAt,
  });

  final String? slogan;
  final String? address;
  final String? phone;
  final String? email;
  final String? gstin;
  final QuoteBankSummary bank;
  final String? termsText;
  final String? cancellationText;
  final bool hasLogo;
  final bool hasSignature;
  final int assetsVersion;
  final DateTime? updatedAt;

  bool hasImage(QuoteImageKind kind) => kind == QuoteImageKind.logo ? hasLogo : hasSignature;

  factory QuoteProfile.fromJson(Map<String, dynamic> j) => QuoteProfile(
        slogan: OwnerJson.strOrNull(j['slogan']),
        address: OwnerJson.strOrNull(j['address']),
        phone: OwnerJson.strOrNull(j['phone']),
        email: OwnerJson.strOrNull(j['email']),
        gstin: OwnerJson.strOrNull(j['gstin']),
        bank: QuoteBankSummary.fromJson(OwnerJson.map(j['bank'])),
        termsText: OwnerJson.strOrNull(j['termsText']),
        cancellationText: OwnerJson.strOrNull(j['cancellationText']),
        hasLogo: OwnerJson.boolean(j['hasLogo']),
        hasSignature: OwnerJson.boolean(j['hasSignature']),
        assetsVersion: OwnerJson.integer(j['assetsVersion']),
        updatedAt: OwnerJson.time(j['updatedAt']),
      );

  // The phone cache keeps no bank value at all (ARCHITECTURE 9.5): only whether one exists.
  Map<String, dynamic> toCacheJson() => {
        'slogan': slogan,
        'address': address,
        'phone': phone,
        'email': email,
        'gstin': gstin,
        'bank': {'has': bank.has},
        'termsText': termsText,
        'cancellationText': cancellationText,
        'hasLogo': hasLogo,
        'hasSignature': hasSignature,
        'assetsVersion': assetsVersion,
        'updatedAt': updatedAt?.toUtc().toIso8601String(),
      };

  QuoteProfile withImage(QuoteImageKind kind, {required bool has, required int assetsVersion}) => QuoteProfile(
        slogan: slogan,
        address: address,
        phone: phone,
        email: email,
        gstin: gstin,
        bank: bank,
        termsText: termsText,
        cancellationText: cancellationText,
        hasLogo: kind == QuoteImageKind.logo ? has : hasLogo,
        hasSignature: kind == QuoteImageKind.signature ? has : hasSignature,
        assetsVersion: assetsVersion,
        updatedAt: updatedAt,
      );
}

class QuoteDefaults {
  const QuoteDefaults({this.address, this.phone, this.upi});

  final String? address;
  final String? phone;
  final String? upi;

  factory QuoteDefaults.fromJson(Map<String, dynamic> j) => QuoteDefaults(
        address: OwnerJson.strOrNull(j['address']),
        phone: OwnerJson.strOrNull(j['phone']),
        upi: OwnerJson.strOrNull(j['upi']),
      );

  // UPI is a payment detail: kept out of the phone cache like the bank block.
  Map<String, dynamic> toCacheJson() => {'address': address, 'phone': phone};
}

class QuoteTermsState {
  const QuoteTermsState({required this.currentVersion, this.acceptedVersion, this.acceptedAt});

  final int currentVersion;
  final int? acceptedVersion;
  final DateTime? acceptedAt;

  bool get accepted => acceptedVersion != null && acceptedVersion == currentVersion;

  factory QuoteTermsState.fromJson(Map<String, dynamic> j) => QuoteTermsState(
        currentVersion: OwnerJson.integer(j['currentVersion'], 1),
        acceptedVersion: OwnerJson.intOrNull(j['acceptedVersion']),
        acceptedAt: OwnerJson.time(j['acceptedAt']),
      );

  Map<String, dynamic> toJson() =>
      {'currentVersion': currentVersion, 'acceptedVersion': acceptedVersion, 'acceptedAt': acceptedAt?.toUtc().toIso8601String()};
}

class QuoteUsage {
  const QuoteUsage({required this.used, required this.limit, this.resetsAt, this.canUpgrade = false});

  final int used;
  final int limit;
  final DateTime? resetsAt;
  final bool canUpgrade;

  bool get full => used >= limit;

  factory QuoteUsage.fromJson(Map<String, dynamic> j) => QuoteUsage(
        used: OwnerJson.integer(j['used']),
        limit: OwnerJson.integer(j['limit']),
        resetsAt: OwnerJson.time(j['resetsAt']),
        canUpgrade: OwnerJson.boolean(j['canUpgrade']),
      );

  Map<String, dynamic> toJson() => {'used': used, 'limit': limit, 'resetsAt': resetsAt?.toUtc().toIso8601String(), 'canUpgrade': canUpgrade};
}

class QuoteNext {
  const QuoteNext({required this.quotation, required this.proforma});

  final int quotation;
  final int proforma;

  int of(QuoteKind kind) => kind == QuoteKind.proforma ? proforma : quotation;

  factory QuoteNext.fromJson(Map<String, dynamic> j) =>
      QuoteNext(quotation: OwnerJson.integer(j['quotation'], 1), proforma: OwnerJson.integer(j['proforma'], 1));

  Map<String, dynamic> toJson() => {'quotation': quotation, 'proforma': proforma};
}

class QuoteHub {
  const QuoteHub({
    required this.stay,
    this.preparedBy,
    this.profile,
    this.defaults = const QuoteDefaults(),
    required this.terms,
    required this.usage,
    required this.next,
    this.bankStorage = true,
    this.bankUnreadable = false,
    this.minTemplateVersion = 1,
    this.previewWatermark = true,
    this.maxFreePerWindow = 0,
  });

  final QuoteStay stay;
  final String? preparedBy;
  final QuoteProfile? profile;
  final QuoteDefaults defaults;
  final QuoteTermsState terms;
  final QuoteUsage usage;
  final QuoteNext next;
  final bool bankStorage;
  final bool bankUnreadable;
  final int minTemplateVersion;
  final bool previewWatermark;
  final int maxFreePerWindow;

  bool get hasGstin => (profile?.gstin ?? '').isNotEmpty;

  factory QuoteHub.fromJson(Map<String, dynamic> j) {
    final profile = OwnerJson.mapOrNull(j['profile']);
    return QuoteHub(
      stay: QuoteStay.fromJson(OwnerJson.map(j['stay'])),
      preparedBy: OwnerJson.strOrNull(j['preparedBy']),
      profile: profile == null ? null : QuoteProfile.fromJson(profile),
      defaults: QuoteDefaults.fromJson(OwnerJson.map(j['defaults'])),
      terms: QuoteTermsState.fromJson(OwnerJson.map(j['terms'])),
      usage: QuoteUsage.fromJson(OwnerJson.map(j['usage'])),
      next: QuoteNext.fromJson(OwnerJson.map(j['next'])),
      bankStorage: OwnerJson.boolean(j['bankStorage'], true),
      bankUnreadable: OwnerJson.boolean(j['bankUnreadable']),
      minTemplateVersion: OwnerJson.integer(j['minTemplateVersion'], 1),
      previewWatermark: OwnerJson.boolean(j['previewWatermark'], true),
      maxFreePerWindow: OwnerJson.integer(j['maxFreePerWindow']),
    );
  }

  Map<String, dynamic> toCacheJson() => {
        'stay': stay.toJson(),
        'preparedBy': preparedBy,
        'profile': profile?.toCacheJson(),
        'defaults': defaults.toCacheJson(),
        'terms': terms.toJson(),
        'usage': usage.toJson(),
        'next': next.toJson(),
        'bankStorage': bankStorage,
        'bankUnreadable': bankUnreadable,
        'minTemplateVersion': minTemplateVersion,
        'previewWatermark': previewWatermark,
        'maxFreePerWindow': maxFreePerWindow,
      };

  QuoteHub copyWith({QuoteStay? stay, QuoteProfile? profile, QuoteTermsState? terms, QuoteUsage? usage, QuoteNext? next, bool? bankUnreadable}) => QuoteHub(
        stay: stay ?? this.stay,
        preparedBy: preparedBy,
        profile: profile ?? this.profile,
        defaults: defaults,
        terms: terms ?? this.terms,
        usage: usage ?? this.usage,
        next: next ?? this.next,
        bankStorage: bankStorage,
        bankUnreadable: bankUnreadable ?? this.bankUnreadable,
        minTemplateVersion: minTemplateVersion,
        previewWatermark: previewWatermark,
        maxFreePerWindow: maxFreePerWindow,
      );
}

class QuoteHubResponse {
  const QuoteHubResponse({required this.notModified, this.etag, this.hub});

  final bool notModified;
  final String? etag;
  final QuoteHub? hub;
}

class QuoteBank {
  const QuoteBank({this.holder = '', this.accountNo = '', this.ifsc = '', this.bank = '', this.branch = '', this.upi = ''});

  final String holder;
  final String accountNo;
  final String ifsc;
  final String bank;
  final String branch;
  final String upi;

  static const empty = QuoteBank();

  bool get hasAccount => accountNo.isNotEmpty;
  bool get isEmpty => holder.isEmpty && accountNo.isEmpty && ifsc.isEmpty && bank.isEmpty && branch.isEmpty && upi.isEmpty;

  String get last4 => accountNo.length <= 4 ? accountNo : accountNo.substring(accountNo.length - 4);

  factory QuoteBank.fromJson(Map<String, dynamic> j) => QuoteBank(
        holder: OwnerJson.str(j['holder']),
        accountNo: OwnerJson.str(j['accountNo']),
        ifsc: OwnerJson.str(j['ifsc']),
        bank: OwnerJson.str(j['bank']),
        branch: OwnerJson.str(j['branch']),
        upi: OwnerJson.str(j['upi']),
      );

  static String? _orNull(String v) => v.isEmpty ? null : v;

  Map<String, dynamic> toJson() =>
      {'holder': _orNull(holder), 'accountNo': _orNull(accountNo), 'ifsc': _orNull(ifsc), 'bank': _orNull(bank), 'branch': _orNull(branch), 'upi': _orNull(upi)};

  QuoteBank withUpi(String value) => QuoteBank(holder: holder, accountNo: accountNo, ifsc: ifsc, bank: bank, branch: branch, upi: value);

  QuoteBank withoutAccount() => QuoteBank(upi: upi);

  @override
  bool operator ==(Object other) =>
      other is QuoteBank &&
      other.holder == holder &&
      other.accountNo == accountNo &&
      other.ifsc == ifsc &&
      other.bank == bank &&
      other.branch == branch &&
      other.upi == upi;

  @override
  int get hashCode => Object.hash(holder, accountNo, ifsc, bank, branch, upi);
}

// PUT /profile body. The business name is never part of it (Q5).
class QuoteProfileInput {
  const QuoteProfileInput({
    this.slogan = '',
    this.address = '',
    this.phone = '',
    this.email = '',
    this.gstin = '',
    this.termsText = '',
    this.cancellationText = '',
    this.bankMode = QuoteBankMode.keep,
    this.bank,
  });

  final String slogan;
  final String address;
  final String phone;
  final String email;
  final String gstin;
  final String termsText;
  final String cancellationText;
  final QuoteBankMode bankMode;
  final QuoteBank? bank;

  static String? _orNull(String v) => v.isEmpty ? null : v;

  Map<String, dynamic> toJson() => {
        'slogan': _orNull(slogan),
        'address': _orNull(address),
        'phone': _orNull(phone),
        'email': _orNull(email),
        'gstin': _orNull(gstin),
        'termsText': _orNull(termsText),
        'cancellationText': _orNull(cancellationText),
        'bankMode': bankMode.wire,
        'bank': bankMode == QuoteBankMode.set ? bank?.toJson() : null,
      };
}

class QuoteTermsAccepted {
  const QuoteTermsAccepted({required this.acceptedVersion, this.acceptedAt});

  final int acceptedVersion;
  final DateTime? acceptedAt;

  factory QuoteTermsAccepted.fromJson(Map<String, dynamic> j) =>
      QuoteTermsAccepted(acceptedVersion: OwnerJson.integer(j['acceptedVersion']), acceptedAt: OwnerJson.time(j['acceptedAt']));
}

class QuoteReserveResult {
  const QuoteReserveResult({
    required this.number,
    required this.display,
    required this.kind,
    required this.counted,
    this.freeUntil,
    this.freeLeft = 0,
    this.issuedAt,
    required this.usage,
    required this.businessName,
    this.assetsVersion = 0,
  });

  final int number;
  final String display;
  final QuoteKind kind;
  final bool counted;
  final DateTime? freeUntil;
  final int freeLeft;
  final DateTime? issuedAt;
  final QuoteUsage usage;
  final String businessName;
  final int assetsVersion;

  factory QuoteReserveResult.fromJson(Map<String, dynamic> j) {
    final kind = QuoteKind.fromWire(j['kind']);
    final number = OwnerJson.integer(j['number']);
    return QuoteReserveResult(
      number: number,
      display: OwnerJson.strOrNull(j['display']) ?? kind.display(number),
      kind: kind,
      counted: OwnerJson.boolean(j['counted']),
      freeUntil: OwnerJson.time(j['freeUntil']),
      freeLeft: OwnerJson.integer(j['freeLeft']),
      issuedAt: OwnerJson.time(j['issuedAt']),
      usage: QuoteUsage.fromJson(OwnerJson.map(j['usage'])),
      businessName: OwnerJson.str(j['businessName']),
      assetsVersion: OwnerJson.integer(j['assetsVersion']),
    );
  }
}

// data of 409 QuotationMonthLimit: {key, limit, used, canUpgrade, resetsAt}.
class QuoteLimitInfo {
  const QuoteLimitInfo({required this.limit, required this.used, required this.canUpgrade, this.resetsAt});

  final int limit;
  final int used;
  final bool canUpgrade;
  final DateTime? resetsAt;

  static QuoteLimitInfo? of(OwnerRefused<dynamic> r) {
    if (r.type != QuoteErrorTypes.monthLimit) return null;
    final d = r.data;
    final limit = OwnerJson.intOrNull(d['limit']);
    if (limit == null) return null;
    return QuoteLimitInfo(
      limit: limit,
      used: OwnerJson.integer(d['used']),
      canUpgrade: OwnerJson.boolean(d['canUpgrade']),
      resetsAt: OwnerJson.time(d['resetsAt']),
    );
  }
}

// 400 ValidationError data: field -> message (camelCase field names of the request).
abstract final class QuoteFieldErrors {
  static Map<String, String> of(OwnerRefused<dynamic> r) {
    if (r.type != QuoteErrorTypes.validation) return const {};
    final out = <String, String>{};
    r.data.forEach((k, v) {
      final msg = v is List && v.isNotEmpty ? v.first : v;
      if (msg is String && msg.isNotEmpty) out[_field(k)] = msg;
    });
    return out;
  }

  static String _field(String k) {
    final last = k.split('.').last;
    return last.isEmpty ? k : last[0].toLowerCase() + last.substring(1);
  }
}
