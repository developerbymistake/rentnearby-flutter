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
          _updated('Last updated: June 2, 2026'),
          const SizedBox(height: 12),
          _body(
            'By using Bakhli, you agree to these Terms of Service. Please read them carefully before proceeding.',
          ),
          _sectionBody(
            'About Bakhli',
            'Bakhli helps property owners reach genuine prospective tenants by giving their listings visibility to people actively searching for accommodation nearby. For those looking for a place to stay, Bakhli makes it simple to discover available rooms and plots in their area — with the ability to view photos, location, rent, and contact the owner directly.\n\nBakhli is a digital service that enables property owners across India to list rental accommodation and allows individuals to discover properties available near them. Bakhli is neither a broker nor an agent. All rental arrangements, negotiations, and agreements take place directly and exclusively between the property owner and the prospective tenant.',
          ),
          _sectionBody(
            'Eligibility',
            'Bakhli is designed for individuals who are 18 years of age or older. By creating an account, you confirm that you meet this age requirement.',
          ),
          _sectionBody(
            'Your Account',
            'Each mobile number may be linked to one Bakhli account. You are solely responsible for the security and activity of your account. Only one active session is permitted at a time — signing in on a new device will automatically end your existing session. Account verification is completed via a one-time password sent through WhatsApp.',
          ),
          _section(
            'Listing Rules',
            [
              'All listing details must be accurate, complete, and a truthful representation of the property.',
              'Photos submitted must be genuine images of the property being listed.',
              'Each property may only be listed once.',
              'Listings must represent actual rental properties located within India.',
              'The visibility of your contact information on a listing is entirely within your control and can be updated at any time through your profile settings.',
            ],
          ),
          _section(
            'Prohibited Conduct',
            [
              'Submitting listings that contain false, inaccurate, or misleading information.',
              'Creating multiple accounts or misrepresenting your identity.',
              'Reproducing or extracting any content from Bakhli without prior written consent.',
              'Using Bakhli for any purpose unrelated to listing or discovering rental accommodation.',
              'Engaging in conduct that is harmful, threatening, or disrespectful toward other users.',
            ],
          ),
          _sectionBody(
            'Listings and Property Information',
            'All listings on Bakhli are published solely by the property owners themselves. The accuracy, completeness, and current availability of any listing — including photos, rent details, address, and property conditions — are entirely the responsibility of the owner who has submitted them. Bakhli does not inspect, authenticate, or endorse any listing or the information it contains. Users are encouraged to conduct their own assessment before making any decisions based on a listing.',
          ),
          _sectionBody(
            'Personal Verification and User Safety',
            'Bakhli strongly encourages all users to personally visit and inspect any property before entering into any agreement or making any payment to a property owner. Listing details are provided by owners and have not been independently verified. Any decision to visit a property, meet an owner in person, or proceed with a rental arrangement is made entirely at the user\'s own discretion and judgement. Bakhli has no involvement in, and accepts no responsibility for, any interaction, meeting, or transaction that takes place between users outside of Bakhli.',
          ),
          _sectionBody(
            'Paid Memberships',
            'Certain features within Bakhli require a paid membership. Membership fees are charged for access to those features and are non-refundable once activated. Activation of a membership does not carry any assurance of responses, inquiries, or rental agreements. All outcomes remain dependent on individual user interest and prevailing conditions. Payments are processed in Indian Rupees (INR) through a third-party payment service. Bakhli does not store your card or bank account details.',
          ),
          _sectionBody(
            'Contact Visibility',
            'Property owners retain complete control over the visibility of their contact information. Your mobile number will only be displayed to other users if you have chosen to make it visible through your profile settings. Bakhli presents contact details strictly in accordance with the preference you have set.',
          ),
          _sectionBody(
            'Your Content',
            'By publishing a listing on Bakhli, you grant Bakhli a non-exclusive, royalty-free right to display that content to other users. Ownership of your content remains with you at all times, and you may remove your listing whenever you wish.',
          ),
          _sectionBody(
            'Intellectual Property',
            'All content available on Bakhli — including its design, layout, and features — is the property of Bakhli. Listing content such as photos and descriptions submitted by users remains the property of the respective user who submitted it. Users are expressly prohibited from copying, downloading, reproducing, distributing, or making any use of content posted by other users without the explicit consent of the original owner. Any unauthorised use of content found on Bakhli may result in immediate account suspension.',
          ),
          _sectionBody(
            'Account Suspension',
            'Bakhli reserves the right to restrict or permanently discontinue access to any account found to be in violation of these Terms, or associated with conduct that is harmful to other users. Such action may be taken at any time without prior notice.',
          ),
          _sectionBody(
            'Scope of Responsibility',
            'Bakhli\'s role is limited to enabling connections between property owners and individuals seeking rental accommodation. Any arrangement that follows — including negotiations, agreements, and financial transactions — takes place solely between the parties involved. Bakhli bears no responsibility for the outcome of any such arrangement, nor for any loss, inconvenience, or dispute that may arise from it.',
          ),
          _sectionBody(
            'Governing Law and Jurisdiction',
            'These Terms of Service are governed by and construed in accordance with the laws of India. Any dispute, claim, or controversy arising out of or in connection with these Terms, or from the use of Bakhli, shall be subject to the exclusive jurisdiction of the competent courts of India.',
          ),
          _sectionBody(
            'Changes to These Terms',
            'These Terms of Service may be updated from time to time. The revised version will be available within the app along with an updated date. Continued use of Bakhli following any update shall be considered acceptance of the revised terms.',
          ),
          _sectionBody(
            'Contact Us',
            'For any questions related to these Terms, please write to us at:\n\nEmail: supportbakhli@gmail.com',
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
