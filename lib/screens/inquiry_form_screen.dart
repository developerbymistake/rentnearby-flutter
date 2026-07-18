import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../config/app_colors.dart';
import '../config/app_insets.dart';
import '../config/app_routes.dart';
import '../controllers/auth_controller.dart';
import '../controllers/inquiry_controller.dart';
import '../models/service_package_model.dart';
import '../utils/app_toast.dart';
import '../utils/input_formatters.dart';
import '../widgets/gradient_button.dart';
import '../widgets/max_width_content.dart';
import '../widgets/service_package_price.dart';

/// Full pushed screen (per AppRoutes.inquiryForm), pre-filled with the
/// selected Service+Package header from the Package List tap. Submitting
/// funnels the create response through InquiryController.applyStatusUpdate
/// (see submitInquiry) and replaces this screen with Confirmation — never
/// leaves a submitted form on the back stack.
class InquiryFormScreen extends StatefulWidget {
  const InquiryFormScreen({super.key});

  @override
  State<InquiryFormScreen> createState() => _InquiryFormScreenState();
}

class _InquiryFormScreenState extends State<InquiryFormScreen> {
  final _inquiryCtrl = Get.find<InquiryController>();
  final _auth = Get.find<AuthController>();
  final _formKey = GlobalKey<FormState>();

  String _serviceId = '';
  String _serviceName = '';
  ServicePackageModel? _package;

  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _peopleCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  final _dateDisplayCtrl = TextEditingController();
  DateTime? _preferredDate;
  bool _agreedToTerms = false;

  @override
  void initState() {
    super.initState();
    final args = (Get.arguments as Map?) ?? const {};
    _serviceId = args['serviceId'] as String? ?? '';
    _serviceName = args['serviceName'] as String? ?? '';
    final package = args['package'];
    if (package is ServicePackageModel) _package = package;
    _nameCtrl.text = _auth.user.value?.name ?? '';
    _mobileCtrl.text = _auth.user.value?.phoneNumber ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _peopleCtrl.dispose();
    _messageCtrl.dispose();
    _dateDisplayCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _preferredDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 730)),
    );
    if (picked != null) {
      setState(() {
        _preferredDate = picked;
        _dateDisplayCtrl.text = _formatDate(picked);
      });
    }
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final package = _package;
    if (package == null || _serviceId.isEmpty) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_agreedToTerms) {
      AppToast.error('Please agree to be contacted to continue.');
      return;
    }
    final peopleText = _peopleCtrl.text.trim();
    final numberOfPeople = peopleText.isEmpty ? null : int.tryParse(peopleText);

    final detail = await _inquiryCtrl.submitInquiry(
      serviceId: _serviceId,
      servicePackageId: package.id,
      fullName: _nameCtrl.text.trim(),
      mobile: _mobileCtrl.text.trim(),
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      preferredDateOrTripStart: _preferredDate,
      numberOfPeople: numberOfPeople,
      message: _messageCtrl.text.trim().isEmpty ? null : _messageCtrl.text.trim(),
      agreedToTerms: _agreedToTerms,
    );
    if (detail != null && mounted) {
      Get.offNamed(AppRoutes.inquiryConfirmation, arguments: {'detail': detail});
    }
  }

  InputDecoration _inputDec(String hint, {Widget? prefixIcon, Widget? suffixIcon}) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textHint),
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.error)),
      );

  @override
  Widget build(BuildContext context) {
    if (_package == null || _serviceId.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.scaffoldBg,
        body: Column(
          children: [
            _buildHeader(),
            const Expanded(
              child: Center(
                child: Text('This inquiry link is invalid.', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight)),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: MaxWidthContent(
                child: Form(
                  key: _formKey,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPackageSummary(_package!),
                        const SizedBox(height: 18),
                        _fieldLabel('Full Name *'),
                        TextFormField(
                          controller: _nameCtrl,
                          inputFormatters: noEmojiInputFormatters,
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
                          decoration: _inputDec('Your full name', prefixIcon: const Icon(Iconsax.user, size: 18, color: AppColors.textLight)),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                        ),
                        const SizedBox(height: 16),
                        _fieldLabel('Mobile Number *'),
                        TextFormField(
                          controller: _mobileCtrl,
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
                          decoration: _inputDec('10-digit mobile number', prefixIcon: const Icon(Iconsax.call, size: 18, color: AppColors.textLight)).copyWith(counterText: ''),
                          validator: (v) {
                            final t = v?.trim() ?? '';
                            if (t.isEmpty) return 'Mobile number is required';
                            if (t.length != 10) return 'Enter a valid 10-digit number';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _fieldLabel('Email (Optional)'),
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          inputFormatters: noEmojiInputFormatters,
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
                          decoration: _inputDec('you@example.com', prefixIcon: const Icon(Iconsax.sms, size: 18, color: AppColors.textLight)),
                          validator: (v) {
                            final t = v?.trim() ?? '';
                            if (t.isEmpty) return null;
                            if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) return 'Enter a valid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _fieldLabel('Preferred Date / Trip Start (Optional)'),
                        TextFormField(
                          controller: _dateDisplayCtrl,
                          readOnly: true,
                          onTap: _pickDate,
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
                          decoration: _inputDec(
                            'Select a date',
                            prefixIcon: const Icon(Iconsax.calendar_1, size: 18, color: AppColors.textLight),
                            suffixIcon: _preferredDate != null
                                ? IconButton(
                                    icon: const Icon(Iconsax.close_circle, size: 18, color: AppColors.textLight),
                                    onPressed: () => setState(() {
                                      _preferredDate = null;
                                      _dateDisplayCtrl.clear();
                                    }),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _fieldLabel('Number of People (Optional)'),
                        TextFormField(
                          controller: _peopleCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
                          decoration: _inputDec('e.g. 4', prefixIcon: const Icon(Iconsax.profile_2user, size: 18, color: AppColors.textLight)),
                          validator: (v) {
                            final t = v?.trim() ?? '';
                            if (t.isEmpty) return null;
                            final n = int.tryParse(t);
                            if (n == null || n <= 0) return 'Enter a valid number';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _fieldLabel('Message (Optional)'),
                        TextFormField(
                          controller: _messageCtrl,
                          maxLines: 4,
                          maxLength: 500,
                          inputFormatters: noEmojiInputFormatters,
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
                          decoration: _inputDec('Tell us anything specific about your requirement...'),
                        ),
                        const SizedBox(height: 6),
                        _buildTermsCheckbox(),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _fieldLabel(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(label, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textDark)),
      );

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 20, 18),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Get.back(),
                icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
              ),
              const Expanded(
                child: Text(
                  'Submit an Inquiry',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 19, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPackageSummary(ServicePackageModel package) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.8)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 54,
              height: 54,
              child: package.thumbnailUrl.isEmpty
                  ? Container(color: AppColors.surface, child: const Icon(Iconsax.gallery, color: AppColors.primaryLight, size: 20))
                  : CachedNetworkImage(
                      imageUrl: package.thumbnailUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: AppColors.surface),
                      errorWidget: (_, __, ___) => Container(color: AppColors.surface, child: const Icon(Iconsax.gallery, color: AppColors.primaryLight, size: 20)),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_serviceName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textLight)),
                const SizedBox(height: 2),
                Text(package.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textDark)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ServicePackagePrice(
            price: package.price,
            originalPrice: package.originalPrice,
            discountPercent: package.discountPercent,
            isStartingAtPrice: package.isStartingAtPrice,
            priceUnit: package.priceUnit,
            priceFontSize: 14,
            priceColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildTermsCheckbox() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: _agreedToTerms,
            onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
            activeColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
            child: const Text(
              'I agree to be contacted regarding this inquiry and confirm the details above are correct.',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight, height: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + AppInsets.bottomViewPadding(context)),
      child: Obx(() => GradientButton(
            onPressed: _inquiryCtrl.isSubmitting.value ? null : _submit,
            isLoading: _inquiryCtrl.isSubmitting.value,
            label: 'Submit Inquiry',
          )),
    );
  }
}
