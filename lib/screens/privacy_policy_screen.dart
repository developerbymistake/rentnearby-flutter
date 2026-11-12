import 'package:flutter/material.dart';
import '../design/design.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GateLegalPage(
      title: 'Privacy Policy',
      children: [
          _heading('Privacy Policy'),
          _updated('Last updated: November 6, 2026'),
          const SizedBox(height: 12),
          _body('This Privacy Policy explains what information Bakhli collects, how it is used, and the choices available to you.'),
          _section('Information We Collect', [
            'Account details — your mobile number, your name and the role you choose in the app (Seeker, Stay Owner or Taxi Driver).',
            'Location — your device\'s precise or approximate location, used while you use the app. Locations you set for a stay, a taxi route or a trip, or share with a report, may be stored.',
            'Photos and content — photos, descriptions and other content you upload for a stay, a taxi or a job post.',
            'Stay, taxi and job details — information you enter, such as prices, rules, vehicle details, routes and fares, and the contact numbers you add to a post.',
            'Owner and driver details — information that stay owners and taxi drivers provide about themselves, their stay or their vehicle, including identity, licence, registration and tax details where asked.',
            'Trip details — places, dates, number of travellers, preferences and other details of the trips you plan or save.',
            'Messages and enquiries — messages, enquiries, offers, replies and booking details you send or receive in the app, including contact or payment details that users choose to share with each other.',
            'Subscription information — your plan, subscription status and related purchase records.',
            'Device and usage information — device and notification identifiers, app version, how the app was installed, and usage and diagnostic information.',
            'Reports — details you submit when you report a user, a post or a problem during a trip.',
            'Website visits — standard technical information, such as IP address, browser type and pages viewed, that our website and its service providers may receive when you visit.',
          ]),
          _section('How We Use Your Information', [
            'To create and maintain your account and to sign you in.',
            'To provide the service, including showing stays, taxis, jobs and trip information near you.',
            'To help you plan, save and follow your trips, including maps, routes and reminders.',
            'To display your stays, taxi details and job posts to other users, in line with your settings.',
            'To enable enquiries, bookings and conversations between users.',
            'To send notifications about your account, trips, enquiries, plans and messages.',
            'To manage and support your plan and subscription.',
            'To review owner and driver details, handle reports, help protect users and the platform, and prevent misuse or fraud.',
            'To comply with the law, and to maintain and improve the service.',
          ]),
          _sectionBody('What Is Publicly Visible', 'When you publish a stay, a taxi or a job post on Bakhli, the content you add, such as photos, description, location, prices and routes, may be visible to other users. Depending on your settings and the feature used, your name and contact numbers may also be shown to other users.\n\nWhen you send an enquiry or a booking request, your name and contact details may be shared with the host or driver concerned. If you share a trip summary or a link, the people you share it with can see it.'),
          _sectionBody('Who We Share Information With', 'We share information with other users as needed to provide the service, as described above.\n\nWe use trusted third-party service providers that help us with hosting, notifications, maps and location data, image storage, messaging and subscription billing. Their handling of information is subject to their own terms and privacy policies.\n\nWe may also disclose information where required by law, a court or a government authority, or to protect the rights and safety of users and Bakhli.'),
          _sectionBody('Consent', 'By using Bakhli, you consent to the collection and use of information as described in this Policy. You can withdraw your consent by deleting your account, after which some features will no longer be available to you.'),
          _sectionBody('Data Retention and Right to Erasure', 'We keep your information for as long as your account is active and as needed to provide the service. You can delete your account at any time from the app (Profile).\n\nChats with no new messages for 90 days, notifications older than 90 days and old closed enquiries are removed automatically.\n\nWhen you delete your account, we process your request in line with this Privacy Policy and applicable law. We may delete, anonymise or retain certain information, including where needed for legal, accounting, safety or fraud-prevention reasons, or to handle disputes and claims. Messages, enquiries and reports you exchanged with other users may remain available to them. We may keep information for longer where the law requires.'),
          _sectionBody('Your Rights', 'As provided under the Digital Personal Data Protection Act, 2023 and other applicable law, you may ask to access, correct or erase your personal data, withdraw consent, and raise a grievance. To do so, use the options in the app or write to the Grievance Officer below. You may also approach the Data Protection Board of India where the law allows.'),
          _sectionBody('Security', 'We take reasonable measures to protect your information. However, no method of storage or transmission is without risk. In case of a personal data breach, we will act as required by law.'),
          _sectionBody('Children\'s Privacy', 'Bakhli is intended for individuals aged 18 and above. Information is not knowingly collected from minors. If you have reason to believe a minor has created an account, please write to us at supportbakhli@gmail.com.'),
          _sectionBody('Third-Party Services', 'Some features rely on third-party services, such as one-time password delivery, push notifications, maps and place data, image storage and subscription billing. Your use of these features may also be subject to the terms and privacy policies of those providers.\n\nCard and bank details for subscriptions are handled by the app store or payment provider you use to subscribe.'),
          _sectionBody('Changes to This Policy', 'This Privacy Policy may be revised periodically. Any changes will be reflected in the "Last updated" date shown at the top of this document, and we may notify you in the app of significant changes. We encourage you to review this policy from time to time.'),
          _sectionBody('Grievance Officer', 'In accordance with the Information Technology Act, 2000 and the rules made thereunder, the contact details of the Grievance Officer are provided below:\n\nGrievance Officer\nEmail: supportbakhli@gmail.com\n\nBakhli will acknowledge grievances within 24 hours of receipt and endeavour to resolve them within 15 days.'),
          _sectionBody('Contact Us', 'For any questions or concerns regarding this Privacy Policy, please write to us:\n\nEmail: supportbakhli@gmail.com'),
          const SizedBox(height: 32),
          const GateLegalCaption('© 2026 Bakhli. All rights reserved.', center: true),
          const SizedBox(height: 20),
      ],
    );
  }

  Widget _heading(String text) => GateLegalHeading(text);

  Widget _updated(String text) => GateLegalCaption(text);

  Widget _body(String text) => GateLegalBody(text);

  Widget _sectionBody(String title, String body) => GateLegalSection(title: title, body: body);

  Widget _section(String title, List<String> points) => GateLegalSection(title: title, bullets: points);
}
