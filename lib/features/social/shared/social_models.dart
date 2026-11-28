import '../../buddy/shared/buddy_json.dart';
import '../../buddy/shared/models/person_models.dart';
import 'social_formats.dart';
import 'travel_levels.dart';

class SocialPerson {
  const SocialPerson({required this.userId, required this.name, this.username, this.photoUrl, required this.initial, this.homeCity, this.gender = '', this.completedTrips = 0, this.level = 0});

  final String userId;
  final String name;
  final String? username;
  final String? photoUrl;
  final String initial;
  final String? homeCity;
  final String gender;
  final int completedTrips;
  final int level;

  TravelLevel get travelLevel => TravelLevels.at(level);

  String get shortName => SocialFormats.shortName(name);

  BuddyPerson get asBuddyPerson => BuddyPerson(userId: userId, name: name, username: username, initial: initial, photoUrl: photoUrl);

  factory SocialPerson.fromJson(Map<String, dynamic> j) {
    final name = BuddyJson.str(j['name']);
    final initial = BuddyJson.str(j['initial']);
    final done = BuddyJson.integer(j['completedTrips']);
    return SocialPerson(
      userId: BuddyJson.str(j['userId']),
      name: name,
      username: BuddyJson.strOrNull(j['username']),
      photoUrl: BuddyJson.photo(j['photoUrl']),
      initial: initial.isNotEmpty ? initial : (name.trim().isEmpty ? '' : name.trim().substring(0, 1).toUpperCase()),
      homeCity: BuddyJson.strOrNull(j['homeCity']),
      gender: BuddyJson.str(j['gender']),
      completedTrips: done,
      level: TravelLevels.parseLevel(j['level'], done),
    );
  }
}

class PersonRow {
  const PersonRow({
    required this.person,
    this.followsMe = false,
    this.iFollow = false,
    this.followRequested = false,
    this.isBuddy = false,
    this.mutualCount = 0,
    this.mutualName,
    this.requestedAt,
  });

  final SocialPerson person;
  final bool followsMe;
  final bool iFollow;
  final bool followRequested;
  final bool isBuddy;
  final int mutualCount;
  final String? mutualName;
  final DateTime? requestedAt;

  PersonRow copyWith({bool? iFollow, bool? followRequested, bool? isBuddy}) => PersonRow(
        person: person,
        followsMe: followsMe,
        iFollow: iFollow ?? this.iFollow,
        followRequested: followRequested ?? this.followRequested,
        isBuddy: isBuddy ?? this.isBuddy,
        mutualCount: mutualCount,
        mutualName: mutualName,
        requestedAt: requestedAt,
      );

  factory PersonRow.fromJson(Map<String, dynamic> j) => PersonRow(
        person: SocialPerson.fromJson(j),
        followsMe: BuddyJson.boolean(j['followsMe']),
        iFollow: BuddyJson.boolean(j['iFollow']),
        followRequested: BuddyJson.boolean(j['followRequested']),
        isBuddy: BuddyJson.boolean(j['isBuddy']),
        mutualCount: BuddyJson.integer(j['mutualCount']),
        mutualName: BuddyJson.strOrNull(j['mutualName']),
        requestedAt: BuddyJson.time(j['requestedAt']),
      );
}

class Mutuals {
  const Mutuals({required this.count, this.names = const [], this.photoUrls = const []});

  final int count;
  final List<String> names;
  final List<String> photoUrls;

  static const Mutuals none = Mutuals(count: 0);

  bool get isEmpty => count <= 0;

  factory Mutuals.fromJson(Map<String, dynamic>? j) {
    if (j == null) return none;
    return Mutuals(count: BuddyJson.integer(j['count']), names: BuddyJson.strings(j['names']), photoUrls: BuddyJson.strings(j['photoUrls']));
  }
}

class TripWhen {
  const TripWhen({required this.kind, this.months = 0, this.month = 0});

  static const String within = 'within';
  static const String monthKind = 'month';

  final String kind;
  final int months;
  final int month;

  factory TripWhen.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const TripWhen(kind: within);
    final kind = BuddyJson.str(j['kind'], within);
    return TripWhen(kind: kind == monthKind ? monthKind : within, months: BuddyJson.integer(j['months']), month: BuddyJson.integer(j['month']));
  }
}

abstract final class TravelModes {
  static const String taxi = 'taxi';
  static const String bike = 'bike';
  static const String bus = 'bus';
  static const String train = 'train';
  static const List<String> codes = [taxi, bike, bus, train];

  static String? parse(Object? v) => v is String && codes.contains(v) ? v : null;
}

class PublicTrip {
  const PublicTrip({
    required this.tripId,
    required this.owner,
    this.ownerInterests = const [],
    this.isMine = false,
    this.cityKey = 0,
    this.cityNames = const [],
    this.stateName,
    required this.when,
    this.days = 0,
    this.joinGender = 'A',
    this.seats = 0,
    this.seatsLeft = 0,
    this.text = '',
    this.publishedAt,
    this.myJoin = 'none',
    this.waitingRequests,
    this.iFollowOwner = false,
    this.mutuals = Mutuals.none,
    this.sample = false,
    this.notOpen = false,
    this.requestsFull = false,
    this.notifyNearby = false,
    this.nearbyNotifiedAt,
    this.notified,
    this.travelMode,
    this.members,
  });

  final String tripId;
  final SocialPerson owner;
  final List<String> ownerInterests;
  final bool isMine;
  final int cityKey;
  final List<String> cityNames;
  final String? stateName;
  final TripWhen when;
  final int days;
  final String joinGender;
  final int seats;
  final int seatsLeft;
  final String text;
  final DateTime? publishedAt;
  final String myJoin;
  final int? waitingRequests;
  final bool iFollowOwner;
  final Mutuals mutuals;
  final bool sample;
  final bool notOpen;
  final bool requestsFull;
  final bool notifyNearby;
  final DateTime? nearbyNotifiedAt;
  final String? travelMode;

  /// Own post only: other travellers who joined (owner not counted); null on others' posts.
  final int? members;

  /// Own post only: true = followers were told or the nearby push is queued; null = the server did not say.
  final bool? notified;

  /// Pending join requests one post takes before it shows Full (server PendingRequestsMax).
  static const int requestsCap = 50;

  bool get removedByHost => myJoin == 'removed';

  /// Others see Full when every seat is taken or the post holds the most pending requests.
  bool get fullForOthers => !isMine && (seatsLeft <= 0 || requestsFull);

  bool get nearbyPending => isMine && notifyNearby && nearbyNotifiedAt == null;

  PublicTrip copyWith({String? myJoin, bool? iFollowOwner, int? seatsLeft, int? waitingRequests, bool? requestsFull}) => PublicTrip(
        tripId: tripId,
        owner: owner,
        ownerInterests: ownerInterests,
        isMine: isMine,
        cityKey: cityKey,
        cityNames: cityNames,
        stateName: stateName,
        when: when,
        days: days,
        joinGender: joinGender,
        seats: seats,
        seatsLeft: seatsLeft ?? this.seatsLeft,
        text: text,
        publishedAt: publishedAt,
        myJoin: myJoin ?? this.myJoin,
        waitingRequests: waitingRequests ?? this.waitingRequests,
        iFollowOwner: iFollowOwner ?? this.iFollowOwner,
        mutuals: mutuals,
        sample: sample,
        notOpen: notOpen,
        requestsFull: requestsFull ?? this.requestsFull,
        notifyNearby: notifyNearby,
        nearbyNotifiedAt: nearbyNotifiedAt,
        notified: notified,
        travelMode: travelMode,
        members: members,
      );

  factory PublicTrip.fromJson(Map<String, dynamic> j) => PublicTrip(
        tripId: BuddyJson.str(j['tripId']),
        owner: SocialPerson.fromJson(BuddyJson.map(j['owner'])),
        ownerInterests: BuddyJson.strings(j['ownerInterests']),
        isMine: BuddyJson.boolean(j['isMine']),
        cityKey: BuddyJson.integer(j['cityKey']),
        cityNames: BuddyJson.strings(j['cityNames']),
        stateName: BuddyJson.strOrNull(j['stateName']),
        when: TripWhen.fromJson(BuddyJson.mapOrNull(j['when'])),
        days: BuddyJson.integer(j['days']),
        joinGender: BuddyJson.str(j['joinGender'], 'A'),
        seats: BuddyJson.integer(j['seats']),
        seatsLeft: BuddyJson.integer(j['seatsLeft']),
        text: BuddyJson.str(j['text']),
        publishedAt: BuddyJson.time(j['publishedAt']),
        myJoin: BuddyJson.str(j['myJoin'], 'none'),
        waitingRequests: BuddyJson.intOrNull(j['waitingRequests']),
        iFollowOwner: BuddyJson.boolean(j['iFollowOwner']),
        mutuals: Mutuals.fromJson(BuddyJson.mapOrNull(j['mutuals'])),
        sample: BuddyJson.boolean(j['sample']),
        notOpen: BuddyJson.boolean(j['notOpen']),
        requestsFull: BuddyJson.boolean(j['requestsFull']),
        notifyNearby: BuddyJson.boolean(j['notifyNearby']) || PostNotifyResult.of(j['notify'])?.nearby == PostNotifyResult.queued,
        nearbyNotifiedAt: BuddyJson.time(j['nearbyNotifiedAt']),
        notified: PostNotifyResult.of(j['notify'])?.notified,
        travelMode: TravelModes.parse(j['travelMode']),
        members: BuddyJson.intOrNull(j['members']),
      );
}

/// The create / publish answer to the poster: what followers and nearby travellers are told (CONTRACT_SOCIAL post notify).
class PostNotifyResult {
  const PostNotifyResult({required this.followers, required this.nearby});

  static const String sent = 'sent';
  static const String queued = 'queued';

  final String followers;
  final String nearby;

  /// true = followers were told or the nearby push is queued; null = nothing to say (no followers, toggle off, edit).
  bool? get notified => followers == sent || nearby == queued ? true : null;

  static PostNotifyResult? of(Object? v) {
    final j = BuddyJson.mapOrNull(v);
    if (j == null) return null;
    return PostNotifyResult(
      followers: BuddyJson.str(j['followers'], 'none'),
      nearby: BuddyJson.str(j['nearby'], 'off'),
    );
  }
}

class LimitUse {
  const LimitUse({required this.limit, required this.used});

  final int limit;
  final int used;

  int get left => used >= limit ? 0 : limit - used;
  bool get reached => used >= limit;

  static const LimitUse none = LimitUse(limit: 0, used: 0);

  factory LimitUse.fromJson(Map<String, dynamic>? j, {int fallbackLimit = 0}) =>
      j == null ? LimitUse(limit: fallbackLimit, used: 0) : LimitUse(limit: BuddyJson.integer(j['limit'], fallbackLimit), used: BuddyJson.integer(j['used']));
}

class SocialLimits {
  const SocialLimits({
    required this.isPlus,
    required this.canUpgrade,
    this.resetsAt,
    required this.activeTrips,
    required this.publicTrips,
    required this.joinRequests,
    required this.newChats,
    required this.genderOnlyTrips,
    required this.nearMe,
    this.inactiveTrips = 0,
    this.pausedPosts = 0,
    this.groupChat = true,
    this.publishes = defaultPublishes,
    this.publishNextAt,
  });

  static const LimitUse defaultPublishes = LimitUse(limit: 4, used: 0);

  final bool isPlus;
  final bool canUpgrade;
  final DateTime? resetsAt;
  final LimitUse activeTrips;
  final LimitUse publicTrips;
  final LimitUse joinRequests;
  final LimitUse newChats;
  final bool genderOnlyTrips;
  final bool nearMe;
  final int inactiveTrips;
  final int pausedPosts;

  /// Sending in a trip group chat. Missing = allowed: the server enforces.
  final bool groupChat;

  /// Publishes (first or again) in the rolling 7 days, every plan; deleting never gives one back.
  final LimitUse publishes;
  final DateTime? publishNextAt;

  /// The Plus hint on post entries: the live public post cap is reached and Plus would lift it.
  bool get postNeedsPlus => publicTrips.reached && !isPlus && canUpgrade;

  int get pausedTotal => inactiveTrips + pausedPosts;

  static const SocialLimits free = SocialLimits(
    isPlus: false,
    canUpgrade: false,
    activeTrips: LimitUse(limit: 1, used: 0),
    publicTrips: LimitUse(limit: 1, used: 0),
    joinRequests: LimitUse(limit: 1, used: 0),
    newChats: LimitUse(limit: 3, used: 0),
    genderOnlyTrips: false,
    nearMe: false,
  );

  factory SocialLimits.fromJson(Map<String, dynamic>? j) {
    if (j == null) return free;
    return SocialLimits(
      isPlus: BuddyJson.boolean(j['isPlus']),
      canUpgrade: BuddyJson.boolean(j['canUpgrade']),
      resetsAt: BuddyJson.time(j['resetsAt']),
      activeTrips: LimitUse.fromJson(BuddyJson.mapOrNull(j['activeTrips']), fallbackLimit: free.activeTrips.limit),
      publicTrips: LimitUse.fromJson(BuddyJson.mapOrNull(j['publicTrips']), fallbackLimit: free.publicTrips.limit),
      joinRequests: LimitUse.fromJson(BuddyJson.mapOrNull(j['joinRequests']), fallbackLimit: free.joinRequests.limit),
      newChats: LimitUse.fromJson(BuddyJson.mapOrNull(j['newChats']), fallbackLimit: free.newChats.limit),
      genderOnlyTrips: BuddyJson.boolean(j['genderOnlyTrips']),
      nearMe: BuddyJson.boolean(j['nearMe']),
      inactiveTrips: BuddyJson.integer(j['inactiveTrips']),
      pausedPosts: BuddyJson.integer(j['pausedPosts']),
      groupChat: BuddyJson.boolean(j['groupChat'], true),
      publishes: LimitUse.fromJson(BuddyJson.mapOrNull(j['publishes']), fallbackLimit: defaultPublishes.limit),
      publishNextAt: BuddyJson.time(j['publishNextAt']),
    );
  }
}

class ChatUnread {
  const ChatUnread({required this.people, required this.trips, required this.requests, required this.total});

  final int people;
  final int trips;
  final int requests;
  final int total;

  static const ChatUnread zero = ChatUnread(people: 0, trips: 0, requests: 0, total: 0);

  factory ChatUnread.fromJson(Map<String, dynamic>? j) {
    if (j == null) return zero;
    return ChatUnread(
      people: BuddyJson.integer(j['people']),
      trips: BuddyJson.integer(j['trips']),
      requests: BuddyJson.integer(j['requests']),
      total: BuddyJson.integer(j['total']),
    );
  }
}

class SocialCatalogData {
  const SocialCatalogData({this.interests = const [], this.skills = const [], this.aboutExamples = const [], this.postChips = const []});

  final List<String> interests;
  final List<String> skills;
  final List<String> aboutExamples;
  final List<String> postChips;

  static const SocialCatalogData empty = SocialCatalogData();

  factory SocialCatalogData.fromJson(Map<String, dynamic>? j) {
    if (j == null) return empty;
    return SocialCatalogData(
      interests: BuddyJson.strings(j['interests']),
      skills: BuddyJson.strings(j['skills']),
      aboutExamples: BuddyJson.strings(j['aboutExamples']),
      postChips: BuddyJson.strings(j['postChips']),
    );
  }
}

class MyProfile {
  const MyProfile({
    required this.userId,
    required this.name,
    this.username,
    this.photoUrl,
    required this.initial,
    required this.gender,
    required this.birthMonth,
    required this.birthYear,
    this.homeCity,
    this.homeState,
    this.about = '',
    this.interests = const [],
    this.skills = const [],
    this.places = const [],
    this.isPrivate = false,
    this.messagePolicy = 'Everyone',
    this.notifyMessages = true,
    this.notifyFollows = true,
    this.notifyFollowedTrips = true,
    this.notifyNearbyTrips = true,
    this.trips = 0,
    this.followers = 0,
    this.following = 0,
    this.buddies = 0,
    this.publicTrips = const [],
    this.nameChangeAllowedAt,
    this.completedTrips = 0,
    this.level = 0,
  });

  final String userId;
  final String name;
  final String? username;
  final String? photoUrl;
  final String initial;
  final String gender;
  final int birthMonth;
  final int birthYear;
  final String? homeCity;
  final String? homeState;
  final String about;
  final List<String> interests;
  final List<String> skills;
  final List<String> places;
  final bool isPrivate;
  final String messagePolicy;
  final bool notifyMessages;
  final bool notifyFollows;
  final bool notifyFollowedTrips;
  final bool notifyNearbyTrips;
  final int trips;
  final int followers;
  final int following;
  final int buddies;
  final List<PublicTrip> publicTrips;
  final DateTime? nameChangeAllowedAt;
  final int completedTrips;
  final int level;

  TravelLevel get travelLevel => TravelLevels.at(level);

  SocialPerson get person =>
      SocialPerson(userId: userId, name: name, username: username, photoUrl: photoUrl, initial: initial, homeCity: homeCity, completedTrips: completedTrips, level: level);

  bool nameLockedAt(DateTime now) {
    final at = nameChangeAllowedAt;
    return at != null && at.isAfter(now.toUtc());
  }

  MyProfile withNameChangeAllowedAt(DateTime? at) => MyProfile(
        userId: userId,
        name: name,
        username: username,
        photoUrl: photoUrl,
        initial: initial,
        gender: gender,
        birthMonth: birthMonth,
        birthYear: birthYear,
        homeCity: homeCity,
        homeState: homeState,
        about: about,
        interests: interests,
        skills: skills,
        places: places,
        isPrivate: isPrivate,
        messagePolicy: messagePolicy,
        notifyMessages: notifyMessages,
        notifyFollows: notifyFollows,
        notifyFollowedTrips: notifyFollowedTrips,
        notifyNearbyTrips: notifyNearbyTrips,
        trips: trips,
        followers: followers,
        following: following,
        buddies: buddies,
        publicTrips: publicTrips,
        nameChangeAllowedAt: at,
        completedTrips: completedTrips,
        level: level,
      );

  factory MyProfile.fromJson(Map<String, dynamic> j) {
    final c = BuddyJson.map(j['counters']);
    final p = SocialPerson.fromJson(j);
    final done = BuddyJson.integer(j['completedTrips'] ?? c['completedTrips']);
    return MyProfile(
      userId: p.userId,
      name: p.name,
      username: p.username,
      photoUrl: p.photoUrl,
      initial: p.initial,
      gender: BuddyJson.str(j['gender']),
      birthMonth: BuddyJson.integer(j['birthMonth']),
      birthYear: BuddyJson.integer(j['birthYear']),
      homeCity: BuddyJson.strOrNull(j['homeCity']),
      homeState: BuddyJson.strOrNull(j['homeState']),
      about: BuddyJson.str(j['about']),
      interests: BuddyJson.strings(j['interests']),
      skills: BuddyJson.strings(j['skills']),
      places: BuddyJson.strings(j['places']),
      isPrivate: BuddyJson.boolean(j['isPrivate']),
      messagePolicy: BuddyJson.str(j['messagePolicy'], 'Everyone'),
      notifyMessages: BuddyJson.boolean(j['notifyMessages'], true),
      notifyFollows: BuddyJson.boolean(j['notifyFollows'], true),
      notifyFollowedTrips: BuddyJson.boolean(j['notifyFollowedTrips'], true),
      notifyNearbyTrips: BuddyJson.boolean(j['notifyNearbyTrips'], true),
      trips: BuddyJson.integer(c['trips']),
      followers: BuddyJson.integer(c['followers']),
      following: BuddyJson.integer(c['following']),
      buddies: BuddyJson.integer(c['buddies']),
      publicTrips: BuddyJson.list(j['publicTrips'], PublicTrip.fromJson),
      nameChangeAllowedAt: BuddyJson.time(j['nameChangeAllowedAt'] ?? j['nextAllowedAt']),
      completedTrips: done,
      level: TravelLevels.parseLevel(j['level'] ?? c['level'], done),
    );
  }
}

class TravellerProfile {
  const TravellerProfile({
    required this.person,
    this.gender = '',
    this.about = '',
    this.interests = const [],
    this.skills = const [],
    this.places = const [],
    this.trips = 0,
    this.followers = 0,
    this.following = 0,
    this.iFollow = false,
    this.followRequested = false,
    this.followsMe = false,
    this.isBuddy = false,
    this.canAddBuddy = false,
    this.canMessage = false,
    this.mutuals = Mutuals.none,
    this.privateLocked = false,
    this.publicTrips = const [],
    this.completedTrips = 0,
    this.level = 0,
  });

  final SocialPerson person;
  final String gender;
  final String about;
  final List<String> interests;
  final List<String> skills;
  final List<String> places;
  final int trips;
  final int followers;
  final int following;
  final bool iFollow;
  final bool followRequested;
  final bool followsMe;
  final bool isBuddy;
  final bool canAddBuddy;
  final bool canMessage;
  final Mutuals mutuals;
  final bool privateLocked;
  final List<PublicTrip> publicTrips;
  final int completedTrips;
  final int level;

  TravelLevel get travelLevel => TravelLevels.at(level);

  TravellerProfile copyWith({bool? iFollow, bool? followRequested, bool? isBuddy, int? followers}) => TravellerProfile(
        person: person,
        gender: gender,
        about: about,
        interests: interests,
        skills: skills,
        places: places,
        trips: trips,
        followers: followers ?? this.followers,
        following: following,
        iFollow: iFollow ?? this.iFollow,
        followRequested: followRequested ?? this.followRequested,
        followsMe: followsMe,
        isBuddy: isBuddy ?? this.isBuddy,
        canAddBuddy: followsMe && !(isBuddy ?? this.isBuddy),
        canMessage: canMessage,
        mutuals: mutuals,
        privateLocked: privateLocked,
        publicTrips: publicTrips,
        completedTrips: completedTrips,
        level: level,
      );

  factory TravellerProfile.fromJson(Map<String, dynamic> j) {
    final c = BuddyJson.map(j['counters']);
    final r = BuddyJson.map(j['relation']);
    final pj = BuddyJson.map(j['person']);
    final done = BuddyJson.integer(j['completedTrips'] ?? pj['completedTrips'] ?? c['completedTrips']);
    final level = TravelLevels.parseLevel(j['level'] ?? pj['level'] ?? c['level'], done);
    final p = SocialPerson.fromJson(pj);
    return TravellerProfile(
      person: SocialPerson(
          userId: p.userId, name: p.name, username: p.username, photoUrl: p.photoUrl, initial: p.initial, homeCity: p.homeCity, gender: p.gender, completedTrips: done, level: level),
      gender: BuddyJson.str(j['gender']),
      about: BuddyJson.str(j['about']),
      interests: BuddyJson.strings(j['interests']),
      skills: BuddyJson.strings(j['skills']),
      places: BuddyJson.strings(j['places']),
      trips: BuddyJson.integer(c['trips']),
      followers: BuddyJson.integer(c['followers']),
      following: BuddyJson.integer(c['following']),
      iFollow: BuddyJson.boolean(r['iFollow']),
      followRequested: BuddyJson.boolean(r['followRequested']),
      followsMe: BuddyJson.boolean(r['followsMe']),
      isBuddy: BuddyJson.boolean(r['isBuddy']),
      canAddBuddy: BuddyJson.boolean(r['canAddBuddy']),
      canMessage: BuddyJson.boolean(r['canMessage']),
      mutuals: Mutuals.fromJson(BuddyJson.mapOrNull(j['mutuals'])),
      privateLocked: BuddyJson.boolean(j['privateLocked']),
      publicTrips: BuddyJson.list(j['publicTrips'], PublicTrip.fromJson),
      completedTrips: done,
      level: level,
    );
  }
}

class SocialMe {
  const SocialMe({
    this.profile,
    required this.limits,
    this.followRequests = 0,
    this.chatUnread = ChatUnread.zero,
    this.catalog = SocialCatalogData.empty,
    this.guidelinesAccepted,
    this.tripInvites = 0,
    this.joinRequests = 0,
  });

  final MyProfile? profile;
  final SocialLimits limits;
  final int followRequests;
  final ChatUnread chatUnread;
  final SocialCatalogData catalog;
  final int tripInvites;
  final int joinRequests;

  /// null = the server did not say (older answer): never block on it, the server enforces.
  final bool? guidelinesAccepted;

  SocialMe copyWith({MyProfile? profile, ChatUnread? chatUnread, int? followRequests, bool? guidelinesAccepted}) => SocialMe(
        profile: profile ?? this.profile,
        limits: limits,
        followRequests: followRequests ?? this.followRequests,
        chatUnread: chatUnread ?? this.chatUnread,
        catalog: catalog,
        guidelinesAccepted: guidelinesAccepted ?? this.guidelinesAccepted,
        tripInvites: tripInvites,
        joinRequests: joinRequests,
      );

  factory SocialMe.fromJson(Map<String, dynamic> j) {
    final counts = BuddyJson.map(j['counts']);
    final p = BuddyJson.mapOrNull(j['profile']);
    return SocialMe(
      profile: p == null ? null : MyProfile.fromJson(p),
      limits: SocialLimits.fromJson(BuddyJson.mapOrNull(j['limits'])),
      followRequests: BuddyJson.integer(counts['followRequests']),
      chatUnread: ChatUnread.fromJson(BuddyJson.mapOrNull(counts['chatUnread'])),
      catalog: SocialCatalogData.fromJson(BuddyJson.mapOrNull(j['catalog'])),
      tripInvites: BuddyJson.integer(counts['tripInvites']),
      joinRequests: BuddyJson.integer(counts['joinRequests']),
      guidelinesAccepted: j['guidelinesAccepted'] is bool ? j['guidelinesAccepted'] as bool : (p != null && p['guidelinesAccepted'] is bool ? p['guidelinesAccepted'] as bool : null),
    );
  }
}

abstract final class DiscoverReasonKinds {
  static const String sameTrip = 'sameTrip';
  static const String travelledWith = 'travelledWith';
  static const String followsYou = 'followsYou';
  static const String mutual = 'mutual';
  static const String near = 'near';
  static const String interests = 'interests';
  static const String places = 'places';
}

abstract final class DiscoverChips {
  static const String forYou = 'forYou';
  static const String sameTrip = 'sameTrip';
  static const String near = 'near';
  static const String mutual = 'mutual';
  static const String interests = 'interests';

  static const List<String> all = [forYou, sameTrip, near, mutual, interests];
}

/// Why a traveller is suggested. Only the fields of its kind are set; month is yyyymm (never an exact date).
class DiscoverReason {
  const DiscoverReason({required this.kind, this.cityName, this.month, this.mutualName, this.mutualCount = 0, this.tags = const []});

  final String kind;
  final String? cityName;
  final int? month;
  final String? mutualName;
  final int mutualCount;
  final List<String> tags;

  static const DiscoverReason none = DiscoverReason(kind: '');

  factory DiscoverReason.fromJson(Map<String, dynamic>? j) {
    if (j == null) return none;
    return DiscoverReason(
      kind: BuddyJson.str(j['kind']),
      cityName: BuddyJson.strOrNull(j['cityName']),
      month: BuddyJson.intOrNull(j['month']),
      mutualName: BuddyJson.strOrNull(j['mutualName']),
      mutualCount: BuddyJson.integer(j['mutualCount']),
      tags: BuddyJson.strings(j['tags']),
    );
  }
}

class DiscoverPerson {
  const DiscoverPerson({
    required this.person,
    this.followsMe = false,
    this.iFollow = false,
    this.followRequested = false,
    this.isPrivate = false,
    this.reason = DiscoverReason.none,
  });

  final SocialPerson person;
  final bool followsMe;
  final bool iFollow;
  final bool followRequested;
  final bool isPrivate;
  final DiscoverReason reason;

  String get userId => person.userId;

  DiscoverPerson copyWith({bool? iFollow, bool? followRequested}) => DiscoverPerson(
        person: person,
        followsMe: followsMe,
        iFollow: iFollow ?? this.iFollow,
        followRequested: followRequested ?? this.followRequested,
        isPrivate: isPrivate,
        reason: reason,
      );

  factory DiscoverPerson.fromJson(Map<String, dynamic> j) => DiscoverPerson(
        person: SocialPerson.fromJson(j),
        followsMe: BuddyJson.boolean(j['followsMe']),
        iFollow: BuddyJson.boolean(j['iFollow']),
        followRequested: BuddyJson.boolean(j['followRequested']),
        isPrivate: BuddyJson.boolean(j['isPrivate']),
        reason: DiscoverReason.fromJson(BuddyJson.mapOrNull(j['reason'])),
      );
}

/// Header of the Same trip chip ("ALSO GOING TO MANALI · DEC"); month is yyyymm.
class DiscoverTrip {
  const DiscoverTrip({required this.cityName, required this.month});

  final String cityName;
  final int month;

  static DiscoverTrip? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    final city = BuddyJson.str(j['cityName']);
    return city.isEmpty ? null : DiscoverTrip(cityName: city, month: BuddyJson.integer(j['month']));
  }
}

/// A page may hold fewer items than asked while nextCursor is set: keep loading while hasMore.
class DiscoverPage {
  const DiscoverPage({required this.items, this.nextCursor, this.myTrip});

  final List<DiscoverPerson> items;
  final String? nextCursor;
  final DiscoverTrip? myTrip;

  static const DiscoverPage empty = DiscoverPage(items: []);

  bool get hasMore => nextCursor != null;

  factory DiscoverPage.fromJson(Map<String, dynamic> j) => DiscoverPage(
        items: BuddyJson.list(j['items'], DiscoverPerson.fromJson),
        nextCursor: BuddyJson.strOrNull(j['nextCursor']),
        myTrip: DiscoverTrip.fromJson(BuddyJson.mapOrNull(j['myTrip'])),
      );
}
