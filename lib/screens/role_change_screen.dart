import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../config/app_colors.dart';
import '../config/user_roles.dart';
import '../controllers/auth_controller.dart';
import '../models/role_model.dart';
import '../utils/app_date_format.dart';
import '../utils/app_toast.dart';
import '../widgets/gradient_button.dart';
import '../widgets/role_option_card.dart';

class RoleChangeScreen extends StatefulWidget {
  const RoleChangeScreen({super.key});

  @override
  State<RoleChangeScreen> createState() => _RoleChangeScreenState();
}

class _RoleChangeScreenState extends State<RoleChangeScreen> {
  final _auth = Get.find<AuthController>();
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
  void dispose() {
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
    final roles = [...await _auth.fetchRoles()]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
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
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 18),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 4),
                    const Text('Change role',
                        style: TextStyle(
                            fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
                child: Obx(() {
                  final currentKey = _auth.roleKey.value;
                  final u = _auth.user.value;
                  final isLoading = _auth.isLoading.value;
                  final pending = u?.hasPendingRoleRequest ?? false;
                  final rejected = u?.hasRejectedRoleRequest ?? false;
                  final blockedUntil = u?.roleRequestBlockedUntil;
                  final targets = _roles.where((r) => r.key != currentKey).map((r) => r.key).toList();
                  final targetKey = targets.contains(_targetKey) ? _targetKey : targets.firstOrNull;
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

                  return Column(
                    children: [
                      const Text('Needs admin approval.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight, height: 1.5)),
                      const SizedBox(height: 20),
                      if (_loading)
                        const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
                      else if (_roles.isEmpty)
                        Expanded(child: RoleLoadError(onRetry: _retry))
                      else if (targetKey == null)
                        const Expanded(
                          child: Center(
                            child: Text('No other role available',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textMedium)),
                          ),
                        )
                      else
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              children: [
                                for (final role in cards) ...[
                                  RoleOptionCard(
                                    role: role,
                                    selected: role.key == targetKey,
                                    isCurrent: role.key == currentKey,
                                    onTap: role.key == currentKey ? null : () => setState(() => _targetKey = role.key),
                                  ),
                                  const SizedBox(height: 14),
                                ],
                                if (deletionLine != null) ...[
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.error.withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                                    ),
                                    child: Text(deletionLine,
                                        style: const TextStyle(
                                            fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.error)),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                if (pending)
                                  const _StatusBox(
                                    title: 'Request pending',
                                    message: 'Waiting for admin approval.',
                                    titleColor: AppColors.primary,
                                    messageColor: AppColors.textLight,
                                    background: AppColors.surface,
                                  )
                                else if (rejected)
                                  _StatusBox(
                                    title: 'Request rejected',
                                    message: u!.roleRequestReason ?? '',
                                    titleColor: AppColors.error,
                                    messageColor: AppColors.textMedium,
                                    background: AppColors.error.withValues(alpha: 0.06),
                                  ),
                                if (!pending && blockedUntil != null) ...[
                                  if (rejected) const SizedBox(height: 12),
                                  _StatusBox(
                                    title: 'Try again later',
                                    message: 'Next request after ${AppDateFormat.dateTime(blockedUntil)}',
                                    titleColor: AppColors.warning,
                                    messageColor: AppColors.textMedium,
                                    background: AppColors.surface,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      GradientButton(
                        label: 'Send request',
                        height: 50,
                        isLoading: isLoading,
                        onPressed: _loading || targetKey == null || pending || blockedUntil != null
                            ? null
                            : () => _send(targetKey),
                      ),
                    ],
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

  const _StatusBox({
    required this.title,
    required this.message,
    required this.titleColor,
    required this.messageColor,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: titleColor)),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(message, style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: messageColor, height: 1.5)),
          ],
        ],
      ),
    );
  }
}
