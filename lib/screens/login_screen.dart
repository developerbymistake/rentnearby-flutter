import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:animate_do/animate_do.dart';
import '../config/app_colors.dart';
import '../controllers/auth_controller.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final screenH = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            height: screenH * 0.52,
            decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
          ),
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: screenH * 0.06),
                  FadeInDown(
                    duration: const Duration(milliseconds: 600),
                    child: const Column(
                      children: [
                        Icon(Icons.location_on_rounded, size: 48, color: Colors.white),
                        SizedBox(height: 12),
                        Text('Bakhli',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 36,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            )),
                        SizedBox(height: 4),
                        Text('Discover your new address',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              color: Colors.white70,
                            )),
                      ],
                    ),
                  ),
                  SizedBox(height: screenH * 0.12),
                  FadeInUp(
                    duration: const Duration(milliseconds: 600),
                    delay: const Duration(milliseconds: 200),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text('Welcome to Bakhli',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              )),
                          const SizedBox(height: 6),
                          const Text('Sign in to find rooms near you',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                color: AppColors.textLight,
                              )),
                          const SizedBox(height: 32),
                          Obx(() => _GoogleSignInButton(
                                isLoading: auth.isLoading.value,
                                onPressed: auth.isLoading.value ? null : auth.signInWithGoogle,
                              )),
                          const SizedBox(height: 20),
                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                color: AppColors.textLight,
                                height: 1.6,
                              ),
                              children: [
                                const TextSpan(text: 'By continuing, you agree to our '),
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.middle,
                                  child: GestureDetector(
                                    onTap: () => Get.to(() => const TermsOfServiceScreen(),
                                        transition: Transition.rightToLeft,
                                        duration: const Duration(milliseconds: 300)),
                                    child: const Text('Terms of Service',
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 11,
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
                                          fontSize: 11,
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
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;

  const _GoogleSignInButton({required this.isLoading, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFDADCE0), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          backgroundColor: Colors.white,
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/images/google_logo.png', width: 20, height: 20,
                      errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata_rounded,
                          color: Color(0xFF4285F4), size: 26)),
                  const SizedBox(width: 12),
                  const Text('Sign in with Google',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      )),
                ],
              ),
      ),
    );
  }
}
