import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:animate_do/animate_do.dart';
import 'package:iconsax/iconsax.dart';
import '../config/app_colors.dart';
import '../controllers/auth_controller.dart';
import '../utils/app_toast.dart';
import '../widgets/gradient_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _auth = Get.find<AuthController>();
  final _nameCtrl = TextEditingController();
  late final String _phone;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>;
    _phone = args['phone'] as String;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      AppToast.error('Please enter your full name');
      return;
    }
    if (name.length > 100) {
      AppToast.error('Name cannot exceed 100 characters');
      return;
    }
    await _auth.completePhoneOnboarding(phone: _phone, name: name);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Stack(
          children: [
            Container(height: 220, decoration: const BoxDecoration(gradient: AppColors.primaryGradient)),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    FadeInDown(
                      duration: const Duration(milliseconds: 500),
                      child: const Text('Complete your profile',
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                    const SizedBox(height: 4),
                    FadeInDown(
                      delay: const Duration(milliseconds: 100),
                      duration: const Duration(milliseconds: 500),
                      child: const Text('Just one more step', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.white70)),
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
                          boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.10), blurRadius: 28, offset: const Offset(0, 8))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Phone display (read-only)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.divider),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.phone_android_rounded, color: AppColors.primary, size: 20),
                                  const SizedBox(width: 12),
                                  Text('+91 $_phone',
                                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(8)),
                                    child: const Text('Verified', style: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF059669))),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Full Name
                            const Text('Full Name', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textMedium)),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _nameCtrl,
                              textCapitalization: TextCapitalization.words,
                              maxLength: 100,
                              style: const TextStyle(fontFamily: 'Poppins', fontSize: 15),
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Iconsax.user, color: AppColors.primaryLight, size: 20),
                                hintText: 'Your full name',
                                counterText: '',
                              ),
                              onFieldSubmitted: (_) => _submit(),
                            ),
                            const SizedBox(height: 28),

                            Obx(() => GradientButton(
                              onPressed: _auth.isLoading.value ? null : _submit,
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
}
