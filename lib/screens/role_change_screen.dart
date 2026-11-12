import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/replies_kit.dart';
import '../config/user_roles.dart';
import '../controllers/auth_controller.dart';
import '../models/role_model.dart';
import '../utils/app_date_format.dart';
import '../utils/app_toast.dart';
import '../widgets/role_option_card.dart';

class RoleChangeScreen extends StatefulWidget {
  const RoleChangeScreen({super.key});

  @override
  State<RoleChangeScreen> createState() => _RoleChangeScreenState();
}

class _RoleChangeScreenState extends State<RoleChangeScreen> with SingleTickerProviderStateMixin {
  final _auth = Get.find<AuthController>();
  late final AnimationController _bar = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
  late final Animation<double> _barAnim =
      CurvedAnimation(parent: _bar, curve: const Interval(0, 0.5, curve: Curves.fastOutSlowIn));
  bool _barStarted = false;
  List<RoleModel> _roles = const [];
  bool _loading = true;
  String? _targetKey;
  Worker? _lockWorker;
  bool _exited = false;

  @override
  void initState() {
    super.initState();
    if (_auth.roleChangeLocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _exitLocked());
      return;
    }
    _lockWorker = ever(_auth.user, (_) {
      if (_auth.roleChangeLocked) _exitLocked();
    });
    _auth.refreshProfile();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_barStarted) return;
    _barStarted = true;
    if (KitMotion.reduce(context)) {
      _bar.value = 1;
    } else {
      _bar.forward();
    }
  }

  @override
  void dispose() {
    _bar.dispose();
    _lockWorker?.dispose();
    super.dispose();
  }

  void _exitLocked() {
    if (_exited || !mounted) return;
    _exited = true;
    AppToast.info('Role is locked after approval');
    Get.back();
  }

  void _retry() {
    setState(() => _loading = true);
    _load();
  }

  Future<void> _load() async {
    final roles = [...await _auth.fetchRoles()]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    if (!mounted) return;
    setState(() {
      _roles = roles;
      _loading = false;
    });
  }

  Future<void> _send(String targetKey) async {
    if (_auth.roleChangeLocked) {
      _exitLocked();
      return;
    }
    final result = await _auth.requestRoleChange(targetKey);
    if (!mounted) return;
    if (result == RoleActionResult.success) {
      AppToast.success('Request sent');
      Get.back();
    } else if (result == RoleActionResult.unavailable) {
      _retry();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignColors.scaffold,
      body: Column(
        children: [
          TemplateTopBar(
            title: 'Change role',
            opacity: 1,
            onBack: () => Get.back(),
            animation: _barAnim,
            animationController: _bar,
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(KitMetrics.gutter, KitMetrics.sectionGap, KitMetrics.gutter, 16),
                child: Obx(() {
                  final currentKey = _auth.roleKey.value;
                  final u = _auth.user.value;
                  final isLoading = _auth.isLoading.value;
                  final pending = u?.hasPendingRoleRequest ?? false;
                  final rejected = u?.hasRejectedRoleRequest ?? false;
                  final blockedUntil = u?.roleRequestBlockedUntil;
                  final targets = _roles
                      .where((r) => r.key != currentKey)
                      .map((r) => r.key)
                      .toList();
                  final targetKey = targets.contains(_targetKey)
                      ? _targetKey
                      : targets.firstOrNull;
                  final deletionLine = RoleCapabilities.of(currentKey).deletionLine;
                  final cards = _roles.any((r) => r.key == currentKey)
                      ? _roles
                      : [
                          RoleModel(
                            key: currentKey,
                            name: RoleVisuals.displayName(currentKey),
                            description: 'Paused',
                            sortOrder: -1,
                          ),
                          ..._roles,
                        ];
                  final count = cards.length + 4;
                  var i = 0;
                  Widget item(Widget child) => StaggerItem(index: i++, child: child);

                  return StaggerHost(
                    key: ValueKey(_loading),
                    count: count,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        item(Text(
                          'Needs admin approval.',
                          textAlign: TextAlign.center,
                          style: TypeTokens.style(12, FontWeight.w500,
                              color: TypeTokens.secondary, height: 1.5, letterSpacing: 0.2),
                        )),
                        const SizedBox(height: 20),
                        Expanded(
                          child: SkeletonSwitcher(
                            loading: _loading,
                            skeleton: Column(
                              children: [
                                for (var k = 0; k < 3; k++) ...[
                                  HeroBanner.skeleton(),
                                  const SizedBox(height: KitMetrics.cardGap),
                                ],
                              ],
                            ),
                            child: _roles.isEmpty
                                ? RoleLoadError(onRetry: _retry)
                                : targetKey == null
                                    ? const StateCard(title: 'No other role available')
                                    : SingleChildScrollView(
                                        physics: const BouncingScrollPhysics(),
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            for (final role in cards) ...[
                                              item(RoleOptionCard(
                                                role: role,
                                                selected: role.key == targetKey,
                                                isCurrent: role.key == currentKey,
                                                onTap: role.key == currentKey
                                                    ? null
                                                    : () => setState(() => _targetKey = role.key),
                                              )),
                                              const SizedBox(height: KitMetrics.cardGap),
                                            ],
                                            if (deletionLine != null) ...[
                                              item(_StatusBox(
                                                title: deletionLine,
                                                message: '',
                                                titleColor: RepliesTone.bad,
                                                messageColor: DesignColors.textGrey,
                                                background: RepliesTone.badSurface,
                                                border: DesignColors.tint(RepliesTone.bad, Alpha.soft),
                                                titleSize: 12,
                                                titleWeight: FontWeight.w600,
                                              )),
                                              const SizedBox(height: KitMetrics.cardGap),
                                            ],
                                            if (pending)
                                              item(const _StatusBox(
                                                title: 'Request pending',
                                                message: 'Waiting for admin approval.',
                                                titleColor: DesignColors.primary,
                                                messageColor: DesignColors.textGrey,
                                                background: RepliesTone.accentSurface,
                                              ))
                                            else if (rejected)
                                              item(_StatusBox(
                                                title: 'Request rejected',
                                                message: u!.roleRequestReason ?? '',
                                                titleColor: RepliesTone.bad,
                                                messageColor: DesignColors.textGrey,
                                                background: RepliesTone.badSurface,
                                              )),
                                            if (!pending && blockedUntil != null) ...[
                                              if (rejected) const SizedBox(height: KitMetrics.cardGap),
                                              item(_StatusBox(
                                                title: 'Try again later',
                                                message: 'Next request after ${AppDateFormat.dateTime(blockedUntil)}',
                                                titleColor: DesignColors.warnDeep,
                                                messageColor: DesignColors.textGrey,
                                                background: RepliesTone.warnSurface,
                                              )),
                                            ],
                                          ],
                                        ),
                                      ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        PrimaryButton(
                          label: 'Send request',
                          loading: isLoading,
                          onPressed: _loading || targetKey == null || pending || blockedUntil != null
                              ? null
                              : () => _send(targetKey),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBox extends StatelessWidget {
  final String title;
  final String message;
  final Color titleColor;
  final Color messageColor;
  final Color background;
  final Color? border;
  final double titleSize;
  final FontWeight titleWeight;

  const _StatusBox({
    required this.title,
    required this.message,
    required this.titleColor,
    required this.messageColor,
    required this.background,
    this.border,
    this.titleSize = 14,
    this.titleWeight = FontWeight.w700,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: CardRadius.tile,
        border: border == null ? null : Border.all(color: border!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TypeTokens.style(titleSize, titleWeight, color: titleColor, letterSpacing: 0.2)),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(message, style: TypeTokens.style(12, FontWeight.w500, color: messageColor, height: 1.5)),
          ],
        ],
      ),
    );
  }
}
