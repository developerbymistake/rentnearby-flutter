import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_colors.dart';
import '../config/app_insets.dart';
import '../config/app_routes.dart';
import '../controllers/auth_controller.dart';
import '../utils/app_toast.dart';
import '../widgets/gradient_button.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = Get.find<AuthController>();
  final _nameCtrl = TextEditingController();
  final _isContactVisible = true.obs;
  Worker? _profileTabWorker;

  @override
  void initState() {
    super.initState();
    _resetForm();
    _profileTabWorker = ever(_auth.profileTabTrigger, (_) => _resetForm());
  }

  void _resetForm() {
    _nameCtrl.text = _auth.user.value?.name ?? '';
    _isContactVisible.value = _auth.user.value?.isContactVisible ?? true;
  }

  @override
  void dispose() {
    _profileTabWorker?.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return '';
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts[0][0].toUpperCase();
  }

  Future<void> _shareApp() async {
    await SharePlus.instance.share(
      ShareParams(
        text: 'Bakhli से किराए का घर ढूंढो — बिना दलाल, बिना कमीशन। 🏠\n'
            'https://play.google.com/store/apps/details?id=com.rentnearby.rentnearby',
        subject: 'Bakhli — किराए का घर ढूंढो आसानी से!',
      ),
    );
  }

  Future<void> _rateApp() async {
    final uri = Uri.parse('market://details?id=com.rentnearby.rentnearby');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await launchUrl(
        Uri.parse('https://play.google.com/store/apps/details?id=com.rentnearby.rentnearby'),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      AppToast.error('Name is required.');
      return;
    }
    if (name.length > 100) {
      AppToast.error('Name cannot exceed 100 characters.');
      return;
    }
    final ok = await _auth.updateProfile(name, isContactVisible: _isContactVisible.value);
    if (ok && mounted) AppToast.success('Profile updated');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Outer MainScreen Scaffold already handles keyboard avoidance.
      // Setting this to false prevents the double-resize glitch.
      resizeToAvoidBottomInset: false,
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          children: [
            // Header
            Container(
              decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 30, 20, 34),
                  child: Obx(() {
                    final name = _auth.profileName.value;
                    return Row(
                      children: [
                        _avatarFallback(name),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name.trim().isNotEmpty ? name.trim() : 'Your Profile',
                                style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Obx(() => Text(
                                '+91 ${_auth.profilePhone.value}',
                                style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 13,
                                    color: Colors.white70),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )),
                            ],
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),

            // Edit form
            Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: AppColors.shadow, blurRadius: 20, offset: const Offset(0, 6))
                ],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Update Profile',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark)),
                const SizedBox(height: 20),
                _buildField('Full Name', Iconsax.user, _nameCtrl),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Contact visible to public',
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textMedium)),
                      const SizedBox(height: 2),
                      const Text('Show call & WhatsApp on your listings',
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight)),
                    ]),
                  ),
                  Obx(() => Switch(
                    value: _isContactVisible.value,
                    onChanged: (v) => _isContactVisible.value = v,
                    activeThumbColor: AppColors.primary,
                    activeTrackColor: AppColors.primaryLight,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  )),
                ]),
                const SizedBox(height: 24),
                Obx(() => GradientButton(
                  onPressed: _auth.isLoading.value ? null : _save,
                  isLoading: _auth.isLoading.value,
                  label: 'Save Profile',
                )),
              ]),
            ),

            // Mobile Number Card
            _buildMobileNumberCard(),

            // Support
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Column(children: [
                  _legalTile(icon: Iconsax.star, label: 'Rate App', onTap: _rateApp),
                  Divider(height: 1, indent: 56, color: AppColors.divider),
                  _legalTile(icon: Iconsax.share, label: 'Share App', onTap: _shareApp),
                ]),
              ),
            ),

            // Legal
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Column(children: [
                  _legalTile(
                    icon: Iconsax.shield_tick,
                    label: 'Privacy Policy',
                    onTap: () async {
                      await Get.to(() => const PrivacyPolicyScreen(),
                          transition: Transition.rightToLeft,
                          duration: const Duration(milliseconds: 300));
                      _resetForm();
                    },
                  ),
                  Divider(height: 1, indent: 56, color: AppColors.divider),
                  _legalTile(
                    icon: Iconsax.document_text,
                    label: 'Terms of Service',
                    onTap: () async {
                      await Get.to(() => const TermsOfServiceScreen(),
                          transition: Transition.rightToLeft,
                          duration: const Duration(milliseconds: 300));
                      _resetForm();
                    },
                  ),
                ]),
              ),
            ),

            // Logout
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: OutlinedButton.icon(
                onPressed: _confirmLogout,
                icon: const Icon(Iconsax.logout, color: AppColors.error, size: 20),
                label: const Text('Logout',
                    style: TextStyle(fontFamily: 'Poppins', color: AppColors.error, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  side: const BorderSide(color: AppColors.error, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),

            // Delete Account
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Obx(() => TextButton(
                onPressed: _auth.isLoading.value ? null : _confirmDeleteAccount,
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
              padding: EdgeInsets.fromLTRB(20, 0, 20, 36 + AppInsets.bottomViewPadding(context)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('Made with ', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight)),
                const Icon(Icons.favorite_rounded, color: Color(0xFFE53935), size: 14),
                const Text(' by ', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight)),
                const Text('Dev', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryLight)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarFallback(String name) {
    final initials = _initials(name);
    return Container(
      width: 80, height: 80,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
      ),
      child: Center(
        child: initials.isNotEmpty
            ? Text(initials, style: const TextStyle(fontFamily: 'Poppins', fontSize: 30, fontWeight: FontWeight.w700, color: Colors.white))
            : const Icon(Iconsax.user5, size: 38, color: Colors.white),
      ),
    );
  }

  Widget _buildMobileNumberCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Iconsax.call, color: AppColors.primaryLight, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Mobile Number', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
                const SizedBox(height: 3),
                Obx(() => Text('+91 ${_auth.profilePhone.value}',
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark))),
                const SizedBox(height: 6),
                Obx(() {
                  final verified = _auth.profilePhoneVerified.value;
                  return verified
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.verified_rounded, color: AppColors.success, size: 12),
                          SizedBox(width: 4),
                          Text('Verified', style: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.success)),
                        ]))
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 12),
                          SizedBox(width: 4),
                          Text('Not verified', style: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.warning)),
                        ]));
                }),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Obx(() {
            if (!_auth.profilePhoneChangeLocked.value) {
              return TextButton(
                onPressed: _openPhoneVerify,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textLight,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                ),
                child: const Text('Change', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textLight)),
              );
            }
            return const SizedBox.shrink();
          }),
        ],
      ),
    );
  }

  Future<void> _openPhoneVerify() async {
    final result = await Get.toNamed(
      AppRoutes.phoneVerify,
      arguments: {'isChange': _auth.user.value?.isPhoneVerified ?? false},
    );
    if (result == true) {
      await _auth.refreshProfile();
      _resetForm();
    }
  }

  Widget _buildField(String label, IconData icon, TextEditingController ctrl) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textMedium)),
      const SizedBox(height: 8),
      TextFormField(
        controller: ctrl,
        style: const TextStyle(fontFamily: 'Poppins', fontSize: 15),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: AppColors.primaryLight, size: 20),
          hintText: 'Enter $label',
        ),
      ),
    ]);
  }

  Widget _legalTile({required IconData icon, required String label, required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: AppColors.primaryLight, size: 18),
      ),
      title: Text(label, style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textDark)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textLight),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 36),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Iconsax.logout, size: 28, color: AppColors.error),
            ),
            const SizedBox(height: 16),
            const Text('Logout?', style: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            const SizedBox(height: 8),
            const Text('Are you sure you want to logout?',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textMedium, height: 1.5),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textMedium,
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _auth.logout();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Logout', style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.delete_forever_rounded, size: 30, color: AppColors.error),
                )),
                const SizedBox(height: 16),
                const Center(child: Text('Delete Account', style: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark))),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                  ),
                  child: const Text(
                    'This will permanently delete your account, all listings, plots, photos and memberships. This action cannot be undone.',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.error, height: 1.55),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Type DELETE to confirm', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMedium)),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmCtrl,
                  autofocus: true,
                  onChanged: (_) => setDialogState(() {}),
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 2),
                  decoration: InputDecoration(
                    hintText: 'DELETE',
                    hintStyle: TextStyle(fontFamily: 'Poppins', fontSize: 15, letterSpacing: 2, color: Colors.grey.shade400),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.error, width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: canDelete ? () { Navigator.pop(ctx); _doDeleteAccount(); } : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        disabledBackgroundColor: AppColors.error.withValues(alpha: 0.35),
                        foregroundColor: Colors.white,
                        disabledForegroundColor: Colors.white70,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Delete Account', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600)),
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
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(width: 48, height: 48, child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.error)),
              const SizedBox(height: 20),
              const Text('Deleting your account...', style: TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark)),
              const SizedBox(height: 6),
              const Text('Please do not close the app.', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
            ]),
          ),
        ),
      ),
    );
    await _auth.deleteAccount();
    if (mounted && Navigator.canPop(context)) Navigator.pop(context);
  }
}
