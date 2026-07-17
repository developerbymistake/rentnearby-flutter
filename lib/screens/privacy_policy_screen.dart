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
          _updated('Last updated: June 2, 2026'),
          const SizedBox(height: 12),
          _body(
            'Bakhli is committed to handling your personal information with care and transparency. This Privacy Policy outlines what information is collected, how it is used, and the choices available to you.',
          ),
          _section(
            'Information We Collect',
            [
              'Mobile number — collected during sign-up for account creation and verification purposes.',
              'Your name — provided by you and displayed alongside your listings.',
              'Location (GPS) — accessed in real-time solely to show nearby rental listings. Your location is not stored on Bakhli\'s servers.',
              'Listing photos — images uploaded by you, stored securely for the purpose of displaying your listings.',
              'Payment information — handled entirely by a third-party payment service. Bakhli does not receive, access, or store your card or bank account details.',
            ],
          ),
          _section(
            'How We Use Your Information',
            [
              'To create and maintain your Bakhli account.',
              'To display your listing details to other users, in line with the visibility preferences you have selected.',
              'To show you rental listings available near your current location.',
              'To facilitate listing-related payments through our payment partner.',
              'To maintain and improve the quality of the service.',
            ],
          ),
          _sectionBody(
            'What Is Publicly Visible',
            'When you publish a listing on Bakhli, your photos, property address, and rent amount are visible to all users. The property\'s location is always displayed and cannot be hidden, as it is essential information for prospective tenants seeking accommodation. Your mobile number is visible by default on your listings, but you may choose to hide it at any time through your profile settings. When contact visibility is turned off, your phone number and direct contact options are no longer shown to other users.',
          ),
          _sectionBody(
            'Data Retention and Right to Erasure',
            'Your account information and listings are retained for as long as your account remains active. You may request deletion of your account at any time through the profile settings. Upon deletion, all associated data — including listings, photos, and wallet/coin transaction records — is permanently removed from our systems. This right is provided in accordance with the Digital Personal Data Protection Act, 2023.',
          ),
          _sectionBody(
            'Security',
            'Reasonable technical and organisational measures are in place to protect your information. While every effort is made to safeguard your data, no system can be considered entirely free of risk.',
          ),
          _sectionBody(
            'Children\'s Privacy',
            'Bakhli is intended for individuals aged 18 and above. Information is not knowingly collected from minors. If you have reason to believe a minor has created an account, please write to us at supportbakhli@gmail.com.',
          ),
          _sectionBody(
            'Third-Party Services',
            'Account verification is completed via a one-time password delivered through WhatsApp. This process is subject to WhatsApp\'s own Privacy Policy.\n\nPayment processing is handled by Razorpay, a licensed payment aggregator regulated by the Reserve Bank of India. All payment data is handled directly by Razorpay and governed by their Privacy Policy. Bakhli does not access or retain any financial credentials.',
          ),
          _sectionBody(
            'Changes to This Policy',
            'This Privacy Policy may be revised periodically. Any changes will be reflected in the \'Last updated\' date shown at the top of this document. We encourage you to review this policy from time to time.',
          ),
          _sectionBody(
            'Contact Us',
            'For any questions or concerns regarding this Privacy Policy, please write to us at:\n\nEmail: supportbakhli@gmail.com',
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
