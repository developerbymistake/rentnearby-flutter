import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_auth.dart';
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
    final tone = ListingTone.indigo;
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: AuthInk.page,
      body: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: pad.top + (MediaQuery.sizeOf(context).height < 820 ? 40 : 64)),
            FadeTransition(
              opacity: _barAnim,
              child: TopBar3D(tone: tone, title: 'Change role', onBack: () => Get.back()),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
              child: Text(
                'Needs admin approval.',
                textAlign: TextAlign.center,
                style: Ink3D.text(13, FontWeight.w600, Ink3D.sub, height: 1.5),
              ),
            ),
            Expanded(
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

                final Widget body;
                var strips = <Widget>[];
                if (_loading) {
                  body = const AuthEvenList(children: [AuthRoleSkeleton(), AuthRoleSkeleton(), AuthRoleSkeleton()]);
                } else if (_roles.isEmpty) {
                  body = Padding(padding: const EdgeInsets.only(bottom: 16), child: RoleLoadError(onRetry: _retry));
                } else if (targetKey == null) {
                  body = Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: AuthStateCard(tone: tone, art: ListingArt.backpack, title: 'No other role available'),
                  );
                } else {
                  body = AuthRoleDescLines(
                    descriptions: [for (final role in cards) role.description],
                    child: AuthEvenList(
                      children: [
                        for (final role in cards)
                          item(RoleOptionCard(
                            role: role,
                            selected: role.key == targetKey,
                            isCurrent: role.key == currentKey,
                            onTap: role.key == currentKey
                                ? null
                                : () => setState(() => _targetKey = role.key),
                          )),
                      ],
                    ),
                  );
                  strips = [
                    if (deletionLine != null)
                      item(AuthStatusStrip(kind: AuthStripKind.bad, art: ListingArt.clipboard, title: deletionLine)),
                    if (pending)
                      item(const AuthStatusStrip(
                        kind: AuthStripKind.pending,
                        art: ListingArt.calendar,
                        title: 'Request pending',
                        message: 'Waiting for admin approval.',
                      ))
                    else if (rejected)
                      item(AuthStatusStrip(
                        kind: AuthStripKind.bad,
                        art: ListingArt.clipboard,
                        title: 'Request rejected',
                        message: u!.roleRequestReason ?? '',
                      )),
                    if (!pending && blockedUntil != null)
                      item(AuthStatusStrip(
                        kind: AuthStripKind.later,
                        art: ListingArt.calendar,
                        title: 'Try again later',
                        message: 'Next request after ${AppDateFormat.dateTime(blockedUntil)}',
                      )),
                  ];
                }

                return StaggerHost(
                  key: ValueKey(_loading),
                  count: count,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: body),
                      if (strips.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            spacing: 8,
                            children: strips,
                          ),
                        ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(18, 0, 18, 22 + pad.bottom),
                        child: GradientPillButton(
                          tone: tone,
                          label: 'Send request',
                          loading: isLoading,
                          onTap: _loading || targetKey == null || pending || blockedUntil != null
                              ? null
                              : () => _send(targetKey),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
