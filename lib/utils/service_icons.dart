import 'package:flutter/widgets.dart';
import 'package:iconsax/iconsax.dart';

/// Resolves an admin-entered `IconName` string column (ServiceSection,
/// ServiceCategory, Service, Inclusion) to an Iconsax glyph. Iconsax is the
/// only icon library this app depends on (explicit product decision — no
/// Phosphor/Lucide/Solar), so every entry here is a real `Iconsax.*`
/// constant, never a custom asset.
///
/// Covers every `IconName` currently seeded by `DataSeeder.SeedServiceXxx`
/// verbatim (see the comment block below), plus a generous set of other
/// common Iconsax names an admin is likely to type for a future category —
/// this is deliberately not an attempt to mirror all ~450 Iconsax glyphs.
/// Anything unmapped falls back to [Iconsax.category] rather than crashing
/// or rendering blank, so a typo'd/forgotten admin icon name degrades
/// gracefully instead of breaking the screen.
const Map<String, IconData> _kServiceIconMap = {
  // ── Seeded verbatim (ServiceSection/ServiceCategory/Service/Inclusion) ──
  'map': Iconsax.map_1,
  'briefcase': Iconsax.briefcase,
  'route_square': Iconsax.route_square,
  'heart': Iconsax.heart,
  'airplane': Iconsax.airplane,
  'car': Iconsax.car,
  'tree': Iconsax.tree,
  'camera': Iconsax.camera,
  'building': Iconsax.building,
  'gas_station': Iconsax.gas_station,
  'calendar': Iconsax.calendar,
  'shield_tick': Iconsax.shield_tick,
  'security_safe': Iconsax.security_safe,
  'activity': Iconsax.activity,
  'weight': Iconsax.weight,
  'chart': Iconsax.chart,
  'cup': Iconsax.cup,
  'profile_2user': Iconsax.profile_2user,
  'ticket': Iconsax.ticket,
  'health': Iconsax.health,
  'wifi': Iconsax.wifi,

  // ── Additional common glyphs, for categories an admin adds later ───────
  'home': Iconsax.home,
  'home_2': Iconsax.home_2,
  'location': Iconsax.location,
  'star': Iconsax.star,
  'star_1': Iconsax.star_1,
  'gift': Iconsax.gift,
  'shop': Iconsax.shop,
  'bag': Iconsax.bag,
  'bag_2': Iconsax.bag_2,
  'wallet': Iconsax.wallet,
  'wallet_money': Iconsax.wallet_money,
  'clock': Iconsax.clock,
  'calendar_1': Iconsax.calendar_1,
  'calendar_2': Iconsax.calendar_2,
  'message': Iconsax.message,
  'message_text': Iconsax.message_text,
  'call': Iconsax.call,
  'sms': Iconsax.sms,
  'notification': Iconsax.notification,
  'book': Iconsax.book,
  'book_1': Iconsax.book_1,
  'chart_2': Iconsax.chart_2,
  'chart_square': Iconsax.chart_square,
  'buildings': Iconsax.buildings,
  'buildings_2': Iconsax.buildings_2,
  'house': Iconsax.house,
  'house_2': Iconsax.house_2,
  'hospital': Iconsax.hospital,
  'security': Iconsax.security,
  'security_card': Iconsax.security_card,
  'shield': Iconsax.shield,
  'people': Iconsax.people,
  'profile_2user_1': Iconsax.profile_2user,
  'sun': Iconsax.sun_1,
  'moon': Iconsax.moon,
  'cloud': Iconsax.cloud,
  'drop': Iconsax.drop,
  'flag': Iconsax.flag,
  'crown': Iconsax.crown,
  'crown_1': Iconsax.crown_1,
  'medal_star': Iconsax.medal_star,
  'award': Iconsax.award,
  'gem': Iconsax.diamonds,
  'image': Iconsax.image,
  'gallery': Iconsax.gallery,
  'video': Iconsax.video,
  'video_play': Iconsax.video_play,
  'music': Iconsax.music,
  'ship': Iconsax.ship,
  'bus': Iconsax.bus,
  'truck': Iconsax.truck,
  'discount_shape': Iconsax.discount_shape,
  'like': Iconsax.like_1,
  'personalcard': Iconsax.personalcard,
  'document': Iconsax.document,
  'document_text': Iconsax.document_text,
  'global': Iconsax.global,
  'discover': Iconsax.discover,
  'mountain': Iconsax.gallery, // no direct "mountain" glyph in this icon set
  'first_aid_kit': Iconsax.health,
};

/// Icon fallback for an unmapped/blank `IconName`.
const IconData kServiceIconFallback = Iconsax.category;

IconData serviceIconFor(String? iconName) {
  if (iconName == null || iconName.trim().isEmpty) return kServiceIconFallback;
  return _kServiceIconMap[iconName.trim()] ?? kServiceIconFallback;
}
