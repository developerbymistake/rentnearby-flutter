import 'package:flutter/material.dart';
import '../config/app_colors.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Privacy Policy',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 17, fontWeight: FontWeight.w600)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _heading('Privacy Policy'),
          _updated('Last updated: May 29, 2026'),
          const SizedBox(height: 12),
          _body(
            'Bakhli is committed to protecting your privacy. This Privacy Policy explains what information we collect, how we use it, and what rights you have regarding your data when you use the Bakhli app.',
          ),
          _section(
            'Information We Collect',
            [
              'Google account details — when you sign in with Google, we receive your name, email address, and profile photo. This is used to create and display your profile.',
              'Mobile number — provided by you when setting up your profile. Required to post listings so tenants can contact you directly.',
              'Location (GPS) — used only in real-time to show rooms near you. Your location is never stored on our servers.',
              'Listing photos — images you upload are stored securely on our platform.',
              'Payment data — listing activation payments are processed by a third-party payment gateway. Bakhli does not store your card or bank details.',
            ],
          ),
          _section(
            'How We Use Your Information',
            [
              'To create and manage your account.',
              'To display your listings — including photos, address, rent, and contact number — to other users of the platform.',
              'To show you rental rooms available near your current location.',
              'To process listing activation payments through our payment partner.',
              'To improve the Bakhli platform and user experience.',
            ],
          ),
          _sectionBody(
            'What Is Publicly Visible',
            'When you post a listing on Bakhli, the details you provide — including photos, address, and rent amount — are visible to all users of the app. Your mobile number is shown on listings by default, but you can hide it at any time from the Profile screen using the "Contact visible to public" toggle. When hidden, your Call and WhatsApp contact buttons are not shown to other users.',
          ),
          _sectionBody(
            'Data Retention and Right to Erasure',
            'We retain your account data and listings for as long as your account is active. You may delete your account at any time from the Profile screen. Upon deletion, your account, all listings, plots, photos, and memberships are permanently and irreversibly removed from our systems. This right is provided under Section 13 of the Digital Personal Data Protection Act, 2023.',
          ),
          _sectionBody(
            'Confidentiality and Security',
            'We take reasonable measures to protect your data. However, no method of internet transmission or electronic storage is 100% secure. We strive to maintain strong security practices but cannot guarantee absolute protection against all threats.',
          ),
          _sectionBody(
            'Children\'s Privacy',
            'Bakhli is intended for adults (18 years and older). We do not knowingly collect personal information from minors. If you believe a minor is using the platform, please contact us at supportbakhli@gmail.com and we will take appropriate action.',
          ),
          _sectionBody(
            'Third-Party Services',
            'Sign-in is handled through Google Sign-In. By choosing to sign in, you are subject to Google\'s Privacy Policy in addition to ours.\n\nListing activation payments are processed by Razorpay, a licensed payment aggregator regulated by the Reserve Bank of India. Razorpay handles your payment information directly and is subject to their own Privacy Policy. Bakhli does not receive or store any card or bank account details.',
          ),
          _sectionBody(
            'Changes to This Policy',
            'We may update this Privacy Policy from time to time. When we do, we will update the "Last updated" date at the top of this page. We encourage you to review this policy periodically.',
          ),
          _sectionBody(
            'Contact Us',
            'If you have any questions or concerns about this Privacy Policy, please contact our Grievance Officer:\n\nName: Bakhli Team\nEmail: supportbakhli@gmail.com',
          ),
          const SizedBox(height: 32),
          Center(
            child: Text('© 2026 Bakhli. All rights reserved.',
                style: const TextStyle(
                    fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _heading(String text) => Text(text,
      style: const TextStyle(
          fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textDark));

  Widget _updated(String text) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: Text(text,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight)),
      );

  Widget _body(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Text(text,
            style: const TextStyle(
                fontFamily: 'Poppins', fontSize: 14, color: AppColors.textMedium, height: 1.6)),
      );

  Widget _sectionBody(String title, String body) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark)),
          const SizedBox(height: 6),
          Text(body,
              style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 14, color: AppColors.textMedium, height: 1.6)),
        ]),
      );

  Widget _section(String title, List<String> points) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark)),
          const SizedBox(height: 8),
          ...points.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: CircleAvatar(radius: 3, backgroundColor: AppColors.primaryLight),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(p,
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            color: AppColors.textMedium,
                            height: 1.6)),
                  ),
                ]),
              )),
        ]),
      );
}
