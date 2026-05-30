import 'package:flutter/material.dart';
import '../config/app_colors.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Terms of Service',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 17, fontWeight: FontWeight.w600)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _heading('Terms of Service'),
          _updated('Last updated: May 29, 2026'),
          const SizedBox(height: 12),
          _body(
            'By using the Bakhli app, you agree to be bound by these Terms of Service. Please read them carefully. If you do not agree to these terms, do not use the platform.',
          ),
          _sectionBody(
            'What Bakhli Is',
            'Bakhli is a room listing platform that connects room owners with people looking for rental accommodation — primarily in Uttarakhand. We are not a broker or an agent. We provide the platform; all transactions and agreements are between room owners and tenants directly.',
          ),
          _sectionBody(
            'Eligibility',
            'Bakhli is intended for adults. By using the app, you confirm that you are 18 years of age or older. We do not independently verify age.',
          ),
          _sectionBody(
            'Your Account',
            'You may create one Bakhli account per Google account. You are responsible for maintaining the security of your account. Only one active login is allowed per account at a time — signing in on a new device will automatically sign you out from your previous one. A verified mobile number is required to post listings.',
          ),
          _section(
            'Listing Rules',
            [
              'All listing information must be accurate, complete, and up to date.',
              'Photos must be of the actual property you are listing.',
              'Duplicate listings of the same property are not permitted.',
              'Listings must be for genuine rental properties located in India.',
              'Listing details — including photos, address, rent, and your contact number — are publicly visible to all users once posted.',
            ],
          ),
          _section(
            'Prohibited Activities',
            [
              'Posting false, misleading, or fraudulent listings.',
              'Creating fake accounts or impersonating other users.',
              'Scraping, copying, or reproducing any content from the platform without permission.',
              'Using the platform for any purpose other than finding or listing rental accommodation.',
              'Harassing, threatening, or abusing other users.',
            ],
          ),
          _sectionBody(
            'Bakhli\'s Role and Limitations',
            'Bakhli provides a platform for users to post and discover rental listings. We do not verify or guarantee the accuracy of any listing. Bakhli and its team will not be held responsible for inaccurate, misleading, or fraudulent content submitted by users. Users are solely responsible for conducting their own due diligence before entering into any rental agreement.',
          ),
          _sectionBody(
            'Payments',
            'Listing activation requires a one-time fee processed through Razorpay, a third-party payment provider. All payments are in Indian Rupees (INR). Fees paid for listing activation are non-refundable once processed. Bakhli does not store your payment card or bank details — all payment data is handled by them.',
          ),
          _sectionBody(
            'Content You Post',
            'By posting a listing on Bakhli, you grant Bakhli a non-exclusive, royalty-free licence to display that content within the platform. You retain ownership of your content. You may remove your listing at any time from within the app.',
          ),
          _sectionBody(
            'Account Termination',
            'Bakhli reserves the right to suspend or permanently ban any account that violates these Terms of Service, posts fraudulent listings, or engages in any activity that harms other users or the platform — without prior notice.',
          ),
          _sectionBody(
            'Limitation of Liability',
            'Bakhli is not liable for any loss, damage, or dispute arising from interactions between room owners and tenants. The platform assumes no liability for the quality, safety, or legality of listed properties. Users interact with each other at their own risk.',
          ),
          _sectionBody(
            'Changes to These Terms',
            'Bakhli may revise these Terms of Service at any time. The updated version will be posted in the app with a revised date. Continued use of the platform after changes are posted constitutes your acceptance of the updated terms.',
          ),
          _sectionBody(
            'Contact Us',
            'If you have questions about these Terms of Service or wish to report a violation, please contact our Grievance Officer:\n\nName: Bakhli Team\nEmail: supportbakhli@gmail.com',
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
