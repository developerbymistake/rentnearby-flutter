import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../config/user_roles.dart';
import '../controllers/auth_controller.dart';
import '../design/design.dart';
import '../design/extra/ext_auth.dart';
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
    final count = _roles.length + 2;
    Widget item(int i, Widget child) => StaggerItem(index: i, child: child);
    final tone = ListingTone.indigo;
    final pad = MediaQuery.paddingOf(context);
    return PopScope(
      canPop: _correction,
      child: Scaffold(
        backgroundColor: AuthInk.page,
        body: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: StaggerHost(
            key: ValueKey(_loading),
            count: count,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: pad.top + (MediaQuery.sizeOf(context).height < 820 ? 40 : 64)),
                item(
                  0,
                  AuthRoleHeader(
                    tone: tone,
                    art: ListingArt.luggage,
                    title: 'Select your role',
                    subtitle: _correction ? 'One-time change.' : 'You can change it later.',
                    onBack: _correction ? () => Get.back() : null,
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const AuthEvenList(children: [AuthRoleSkeleton(), AuthRoleSkeleton(), AuthRoleSkeleton()])
                      : _roles.isEmpty
                          ? Padding(padding: const EdgeInsets.only(bottom: 16), child: RoleLoadError(onRetry: _retry))
                          : AuthEvenList(
                              children: [
                                for (var i = 0; i < _roles.length; i++)
                                  item(
                                    1 + i,
                                    RoleOptionCard(
                                      role: _roles[i],
                                      selected: _roles[i].key == _selectedKey,
                                      onTap: () => setState(() => _selectedKey = _roles[i].key),
                                    ),
                                  ),
                              ],
                            ),
                ),
                item(
                  count - 1,
                  Padding(
                    padding: EdgeInsets.fromLTRB(18, 0, 18, 22 + pad.bottom),
                    child: Obx(() {
                      final busy = _auth.isLoading.value;
                      final disabled = _loading || _roles.isEmpty || busy;
                      return GradientPillButton(
                        tone: tone,
                        label: 'Continue',
                        loading: busy,
                        onTap: disabled ? null : _choose,
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
