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
          _updated('Last updated: October 31, 2026'),
          const SizedBox(height: 12),
          _body('By using Bakhli, you agree to these Terms of Service. Please read them carefully before proceeding.'),
          _sectionBody('About Bakhli', 'Bakhli is a digital platform that helps people in India find and list rental rooms and plots, homestays and other stays, local jobs at stays, and local taxi drivers. Users can view listings, photos, locations and contact details, and get in touch with each other directly.\n\nBakhli is only a platform that connects users. Bakhli is not a broker, agent, employer, hotel, travel agency or taxi operator. All rental, stay, job and ride arrangements, including negotiations, agreements and payments, take place directly and exclusively between the users.'),
          _sectionBody('Eligibility', 'Bakhli is designed for individuals who are 18 years of age or older. By creating an account, you confirm that you meet this age requirement.'),
          _sectionBody('Your Account and Role', 'Each mobile number may be linked to one Bakhli account. You are solely responsible for the security and activity of your account. Only one active session is permitted at a time, and signing in on a new device will end your existing session. Account verification is completed via a one-time password sent through WhatsApp.\n\nWhen you first sign in you choose one role: Seeker, Rent Owner, Property Owner, Stay Owner or Taxi Driver. An account has one role at a time. A role may be changed only through a request that Bakhli may approve or reject, and a change may not be available once a Stay or Taxi listing has been approved. Changing your role may remove the listings of the role you leave.'),
          _section('Listing and Posting Rules', [
            'All details must be accurate, complete and a truthful representation of the property, stay, vehicle or job.',
            'Photos must be genuine images of what is being listed.',
            'Each property, stay, vehicle or job may be listed only once, and you must have the right to list it.',
            'Listings must be real and located within India.',
            'Taxi Drivers must hold a valid driving licence of the class needed to drive a transport vehicle, and a valid registration, permit, fitness certificate and insurance for the vehicle. They must give their own driving licence number, their own date of birth and the correct vehicle number.',
            'Stay Owners must hold every registration, licence or permission their stay needs under local, state and central law, and must give the correct registration type, registration number and, if registered, GSTIN.',
            'Job posts must be genuine and lawful, must be posted by the employer or its authorised person, and must not ask candidates for money or fees of any kind.',
            'Where the app allows it, you can control the visibility of your contact information in your profile settings.',
          ]),
          _section('Prohibited Conduct', [
            'Submitting false, inaccurate or misleading information.',
            'Creating multiple accounts or misrepresenting your identity.',
            'Copying or extracting content from Bakhli without prior written consent.',
            'Using the contact details of other users for anything other than the purpose for which they were published.',
            'Spam, harassment, threats, or conduct that is harmful or disrespectful toward other users.',
            'Using Bakhli for any unlawful purpose, or for any purpose unrelated to finding or listing rooms, plots, stays, jobs or taxis.',
          ]),
          _sectionBody('Listings, Jobs and Taxi Information', 'All listings, job posts and taxi details on Bakhli are published by the users themselves. Their accuracy, completeness and availability are the sole responsibility of the user who posted them. Bakhli does not inspect, verify, authenticate or endorse any listing, owner, employer, driver, vehicle, licence or job offer, or the information they contain.\n\nBakhli may ask Taxi Drivers and Stay Owners for their licence, date of birth, registration and GSTIN details and may review them before a listing goes live. A review by Bakhli only checks that the details look complete and consistent. It is not a confirmation that a licence, registration, vehicle, stay or person is genuine, lawful, valid or current, and it is not an endorsement, rating or guarantee of any kind.'),
          _sectionBody('Responsibility of Taxi Drivers and Stay Owners', 'If you register as a Taxi Driver or a Stay Owner, all responsibility for the truth, validity and legality of the driving licence, date of birth, registration, GSTIN and any other detail you give, and for the vehicle or stay itself, including its documents, permits, fitness, insurance and taxes, the security and well-being of passengers and guests, and compliance with every applicable law, lies fully and only with you.\n\nBakhli, its owner, its developers and its administrators carry no responsibility for any of these details, the vehicle or the stay, and are not a party to any ride, stay or other arrangement between you and another user.\n\nYou agree to indemnify and hold harmless Bakhli, its owner, its developers and its administrators against every claim, fine, penalty, loss or expense arising from these details, the vehicle, the stay, or any ride or stay you provide.\n\nBakhli may reject, hide or remove your listing, and may suspend your account, where any of these details are missing, false or no longer valid. Plan fees already paid are not refunded in such cases.'),
          _sectionBody('Personal Verification and User Safety', 'Bakhli strongly encourages every user to verify things personally. Visit and inspect a property or stay before making any payment. Check the employer and the job before accepting it. Check the driver, the vehicle and the fare before you travel. Do not make advance payments unless you are sure.\n\nAny decision to visit, meet, travel, take a job or enter into an arrangement is made entirely at your own discretion and risk.'),
          _sectionBody('Plans and Subscriptions', 'Listing on Bakhli is free on the Free plan, within its limit. Owners may choose to buy a paid plan for a higher listing limit, priority placement and other features shown in the app. Seekers and job seekers may use Bakhli free of charge. Bakhli does not charge any commission or brokerage on rent, stays, rides or salaries.'),
          _section('', [
            'Paid plans are subscriptions billed through Google Play. The price, the billing period (1, 3 or 12 months) and any offer are shown in the app and in Google Play before you buy.',
            'A subscription renews automatically at the end of each billing period until you cancel it. You can cancel at any time in Google Play (Play Store > Payments and subscriptions > Subscriptions). Cancelling stops future renewals, and your plan stays active until the end of the period you have already paid for.',
            'A free trial may be offered to eligible new customers, as shown in Google Play. If you do not cancel before the trial ends, the subscription starts at the listed price.',
            'Payments are made to and processed by Google Play. Bakhli does not receive or store your card or bank details. Any applicable taxes are shown by Google Play at the time of purchase.',
            'Bakhli does not refund a subscription when you cancel it, change your role or delete your account, or when a listing is removed or an account is suspended for breaking these Terms. Refund requests are handled under Google Play\'s policies, and Bakhli is not responsible for decisions made by Google.',
            'If a payment fails, Google Play may retry it for some time and then place the subscription on hold. Paid features stay unavailable until the payment is fixed in Google Play.',
            'When a paid plan ends, you return to the Free plan. If you have more live listings than the Free plan allows, the extra listings are paused, not deleted. Paused listings can go live again when you subscribe again.',
            'Bakhli may change plans, prices, limits or offers from time to time. Changes for existing subscribers follow Google Play\'s rules and may need your consent through Google Play.',
          ]),
          _sectionBody('Contact Visibility', 'The location and address of a listing are always visible to other users, as this is essential for people looking for accommodation. Your mobile number is displayed by default on your listings and can be hidden in your profile settings. Contact numbers on job posts and taxi listings are shown to logged-in users so that they can reach you. When contact visibility is turned off, your number and direct contact options are not shown.'),
          _sectionBody('Chat and Notifications', 'Bakhli provides a simple question-and-answer chat between users for rooms, plots and stays. You agree to receive push notifications about your account, listings, plans and activity. You can turn them off in your phone settings.'),
          _sectionBody('Your Content', 'By publishing a listing or post on Bakhli, you grant Bakhli a non-exclusive, royalty-free right to display that content to other users and to promote it within Bakhli. Ownership of your content remains with you at all times, and you may remove your listing whenever you wish.'),
          _sectionBody('Intellectual Property', 'The Bakhli name, design, layout, features and software are the property of Bakhli. Content such as photos and descriptions submitted by users remains the property of the respective user. Users must not copy, download, reproduce, distribute or make any use of content posted by other users without their explicit consent.'),
          _sectionBody('Review, Rejection and Removal', 'Bakhli reserves the right to review, approve, reject, hide or remove any listing, post or content at its sole discretion, including in response to a user report or a violation of these Terms. Where reasonably possible, a reason will be stated. Plan fees already paid are not refunded in such cases.'),
          _sectionBody('Account Suspension', 'Bakhli reserves the right to restrict or permanently discontinue access to any account found to be in violation of these Terms, or associated with conduct that is harmful to other users. Such action may be taken at any time without prior notice.'),
          _sectionBody('Scope of Responsibility', 'Bakhli\'s role is limited to enabling connections between users. Any arrangement that follows, including negotiations, agreements, payments, stays, jobs and journeys, takes place solely between the parties involved. Bakhli bears no responsibility for the outcome of any such arrangement, nor for any loss, injury, inconvenience or dispute that may arise from it.'),
          _sectionBody('Disclaimer and Limitation of Liability', 'Bakhli is provided on an "as is" and "as available" basis. To the maximum extent permitted by law, Bakhli, its owner and its developers are not liable for any indirect, incidental or consequential loss, or for any loss arising from dealings between users or from content posted by users.\n\nWhere liability cannot be excluded, it is limited to the amount you paid to Bakhli for your plan in the three months before the claim arose. Nothing in these Terms limits any right that you have under applicable law and that cannot be limited.'),
          _sectionBody('Indemnity', 'You agree to indemnify and hold harmless Bakhli, its owner and its developers from any claim, loss or expense arising from your listings, posts or content, from any licence, registration, vehicle or stay you list, or from your breach of these Terms or of any law.'),
          _sectionBody('Account Deletion', 'You can delete your account from within the app. Your listings and photos are removed. Some records are kept as explained in the Privacy Policy. Licence, date of birth, registration and GSTIN details are kept for a limited period as explained in the Privacy Policy.'),
          _sectionBody('Governing Law and Jurisdiction', 'These Terms of Service are governed by and construed in accordance with the laws of India. Any dispute, claim, or controversy arising out of or in connection with these Terms, or from the use of Bakhli, shall be subject to the exclusive jurisdiction of the competent courts of India.'),
          _sectionBody('Changes to These Terms', 'These Terms of Service may be updated from time to time. The revised version will be available within the app and on our website along with an updated date. Continued use of Bakhli following any update shall be considered acceptance of the revised terms.'),
          _sectionBody('Contact Us', 'For any questions related to these Terms, please write to us:\n\nEmail: supportbakhli@gmail.com'),
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
