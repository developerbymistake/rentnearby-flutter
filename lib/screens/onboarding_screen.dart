import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:animate_do/animate_do.dart';
import 'package:iconsax/iconsax.dart';
import '../config/app_colors.dart';
import '../controllers/auth_controller.dart';
import '../utils/app_toast.dart';
import '../widgets/gradient_button.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _auth = Get.find<AuthController>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _agreed = false;

  late final String _idToken;
  late final String _googleEmail;
  late final String? _photoUrl;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>;
    _idToken = args['idToken'] as String;
    _googleEmail = args['email'] as String? ?? '';
    _photoUrl = args['photoUrl'] as String?;
    _nameCtrl.text = args['name'] as String? ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty) {
      AppToast.error('Please enter your full name');
      return;
    }
    if (name.length > 100) {
      AppToast.error('Name cannot exceed 100 characters');
      return;
    }
    if (phone.length != 10) {
      AppToast.error('Enter a valid 10-digit mobile number');
      return;
    }
    await _auth.completeOnboarding(
      idToken: _idToken,
      name: name,
      phoneNumber: phone,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Stack(
          children: [
            Container(
              height: 220,
              decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
            ),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    FadeInDown(
                      duration: const Duration(milliseconds: 500),
                      child: const Text('Complete your profile',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          )),
                    ),
                    const SizedBox(height: 4),
                    FadeInDown(
                      delay: const Duration(milliseconds: 100),
                      duration: const Duration(milliseconds: 500),
                      child: const Text('A few quick details to get started',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            color: Colors.white70,
                          )),
                    ),
                    const SizedBox(height: 32),
                    FadeInUp(
                      duration: const Duration(milliseconds: 500),
                      delay: const Duration(milliseconds: 150),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.10),
                              blurRadius: 28,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Profile photo + email (read-only)
                            Row(
                              children: [
                                _buildAvatar(),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Google Account',
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 11,
                                            color: AppColors.textLight,
                                          )),
                                      const SizedBox(height: 2),
                                      Text(_googleEmail,
                                          style: const TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.textMedium,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 28),

                            // Full Name
                            _fieldLabel('Full Name'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _nameCtrl,
                              textCapitalization: TextCapitalization.words,
                              maxLength: 100,
                              style: const TextStyle(fontFamily: 'Poppins', fontSize: 15),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Iconsax.user, color: AppColors.primaryLight, size: 20),
                                hintText: 'Your full name',
                                counterText: '',
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Phone Number
                            _fieldLabel('Mobile Number'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _phoneCtrl,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              style: const TextStyle(fontFamily: 'Poppins', fontSize: 15),
                              decoration: InputDecoration(
                                prefixIcon: Container(
                                  margin: const EdgeInsets.all(12),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('+91',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      )),
                                ),
                                hintText: 'Enter mobile number',
                              ),
                            ),
                            const SizedBox(height: 24),

                            // T&C Checkbox
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: Checkbox(
                                    value: _agreed,
                                    onChanged: (v) {
                                      FocusScope.of(context).unfocus();
                                      setState(() => _agreed = v ?? false);
                                    },
                                    activeColor: AppColors.primary,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                    side: const BorderSide(color: AppColors.textLight, width: 1.5),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 12,
                                        color: AppColors.textMedium,
                                        height: 1.5,
                                      ),
                                      children: [
                                        const TextSpan(text: 'I agree to the '),
                                        WidgetSpan(
                                          alignment: PlaceholderAlignment.middle,
                                          child: GestureDetector(
                                            onTap: () => Get.to(() => const TermsOfServiceScreen(),
                                                transition: Transition.rightToLeft,
                                                duration: const Duration(milliseconds: 300)),
                                            child: const Text('Terms of Service',
                                                style: TextStyle(
                                                  fontFamily: 'Poppins',
                                                  fontSize: 12,
                                                  color: AppColors.primary,
                                                  fontWeight: FontWeight.w600,
                                                  decoration: TextDecoration.underline,
                                                  decorationColor: AppColors.primary,
                                                )),
                                          ),
                                        ),
                                        const TextSpan(text: ' and '),
                                        WidgetSpan(
                                          alignment: PlaceholderAlignment.middle,
                                          child: GestureDetector(
                                            onTap: () => Get.to(() => const PrivacyPolicyScreen(),
                                                transition: Transition.rightToLeft,
                                                duration: const Duration(milliseconds: 300)),
                                            child: const Text('Privacy Policy',
                                                style: TextStyle(
                                                  fontFamily: 'Poppins',
                                                  fontSize: 12,
                                                  color: AppColors.primary,
                                                  fontWeight: FontWeight.w600,
                                                  decoration: TextDecoration.underline,
                                                  decorationColor: AppColors.primary,
                                                )),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            Obx(() => GradientButton(
                                  onPressed: (_agreed && !_auth.isLoading.value) ? _submit : null,
                                  isLoading: _auth.isLoading.value,
                                  label: 'Get Started',
                                )),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    if (_photoUrl != null) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: _photoUrl!,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          placeholder: (_, __) => _avatarPlaceholder(),
          errorWidget: (_, __, ___) => _avatarPlaceholder(),
        ),
      );
    }
    return _avatarPlaceholder();
  }

  Widget _avatarPlaceholder() => Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          shape: BoxShape.circle,
        ),
        child: const Icon(Iconsax.user, color: Colors.white, size: 28),
      );

  Widget _fieldLabel(String label) => Text(label,
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.textMedium,
      ));
}
