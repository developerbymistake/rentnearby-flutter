import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:share_plus/share_plus.dart';
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

  String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return '';
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts[0][0].toUpperCase();
  }

  void _shareApp() {
    Share.share(
      '🏠 RentNearBy — Find rooms near you!\n'
      'No brokers. No commission. Just homes.\n\n'
      'Download now: https://rentnearby.in',
      subject: 'Check out RentNearBy!',
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
                    // Centered avatar + name
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 36),
                      child: Column(
                        children: [
                          Obx(() {
                            final initials = _initials(_auth.user.value?.name);
                            return Container(
                              width: 86, height: 86,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.22),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withOpacity(0.6), width: 2.5),
                              ),
                              child: Center(
                                child: initials.isNotEmpty
                                    ? Text(initials,
                                        style: const TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 32,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white))
                                    : const Icon(Iconsax.user5, size: 40, color: Colors.white),
                              ),
                            );
                          }),
                          const SizedBox(height: 14),
                          Obx(() => Text(
                            _auth.user.value?.name?.trim().isNotEmpty == true
                                ? _auth.user.value!.name!.trim()
                                : 'Your Profile',
                            style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white),
                            textAlign: TextAlign.center,
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
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                                    decoration: BoxDecoration(
                                        color: AppColors.accent,
                                        borderRadius: BorderRadius.circular(20)),
                                    child: const Text('Admin',
                                        style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white)),
                                  ),
                                )
                              : const SizedBox()),
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
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              child: Column(children: [
                Divider(color: AppColors.divider.withOpacity(0.6), thickness: 1),
                const SizedBox(height: 14),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('Made with ',
                      style: TextStyle(
                          fontFamily: 'Poppins', fontSize: 12, color: AppColors.textHint)),
                  const Icon(Icons.favorite_rounded, color: Color(0xFFE53935), size: 13),
                  const Text(' for renters who hate broker fees',
                      style: TextStyle(
                          fontFamily: 'Poppins', fontSize: 12, color: AppColors.textHint)),
                ]),
                const SizedBox(height: 4),
                const Text('RentNearBy · v1.0.0',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: AppColors.textHint,
                        letterSpacing: 0.4)),
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

  void _save() => _auth.updateProfile(
        _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : null,
        _gmailCtrl.text.trim().isNotEmpty ? _gmailCtrl.text.trim() : null,
      );

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
        content: const Text('Are you sure you want to logout?',
            style: TextStyle(fontFamily: 'Poppins')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(fontFamily: 'Poppins', color: AppColors.textLight))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
            onPressed: () {
              Navigator.pop(context);
              _auth.logout();
            },
            child: const Text('Logout', style: TextStyle(fontFamily: 'Poppins')),
          ),
        ],
      ),
    );
  }
}
