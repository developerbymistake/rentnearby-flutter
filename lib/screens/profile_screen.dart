import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:share_plus/share_plus.dart';
import '../config/app_colors.dart';
import '../controllers/auth_controller.dart';
import '../utils/app_toast.dart';
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
  bool _tickerWasActive = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = _auth.user.value?.name ?? '';
    _gmailCtrl.text = _auth.user.value?.gmailId ?? '';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = TickerMode.of(context);
    if (active && !_tickerWasActive) {
      _nameCtrl.text = _auth.user.value?.name ?? '';
      _gmailCtrl.text = _auth.user.value?.gmailId ?? '';
    }
    _tickerWasActive = active;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _gmailCtrl.dispose();
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
            // Profile hero header
            Container(
              decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
              child: SafeArea(
                bottom: false,
                child: Stack(
                  children: [
                    // Avatar + name/phone in a Row
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
                                border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
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
                                      fontFamily: 'Poppins', fontSize: 15, color: Colors.white70),
                                )),
                                Obx(() => _auth.user.value?.isAdmin == true
                                    ? Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                          decoration: BoxDecoration(
                                              color: AppColors.accent,
                                              borderRadius: BorderRadius.circular(20)),
                                          child: const Text('Admin',
                                              style: TextStyle(
                                                  fontFamily: 'Poppins',
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white)),
                                        ),
                                      )
                                    : const SizedBox()),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Share icon — top right
                    Positioned(
                      top: 8, right: 8,
                      child: IconButton(
                        onPressed: _shareApp,
                        icon: const Icon(Icons.share_rounded, color: Colors.white, size: 22),
                        tooltip: 'Share App',
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Form card
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
                const Text('Edit Profile',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark)),
                const SizedBox(height: 20),
                _buildField('Full Name', Iconsax.user, _nameCtrl),
                const SizedBox(height: 16),
                _buildField('Gmail ID (Optional)', Iconsax.sms, _gmailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    hint: 'Enter your Gmail (optional)'),
                const SizedBox(height: 24),
                Obx(() => GradientButton(
                  onPressed: _auth.isLoading.value ? null : _save,
                  isLoading: _auth.isLoading.value,
                  label: 'Save Profile',
                )),
              ]),
            ),

            // Logout
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('Made with ',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textLight,
                        letterSpacing: 0.2)),
                const Icon(Icons.favorite_rounded, color: Color(0xFFE53935), size: 14),
                const Text(' by ',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textLight,
                        letterSpacing: 0.2)),
                const Text('Dev',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryLight,
                        letterSpacing: 0.2)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, IconData icon, TextEditingController ctrl,
      {TextInputType? keyboardType, String? hint}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textMedium)),
      const SizedBox(height: 8),
      TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        style: const TextStyle(fontFamily: 'Poppins', fontSize: 15),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: AppColors.primaryLight, size: 20),
          hintText: hint ?? 'Enter $label',
        ),
      ),
    ]);
  }

  void _save() {
    FocusScope.of(context).unfocus();
    final name = _nameCtrl.text.trim();
    final gmail = _gmailCtrl.text.trim();

    if (name.isEmpty) {
      AppToast.error('Name is required.');
      return;
    }
    if (name.length > 100) {
      AppToast.error('Name cannot exceed 100 characters.');
      return;
    }
    if (gmail.isNotEmpty && !RegExp(r'^[\w.+-]+@[\w-]+\.[\w.]+$').hasMatch(gmail)) {
      AppToast.error('Enter a valid email address.');
      return;
    }

    _auth.updateProfile(name, gmail.isNotEmpty ? gmail : null);
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Iconsax.logout, size: 28, color: AppColors.error),
              ),
              const SizedBox(height: 16),
              const Text(
                'Logout?',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Are you sure you want to logout?',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: AppColors.textMedium,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textMedium,
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Logout',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
