import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../config/app_colors.dart';
import '../config/user_roles.dart';
import '../controllers/auth_controller.dart';
import '../models/role_model.dart';
import '../widgets/gradient_button.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
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
      if (roles.isNotEmpty && !roles.any((r) => r.key == _selectedKey)) _selectedKey = roles.first.key;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 44, 22, 16),
            child: Column(
              children: [
                const SizedBox(height: 6),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Iconsax.home_2, color: Colors.white, size: 26),
                ),
                const SizedBox(height: 14),
                const Text('Select your role',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: 'Poppins', fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                const SizedBox(height: 6),
                const Text('You can change it later.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight, height: 1.5)),
                const SizedBox(height: 20),
                if (_loading)
                  const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
                else if (_roles.isEmpty)
                  Expanded(child: RoleLoadError(onRetry: _retry))
                else
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          for (final role in _roles) ...[
                            RoleOptionCard(
                              role: role,
                              selected: role.key == _selectedKey,
                              onTap: () => setState(() => _selectedKey = role.key),
                            ),
                            const SizedBox(height: 14),
                          ],
                        ],
                      ),
                    ),
                  ),
                Obx(() => GradientButton(
                      label: 'Continue',
                      height: 50,
                      isLoading: _auth.isLoading.value,
                      onPressed: _loading || _roles.isEmpty ? null : () => _auth.chooseRole(_selectedKey),
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
