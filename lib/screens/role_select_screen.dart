import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../config/user_roles.dart';
import '../controllers/auth_controller.dart';
import '../design/design.dart';
import '../controllers/location_controller.dart';
import '../models/role_model.dart';
import '../widgets/global_location_gates.dart';
import '../widgets/role_correction_dialog.dart';
import '../widgets/role_option_card.dart';

class RoleSelectScreen extends StatefulWidget {
  const RoleSelectScreen({super.key});

  @override
  State<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends State<RoleSelectScreen> {
  final _auth = Get.find<AuthController>();
  List<RoleModel> _roles = const [];
  bool _loading = true;
  String _selectedKey = UserRoleKeys.seeker;
  late final bool _correction;
  late final int _percent;

  @override
  void initState() {
    super.initState();
    // Pre-main page; permanent so MainScreen's later Get.put reuses this instance.
    if (!Get.isRegistered<LocationController>()) {
      Get.put(LocationController(), permanent: true);
      GlobalLocationGates.notifyReady();
    }
    final args = Get.arguments;
    _correction = args is Map && args['correction'] == true;
    _percent = args is Map && args['percent'] is int
        ? args['percent'] as int
        : 0;
    _load();
  }

  void _retry() {
    setState(() => _loading = true);
    _load();
  }

  Future<void> _choose() async {
    if (_correction) {
      final kind = _auth.roleKey.value == UserRoleKeys.taxiDriver
          ? 'Taxi'
          : 'Stay';
      final ok = await RoleCorrectionDialog.confirm(
        context,
        kind: kind,
        percent: _percent,
      );
      if (!ok || !mounted) return;
    }
    final result = _correction
        ? await _auth.correctRole(_selectedKey)
        : await _auth.chooseRole(_selectedKey);
    if (result == RoleActionResult.unavailable && mounted) _retry();
  }

  Future<void> _load() async {
    final roles = [...await _auth.fetchRoles()]
      ..removeWhere((r) => _correction && r.key == _auth.roleKey.value)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    if (!mounted) return;
    setState(() {
      _roles = roles;
      if (roles.isNotEmpty && !roles.any((r) => r.key == _selectedKey)) {
        _selectedKey =
            !_correction && roles.any((r) => r.key == UserRoleKeys.seeker)
            ? UserRoleKeys.seeker
            : roles.first.key;
      }
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final count = _roles.length + 4;
    Widget item(int i, Widget child) => StaggerItem(index: i, child: child);
    return PopScope(
      canPop: _correction,
      child: Scaffold(
        backgroundColor: DesignColors.scaffold,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(KitMetrics.gutter, 24, KitMetrics.gutter, 16),
            child: StaggerHost(
              key: ValueKey(_loading),
              count: count,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  item(
                    0,
                    Column(
                      children: [
                        if (_correction)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: PressScale(
                              child: IconButton(
                                onPressed: () => Get.back(),
                                icon: const Icon(
                                  Icons.arrow_back_ios_rounded,
                                  color: DesignColors.textStrong,
                                ),
                              ),
                            ),
                          )
                        else
                          const SizedBox(height: 6),
                        Container(
                          width: 84,
                          height: 84,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: DesignColors.surface,
                            shape: BoxShape.circle,
                            boxShadow: ShadowTokens.elev2,
                          ),
                          child: const TravelIcon(TravelIcon.luggage, size: 60),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  item(
                    1,
                    Text(
                      'Select your role',
                      textAlign: TextAlign.center,
                      style: TypeTokens.style(24, FontWeight.w700, color: DesignColors.textStrong, letterSpacing: 0.27),
                    ),
                  ),
                  const SizedBox(height: 8),
                  item(
                    2,
                    Text(
                      _correction ? 'One-time change.' : 'You can change it later.',
                      textAlign: TextAlign.center,
                      style: TypeTokens.style(14, FontWeight.w400, color: TypeTokens.secondary),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: SkeletonSwitcher(
                      loading: _loading,
                      skeleton: Column(
                        children: [
                          for (var i = 0; i < 3; i++) ...[
                            HeroBanner.skeleton(),
                            const SizedBox(height: KitMetrics.cardGap),
                          ],
                        ],
                      ),
                      child: _roles.isEmpty
                          ? RoleLoadError(onRetry: _retry)
                          : SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (var i = 0; i < _roles.length; i++) ...[
                                    item(
                                      3 + i,
                                      RoleOptionCard(
                                        role: _roles[i],
                                        selected: _roles[i].key == _selectedKey,
                                        onTap: () => setState(() => _selectedKey = _roles[i].key),
                                      ),
                                    ),
                                    const SizedBox(height: KitMetrics.cardGap),
                                  ],
                                ],
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  item(
                    count - 1,
                    Obx(() {
                      final busy = _auth.isLoading.value;
                      final disabled = _loading || _roles.isEmpty || busy;
                      return PrimaryButton(
                        label: 'Continue',
                        loading: busy,
                        onPressed: disabled ? null : _choose,
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
