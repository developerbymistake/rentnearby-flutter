import 'package:flutter/material.dart';
import '../design/design.dart';
import '../widgets/legal_page_3d.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LegalPage3D(
      title: 'Terms of Service',
      updated: 'Last updated: November 6, 2026',
      art: ListingArt.clipboard,
      intro: 'By using Bakhli, you agree to these Terms of Service. Please read them carefully before proceeding.',
      caption: '© 2026 Bakhli. All rights reserved.',
      sections: [
          _sb('About Bakhli', 'Bakhli is a digital platform that helps travellers in India plan trips, find stays, local taxis and jobs at stays, and get in touch with hosts, drivers and other users directly.\n\nBakhli is only an intermediary that facilitates information and communication between users. Bakhli is not an agent, employer, hotel, travel agency, tour operator or taxi operator, and does not itself provide any stay, ride, job or travel service. All stay, ride, job and travel arrangements, including enquiries, offers, bookings, agreements and payments, take place directly and only between the users concerned.'),
          _sb('Eligibility', 'Bakhli is designed for individuals who are 18 years of age or older. By creating an account, you confirm that you meet this age requirement.'),
          _sb('Your Account and Role', 'Each mobile number may be linked to one Bakhli account. You are solely responsible for the security and activity of your account. Sign-in is completed with a one-time password.\n\nWhen you first sign in you choose one role: Seeker, Stay Owner or Taxi Driver. An account has one role at a time. A change of role is subject to the options available in the app and to approval by Bakhli, and may remove the content linked to your earlier role.'),
          _sp('Listing and Posting Rules', [
            'All details must be accurate, complete and a truthful representation of the stay, vehicle or job.',
            'Photos must be genuine images of what is being listed.',
            'Each stay, vehicle or job may be listed only once, and you must have the right to list it.',
            'Listings must be real and located within India.',
            'Taxi Drivers must hold a valid driving licence of the class needed to drive a transport vehicle, and a valid registration, permit, fitness certificate and insurance for the vehicle. They must give true and correct identity, licence and vehicle details.',
            'Stay Owners must hold every registration, licence or permission their stay needs under local, state and central law, and must give true and correct registration and tax details.',
            'Job posts must be genuine and lawful, must be posted by the employer or its authorised person, and must not ask candidates for money or fees of any kind.',
            'Where the app allows it, you can control the visibility of your contact information in your profile settings.',
          ]),
          _sp('Prohibited Conduct', [
            'Submitting false, inaccurate or misleading information.',
            'Creating multiple accounts or misrepresenting your identity.',
            'Entering or sharing another person\'s personal details without their permission.',
            'Copying or extracting content from Bakhli without prior written consent.',
            'Using the contact details of other users for anything other than the purpose for which they were shared.',
            'Spam, harassment, threats, or conduct that is harmful or disrespectful toward other users.',
            'Using Bakhli for any unlawful purpose, or for any purpose unrelated to planning trips or finding or offering stays, rides or jobs.',
          ]),
          _sb('Listings, Jobs and Taxi Information', 'All stays, job posts and taxi details on Bakhli are published by the users themselves. Their accuracy, completeness and availability are the sole responsibility of the user who posted them. Bakhli does not inspect, authenticate or endorse any stay, host, employer, driver, vehicle, licence or job offer, or the information they contain.\n\nBakhli may ask Taxi Drivers and Stay Owners for identity, licence, registration or tax details and may review them. Any such review is limited. It is not a confirmation that a licence, registration, vehicle, stay or person is genuine, lawful, valid or current, and it is not an endorsement, rating or guarantee of any kind.'),
          _sb('Trip Planner and Map Information', 'Trip plans, day plans, maps, places, routes, distances, travel times, fares and other trip information in Bakhli are suggestions only. They may come in part from third-party and open data sources and may be incomplete, inaccurate or out of date. Check road, weather and local conditions yourself before you travel. You use this information at your own discretion and risk.'),
          _sb('Enquiries, Bookings and Payments', 'Enquiries, offers, replies and booking details exchanged in Bakhli are communications between users. A booking or any other arrangement is made only between the traveller and the host or driver concerned.\n\nAny payment for a stay, a ride or a job, including any advance, is made directly between the users concerned, outside Bakhli. Bakhli is not a party to such payments and is not responsible for any payment, refund, cancellation or dispute between users.\n\nIf you enter another person\'s details, such as a host\'s phone number, you must have the right to share them.'),
          _sb('Responsibility of Taxi Drivers and Stay Owners', 'If you register as a Taxi Driver or a Stay Owner, all responsibility for the truth, validity and legality of the identity, licence, registration, tax and any other details you give, and for the vehicle or stay itself, including its documents, permits, fitness, insurance and taxes, the security and well-being of passengers and guests, any payment you ask for or receive, and compliance with every applicable law, lies fully and only with you.\n\nBakhli, its owner, its developers and its administrators carry no responsibility for any of these details, the vehicle or the stay, and are not a party to any ride, stay or other arrangement between you and another user.\n\nYou agree to indemnify and hold harmless Bakhli, its owner, its developers and its administrators against every claim, fine, penalty, loss or expense arising from these details, the vehicle, the stay, or any ride or stay you provide.\n\nBakhli may reject, hide or remove your listing, and may suspend your account, where any of these details are missing, false or no longer valid. Plan fees already paid are not refunded in such cases.'),
          _sb('Check Before You Pay or Travel', 'Bakhli strongly encourages every user to check things personally. Check the stay, the host, the driver, the vehicle and the fare before you pay any advance or travel. Check the employer and the job before accepting it. Do not make advance payments unless you are sure.\n\nAny decision to visit, meet, travel, pay, take a job or enter into an arrangement is made entirely at your own discretion and risk.'),
          _sbp('Plans and Subscriptions', 'Stay Owners and Taxi Drivers may choose a paid plan with the features shown in the app.', [
            'Paid plans are subscriptions bought through the app store. The price, the billing period and any offer are shown before you buy.',
            'A subscription renews automatically at the end of each billing period until you cancel it. You can cancel at any time in the subscription settings of the app store you used. Cancelling stops future renewals, and your plan stays active until the end of the period you have already paid for.',
            'A trial may be offered to eligible users, as shown at the time of purchase. If you do not cancel before the trial ends, the subscription starts at the listed price.',
            'Payments are made to and processed by the app store under its own terms. Any applicable taxes are shown at the time of purchase.',
            'Bakhli does not refund a subscription when you cancel it, change your role or delete your account, or when a listing is removed or an account is suspended for breaking these Terms. Refund requests are handled under the app store\'s policies, and Bakhli is not responsible for decisions made by the app store.',
            'If a payment fails, the app store may retry it for some time and then place the subscription on hold. Paid features stay unavailable until the payment is fixed.',
            'When a paid plan ends, its paid features are no longer available.',
            'Bakhli may change plans, prices, features or offers from time to time. Changes for existing subscribers follow the app store\'s rules.',
          ]),
          _sb('Contact Visibility', 'Stays and taxi listings show the information travellers need to find and contact the owner, such as location, photos and prices. Depending on your settings and the feature used, your name and contact numbers may be shown to other users. When you send an enquiry or a booking request, your name and contact details may be shared with the host or driver concerned.'),
          _sb('Chat and Notifications', 'Bakhli provides in-app chat between users, including messages for enquiries, offers and bookings. Messages may remain available to the other user. You agree to receive push notifications about your account, trips, enquiries, plans and activity. You can turn them off in your phone settings.'),
          _sb('Your Content', 'By publishing a stay, a taxi or a post on Bakhli, you grant Bakhli a non-exclusive, royalty-free right to display that content to other users and to promote it within Bakhli. Ownership of your content remains with you, and you may remove your content where the app allows.'),
          _sb('Intellectual Property', 'The Bakhli name, design, layout, features and software are the property of Bakhli. Content such as photos and descriptions submitted by users remains the property of the respective user. Users must not copy, download, reproduce, distribute or make any use of content posted by other users without their explicit consent.'),
          _sb('Review, Rejection and Removal', 'Bakhli reserves the right to review, approve, reject, hide or remove any listing, post or content at its sole discretion, including in response to a user report or a violation of these Terms. A reason may be given where reasonably possible. Plan fees already paid are not refunded in such cases.'),
          _sb('Account Suspension', 'Bakhli reserves the right to restrict or permanently discontinue access to any account found to be in violation of these Terms, or associated with conduct that is harmful to other users. Such action may be taken at any time without prior notice.'),
          _sb('Scope of Responsibility', 'Bakhli\'s role is limited to providing information and enabling communication between users. Any arrangement that follows, including enquiries, bookings, agreements, payments, stays, rides, jobs and journeys, takes place solely between the parties involved. Bakhli bears no responsibility for the outcome of any such arrangement, nor for any loss, injury, delay, inconvenience or dispute that may arise from it.'),
          _sb('Disclaimer and Limitation of Liability', 'Bakhli is provided on an "as is" and "as available" basis. Bakhli makes no warranty about the availability, prices or quality of any stay, ride or job, the accuracy of maps, places, distances, routes, travel times or other trip information, any content posted by users or taken from third parties, or the conduct of any user.\n\nTo the maximum extent permitted by law, Bakhli, its owner, its developers and its administrators are not liable for any indirect, incidental or consequential loss, or for any loss arising from dealings between users, from content posted by users, or from trip information.\n\nWhere liability cannot be excluded, it is limited to the amount you paid to Bakhli for your plan in the three months before the claim arose. Nothing in these Terms limits any right that you have under applicable law and that cannot be limited.'),
          _sb('Indemnity', 'You agree to indemnify and hold harmless Bakhli, its owner, its developers and its administrators from any claim, loss or expense arising from your listings, posts, enquiries, bookings or content, from any licence, registration, vehicle or stay you list, from any arrangement or payment between you and another user, or from your breach of these Terms or of any law.'),
          _sb('Account Deletion', 'You can delete your account from within the app. Some information may be kept after deletion, as explained in the Privacy Policy.'),
          _sb('Governing Law and Jurisdiction', 'These Terms of Service are governed by and construed in accordance with the laws of India. Any dispute, claim, or controversy arising out of or in connection with these Terms, or from the use of Bakhli, shall be subject to the exclusive jurisdiction of the competent courts of India.'),
          _sb('Changes to These Terms', 'These Terms of Service may be updated from time to time. The revised version will be available within the app and on our website along with an updated date. Continued use of Bakhli following any update shall be considered acceptance of the revised terms.'),
          _sb('Contact Us', 'For any questions related to these Terms, please write to us:\n\nEmail: supportbakhli@gmail.com'),
      ],
    );
  }

  LegalSectionData _sb(String title, String body) => LegalSectionData(title, body: body);

  LegalSectionData _sp(String title, List<String> points) => LegalSectionData(title, bullets: points);

  LegalSectionData _sbp(String title, String body, List<String> points) =>
      LegalSectionData(title, body: body, bullets: points);
}
