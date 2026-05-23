import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:share_plus/share_plus.dart';
import '../config/app_colors.dart';
import '../controllers/auth_controller.dart';
import 'edit_profile_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = Get.find<AuthController>();

  String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return '';
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts[0][0].toUpperCase();
  }

  Future<void> _shareApp() async {
    await SharePlus.instance.share(
      ShareParams(
        text: '🏠 Bakhli — Find rooms near you!\n'
            'No brokers. No commission. Just homes.\n\n'
            'Download: https://google.com',
        subject: 'Check out Bakhli!',
      ),
    );
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
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 30, 60, 34),
                      child: Row(
                        children: [
                          Obx(() {
                            final initials = _initials(_auth.user.value?.name);
                            return Container(
                              width: 80, height: 80,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.6), width: 2),
                              ),
                              child: Center(
                                child: initials.isNotEmpty
                                    ? Text(initials,
                                        style: const TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 30,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white))
                                    : const Icon(Iconsax.user5, size: 38, color: Colors.white),
                              ),
                            );
                          }),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Obx(() => Text(
                                  _auth.user.value?.name?.trim().isNotEmpty == true
                                      ? _auth.user.value!.name!.trim()
                                      : 'Your Profile',
                                  style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )),
                                const SizedBox(height: 4),
                                Obx(() => Text(
                                  '+91 ${_auth.user.value?.phoneNumber ?? ''}',
                                  style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 15,
                                      color: Colors.white70),
                                )),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 8, right: 8,
                      child: IconButton(
                        onPressed: _shareApp,
                        icon: const Icon(Icons.share_rounded,
                            color: Colors.white, size: 22),
                        tooltip: 'Share App',
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Settings tiles
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.shadow,
                        blurRadius: 12,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: Column(children: [
                  _tile(
                    icon: Iconsax.user_edit,
                    label: 'Update Profile',
                    onTap: () => Get.to(
                      () => const EditProfileScreen(),
                      transition: Transition.rightToLeft,
                      duration: const Duration(milliseconds: 300),
                    ),
                  ),
                  Divider(height: 1, indent: 56, color: AppColors.divider),
                  _tile(
                    icon: Iconsax.shield_tick,
                    label: 'Privacy Policy',
                    onTap: () => Get.to(
                      () => const PrivacyPolicyScreen(),
                      transition: Transition.rightToLeft,
                      duration: const Duration(milliseconds: 300),
                    ),
                  ),
                  Divider(height: 1, indent: 56, color: AppColors.divider),
                  _tile(
                    icon: Iconsax.document_text,
                    label: 'Terms of Service',
                    onTap: () => Get.to(
                      () => const TermsOfServiceScreen(),
                      transition: Transition.rightToLeft,
                      duration: const Duration(milliseconds: 300),
                    ),
                  ),
                ]),
              ),
            ),

            const SizedBox(height: 12),

            // Logout
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: OutlinedButton.icon(
                onPressed: _confirmLogout,
                icon: const Icon(Iconsax.logout, color: AppColors.error, size: 20),
                label: const Text('Logout',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        color: AppColors.error,
                        fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  side: const BorderSide(color: AppColors.error, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Delete Account
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Obx(() => TextButton(
                onPressed:
                    _auth.isLoading.value ? null : _confirmDeleteAccount,
                child: const Text(
                  'Delete Account',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: AppColors.textLight,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.textLight,
                  ),
                ),
              )),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('Made with ',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: AppColors.textLight)),
                const Icon(Icons.favorite_rounded,
                    color: Color(0xFFE53935), size: 14),
                const Text(' by ',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: AppColors.textLight)),
                const Text('Dev',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryLight)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String label,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primaryLight, size: 18),
      ),
      title: Text(label,
          style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textDark)),
      subtitle: subtitle != null
          ? Text(subtitle,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: AppColors.textLight))
          : null,
      trailing: const Icon(Icons.arrow_forward_ios_rounded,
          size: 14, color: AppColors.textLight),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 36),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Iconsax.logout, size: 28, color: AppColors.error),
            ),
            const SizedBox(height: 16),
            const Text('Logout?',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark)),
            const SizedBox(height: 8),
            const Text('Are you sure you want to logout?',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: AppColors.textMedium,
                    height: 1.5),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textMedium,
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancel',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _auth.logout();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Logout',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  void _confirmDeleteAccount() {
    final confirmCtrl = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => StatefulBuilder(builder: (ctx, setDialogState) {
        final canDelete = confirmCtrl.text.trim() == 'DELETE';
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delete_forever_rounded,
                        size: 30, color: AppColors.error),
                  ),
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text('Delete Account',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark)),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.2)),
                  ),
                  child: const Text(
                    'This will permanently delete your account, all listings, plots, photos and memberships. This action cannot be undone.',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: AppColors.error,
                        height: 1.55),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Type DELETE to confirm',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMedium)),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmCtrl,
                  autofocus: true,
                  onChanged: (_) => setDialogState(() {}),
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2),
                  decoration: InputDecoration(
                    hintText: 'DELETE',
                    hintStyle: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        letterSpacing: 2,
                        color: Colors.grey.shade400),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: AppColors.error, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textMedium,
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: canDelete
                          ? () {
                              Navigator.pop(ctx);
                              _doDeleteAccount();
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        disabledBackgroundColor:
                            AppColors.error.withValues(alpha: 0.35),
                        foregroundColor: Colors.white,
                        disabledForegroundColor: Colors.white70,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Delete Account',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        );
      }),
    ).whenComplete(() => confirmCtrl.dispose());
  }

  Future<void> _doDeleteAccount() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (_) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                width: 48, height: 48,
                child: CircularProgressIndicator(
                    strokeWidth: 3, color: AppColors.error),
              ),
              const SizedBox(height: 20),
              const Text('Deleting your account...',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark)),
              const SizedBox(height: 6),
              const Text('Please do not close the app.',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: AppColors.textLight)),
            ]),
          ),
        ),
      ),
    );

    await _auth.deleteAccount();

    if (mounted && Navigator.canPop(context)) Navigator.pop(context);
  }
}
