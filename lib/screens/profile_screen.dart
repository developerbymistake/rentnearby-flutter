import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:animate_do/animate_do.dart';
import 'package:iconsax/iconsax.dart';
import '../config/app_colors.dart';
import '../controllers/auth_controller.dart';
import '../widgets/gradient_button.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = Get.find<AuthController>();
  final _nameCtrl = TextEditingController();
  final _gmailCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = _auth.user.value?.name ?? '';
    _gmailCtrl.text = _auth.user.value?.gmailId ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _gmailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            Container(
              decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                  child: Column(children: [
                    Row(children: [
                      const Text('Profile', style: TextStyle(fontFamily: 'Poppins', fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
                      const Spacer(),
                      Obx(() => _auth.user.value?.isAdmin == true
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(20)),
                              child: const Text('Admin', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                            )
                          : const SizedBox()),
                    ]),
                    const SizedBox(height: 24),
                    // Avatar
                    FadeInDown(
                      child: Container(
                        width: 82, height: 82,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                        ),
                        child: const Icon(Iconsax.user5, size: 40, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Obx(() => Text(
                      _auth.user.value?.displayName ?? '',
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                    )),
                    Obx(() => Text(
                      '+91 ${_auth.user.value?.phoneNumber ?? ''}',
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.white70),
                    )),
                  ]),
                ),
              ),
            ),

            // Form card
            FadeInUp(
              delay: const Duration(milliseconds: 200),
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 20, offset: const Offset(0, 6))],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Edit Profile', style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                  const SizedBox(height: 20),
                  _buildField('Full Name', Iconsax.user, _nameCtrl),
                  const SizedBox(height: 16),
                  _buildField('Gmail ID', Iconsax.sms, _gmailCtrl, keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 24),
                  Obx(() => GradientButton(
                    onPressed: _auth.isLoading.value ? null : _save,
                    isLoading: _auth.isLoading.value,
                    label: 'Save Profile',
                  )),
                ]),
              ),
            ),

            // Logout
            FadeInUp(
              delay: const Duration(milliseconds: 300),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: OutlinedButton.icon(
                  onPressed: _confirmLogout,
                  icon: const Icon(Iconsax.logout, color: AppColors.error, size: 20),
                  label: const Text('Logout', style: TextStyle(fontFamily: 'Poppins', color: AppColors.error, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    side: const BorderSide(color: AppColors.error, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, IconData icon, TextEditingController ctrl, {TextInputType? keyboardType}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textMedium)),
      const SizedBox(height: 8),
      TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        style: const TextStyle(fontFamily: 'Poppins', fontSize: 15),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: AppColors.primaryLight, size: 20),
          hintText: 'Enter $label',
        ),
      ),
    ]);
  }

  void _save() => _auth.updateProfile(
    _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : null,
    _gmailCtrl.text.trim().isNotEmpty ? _gmailCtrl.text.trim() : null,
  );

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
        content: const Text('Are you sure you want to logout?', style: TextStyle(fontFamily: 'Poppins')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins', color: AppColors.textLight))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white, minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
            onPressed: () { Navigator.pop(context); _auth.logout(); },
            child: const Text('Logout', style: TextStyle(fontFamily: 'Poppins')),
          ),
        ],
      ),
    );
  }
}
