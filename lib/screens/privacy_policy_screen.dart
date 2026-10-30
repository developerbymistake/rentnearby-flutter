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
          _updated('Last updated: October 30, 2026'),
          const SizedBox(height: 12),
          _body('Bakhli is committed to handling your personal information with care and transparency. This Privacy Policy outlines what information is collected, how it is used, and the choices available to you.'),
          _section('Information We Collect', [
            'Mobile number — collected during sign-up for account creation and verification.',
            'Your name — provided by you and displayed alongside your listings.',
            'Your role — the role you choose in the app (Seeker, Rent Owner, Property Owner, Stay Owner or Taxi Driver).',
            'Location (GPS) — your phone\'s location is accessed in real time to show nearby listings. We do not keep a history of your live location. The map location you set for a listing, stay or taxi route is stored and shown to other users.',
            'Photos — images you upload for listings, stays and vehicle number plates, stored with our image hosting provider.',
            'Listing, stay, job and taxi details — information you enter, including prices, addresses, vehicle details, number plate, routes and fares, and the phone or WhatsApp numbers you add to a post.',
            'Chat messages — messages you send through Bakhli\'s chat feature are stored to enable the conversation.',
            'Plan and purchase information — your plan, order IDs, amounts, dates and the Google Play purchase token, used to confirm and manage your subscription. A coded identifier derived from your account is shared with Google Play to link a purchase to your account. Payments are made through Google Play; Bakhli does not receive or store your card or bank details.',
            'Device and notification information — a push notification token, the app version, and Google Play install-referrer information (to understand how the app was installed).',
            'Reports — details you submit when you report a listing.',
          ]),
          _sectionBody('How We Use Your Information', 'Bakhli does not sell your personal information.'),
          _section('', [
            'To create and maintain your account and verify your login.',
            'To display your listings, stays, job posts and taxi details to other users, in line with your visibility settings.',
            'To show you listings, stays, jobs and taxis near you.',
            'To confirm, manage and support your plan and subscription.',
            'To send push notifications about your account, listings, plans and messages.',
            'To enable conversations between users through the chat feature.',
            'To review reports, keep the platform safe, and prevent misuse or fraud.',
            'To keep records required by law, and to maintain and improve the quality of the service.',
          ]),
          _sectionBody('What Is Publicly Visible', 'When you publish a listing on Bakhli, its photos, address, location and price are visible to all users. The location of a listing is always displayed and cannot be hidden, as it is essential information for people seeking accommodation. Your name and, unless you have hidden it, your mobile number are shown on your listings. Contact numbers on job posts and taxi listings are shown to logged-in users. Anything you post is visible to other users while it is live.'),
          _sectionBody('Who We Share Information With', 'We use trusted service providers to run Bakhli: Google (Google Play Billing and Play Store services, and Firebase Cloud Messaging for notifications), WhatsApp (one-time passwords), an image hosting provider for photos, map and place-search services, and our hosting providers. They process information only to provide their service and are subject to their own privacy policies.\n\nWe may also disclose information where required by law, a court or a government authority, or to protect the rights and safety of users and Bakhli.'),
          _sectionBody('Consent', 'By using Bakhli, you consent to the collection and use of information as described in this Policy. You can withdraw your consent by deleting your account, after which some features will no longer be available to you.'),
          _sectionBody('Data Retention and Right to Erasure', 'Your account information and listings are retained for as long as your account remains active. You can delete your account at any time from the app (Profile). When you delete your account, your profile, sessions, notification tokens and history, listings and photos are removed.\n\nSome records are kept after deletion. Subscription and order records are kept in anonymised form, no longer linked to you, for accounting and legal reasons. The name, mobile number and dates of a deleted account may be kept for up to 180 days to prevent fraud and to handle legal claims, and are then deleted. Conversations and reports involving other users may be kept for a limited period where needed for safety, dispute handling or legal compliance. We may keep information for longer where the law requires.'),
          _sectionBody('Your Rights', 'As provided under the Digital Personal Data Protection Act, 2023 and other applicable law, you may ask to access, correct or erase your personal data, withdraw consent, and raise a grievance. To do so, use the options in the app or write to the Grievance Officer below. You may also approach the Data Protection Board of India where the law allows.'),
          _sectionBody('Security', 'Reasonable technical and organisational measures are in place to protect your information. While every effort is made to safeguard your data, no system can be considered entirely free of risk. In case of a personal data breach, we will act as required by law.'),
          _sectionBody('Children\'s Privacy', 'Bakhli is intended for individuals aged 18 and above. Information is not knowingly collected from minors. If you have reason to believe a minor has created an account, please write to us at supportbakhli@gmail.com.'),
          _sectionBody('Third-Party Services', 'One-time passwords are delivered via WhatsApp and are subject to WhatsApp\'s own Privacy Policy.\n\nSubscription payments are processed by Google Play and are subject to Google\'s Terms and Privacy Policy. Push notifications use Firebase Cloud Messaging by Google. Bakhli does not access or retain your financial credentials.'),
          _sectionBody('Changes to This Policy', 'This Privacy Policy may be revised periodically. Any changes will be reflected in the "Last updated" date shown at the top of this document, and we may notify you in the app of significant changes. We encourage you to review this policy from time to time.'),
          _sectionBody('Grievance Officer', 'In accordance with the Information Technology Act, 2000 and the rules made thereunder, the contact details of the Grievance Officer are provided below:\n\nGrievance Officer\nEmail: supportbakhli@gmail.com\n\nBakhli will acknowledge grievances within 24 hours of receipt and endeavour to resolve them within 15 days.'),
          _sectionBody('Contact Us', 'For any questions or concerns regarding this Privacy Policy, please write to us:\n\nEmail: supportbakhli@gmail.com'),
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
          if (title.isNotEmpty) ...[
            Text(title,
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark)),
            const SizedBox(height: 8),
          ],
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
