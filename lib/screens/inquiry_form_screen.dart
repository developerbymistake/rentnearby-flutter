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
import '../utils/app_date_format.dart';
import '../utils/app_toast.dart';
import '../utils/inquiry_form_fields.dart';
import '../utils/input_formatters.dart';
import '../widgets/gradient_button.dart';
import '../widgets/inquiry_contact_sheet.dart';
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
  // Which of Preferred-Date/Number-of-People to show and how to label them — driven by the
  // category's FormType (see inquiry_form_fields.dart). Falls back to Travel's shape if missing.
  InquiryFormFieldConfig _fieldConfig = inquiryFormFieldConfigFor(null);

  // Full Name/Mobile are no longer typed — they come from the account by default, or from this
  // override once the user taps "Not you?" and saves an alternate contact for this one inquiry.
  InquiryContact? _contactOverride;

  final _peopleCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  final _dateDisplayCtrl = TextEditingController();
  DateTime? _preferredDate;
  bool _agreedToTerms = false;

  String get _effectiveName =>
      _contactOverride?.name ?? _auth.user.value?.name?.trim() ?? '';
  String get _effectiveMobile =>
      _contactOverride?.mobile ?? (_auth.user.value?.phoneNumber ?? '').trim();

  @override
  void initState() {
    super.initState();
    final args = (Get.arguments as Map?) ?? const {};
    _serviceId = args['serviceId'] as String? ?? '';
    _serviceName = args['serviceName'] as String? ?? '';
    _fieldConfig = inquiryFormFieldConfigFor(args['formType'] as String?);
    final package = args['package'];
    if (package is ServicePackageModel) _package = package;
  }

  @override
  void dispose() {
    _peopleCtrl.dispose();
    _messageCtrl.dispose();
    _dateDisplayCtrl.dispose();
    super.dispose();
  }

  Future<void> _openContactSheet() async {
    final result = await InquiryContactSheet.show(
      context,
      initialName: _effectiveName,
      initialMobile: _effectiveMobile,
    );
    if (result != null) setState(() => _contactOverride = result);
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
        // UTC-tagged, not converted: this is a pure calendar date with no meaningful
        // time-of-day. A real .toUtc() conversion would roll the date back a day for any
        // positive-UTC-offset user (e.g. India, UTC+5:30) once local midnight crosses to the
        // previous UTC day. Tagging the same y/m/d as UTC satisfies the backend's
        // `timestamp with time zone` column without shifting which date was actually picked.
        _preferredDate = DateTime.utc(picked.year, picked.month, picked.day);
        _dateDisplayCtrl.text = AppDateFormat.date(picked);
      });
    }
  }

  Future<void> _onSubmitPressed() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final package = _package;
    if (package == null || _serviceId.isEmpty) return;
    if (_effectiveName.isEmpty || _effectiveMobile.length != 10) {
      AppToast.error('Please add your name and mobile number to continue.');
      await _openContactSheet();
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_agreedToTerms) {
      AppToast.error('Please agree to be contacted to continue.');
      return;
    }
    final confirmed = await _confirmSubmitDialog();
    if (confirmed == true) await _submit();
  }

  // Same rounded Dialog + icon-circle + Row-of-two-Expanded-buttons shape as
  // ProfileScreen._confirmLogout(), re-themed to primary (not destructive) since
  // submitting an inquiry isn't a destructive action.
  Future<bool?> _confirmSubmitDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 36),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Iconsax.send_2,
                  size: 28,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Submit Inquiry?',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please confirm your details are correct. Our team will reach out to you soon.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: AppColors.textMedium,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textMedium,
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Confirm',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final package = _package!;
    final peopleText = _peopleCtrl.text.trim();
    final numberOfPeople = peopleText.isEmpty ? null : int.tryParse(peopleText);

    final detail = await _inquiryCtrl.submitInquiry(
      serviceId: _serviceId,
      servicePackageId: package.id,
      fullName: _effectiveName,
      mobile: _effectiveMobile,
      preferredDateOrTripStart: _preferredDate,
      numberOfPeople: numberOfPeople,
      message: _messageCtrl.text.trim().isEmpty
          ? null
          : _messageCtrl.text.trim(),
      agreedToTerms: _agreedToTerms,
    );
    if (detail != null && mounted) {
      Get.offNamed(
        AppRoutes.inquiryConfirmation,
        arguments: {'detail': detail},
      );
    }
  }

  InputDecoration _inputDec(
    String hint, {
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(
      fontFamily: 'Poppins',
      fontSize: 14,
      color: AppColors.textHint,
    ),
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: AppColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.divider),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.error),
    ),
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
                child: Text(
                  'This inquiry link is invalid.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: AppColors.textLight,
                  ),
                ),
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
              child: Form(
                key: _formKey,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPackageSummary(_package!),
                      const SizedBox(height: 14),
                      _buildIdentityStrip(),
                      if (_fieldConfig.dateLabel != null) ...[
                        const SizedBox(height: 16),
                        _fieldLabel('${_fieldConfig.dateLabel} (Optional)'),
                        TextFormField(
                          controller: _dateDisplayCtrl,
                          readOnly: true,
                          onTap: _pickDate,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                          ),
                          decoration: _inputDec(
                            'Select a date',
                            prefixIcon: const Icon(
                              Iconsax.calendar_1,
                              size: 18,
                              color: AppColors.textLight,
                            ),
                            suffixIcon: _preferredDate != null
                                ? IconButton(
                                    icon: const Icon(
                                      Iconsax.close_circle,
                                      size: 18,
                                      color: AppColors.textLight,
                                    ),
                                    onPressed: () => setState(() {
                                      _preferredDate = null;
                                      _dateDisplayCtrl.clear();
                                    }),
                                  )
                                : null,
                          ),
                        ),
                      ],
                      if (_fieldConfig.peopleLabel != null) ...[
                        const SizedBox(height: 16),
                        _fieldLabel('${_fieldConfig.peopleLabel} (Optional)'),
                        TextFormField(
                          controller: _peopleCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(3),
                          ],
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                          ),
                          decoration: _inputDec(
                            'e.g. 4',
                            prefixIcon: const Icon(
                              Iconsax.profile_2user,
                              size: 18,
                              color: AppColors.textLight,
                            ),
                          ),
                          validator: (v) {
                            final t = v?.trim() ?? '';
                            if (t.isEmpty) return null;
                            final n = int.tryParse(t);
                            if (n == null || n <= 0)
                              return 'Enter a valid number';
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 16),
                      _fieldLabel('Message (Optional)'),
                      TextFormField(
                        controller: _messageCtrl,
                        maxLines: 4,
                        maxLength: 500,
                        inputFormatters: noEmojiInputFormatters,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                        ),
                        decoration: _inputDec(
                          'Tell us anything specific about your requirement...',
                        ),
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
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _fieldLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      label,
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: AppColors.textDark,
      ),
    ),
  );

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
                icon: const Icon(
                  Icons.arrow_back_ios_rounded,
                  color: Colors.white,
                ),
              ),
              const Expanded(
                child: Text(
                  'Submit an Inquiry',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
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
                  ? Container(
                      color: AppColors.surface,
                      child: const Icon(
                        Iconsax.gallery,
                        color: AppColors.primaryLight,
                        size: 20,
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: package.thumbnailUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: AppColors.surface),
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.surface,
                        child: const Icon(
                          Iconsax.gallery,
                          color: AppColors.primaryLight,
                          size: 20,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _serviceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  package.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: ServicePackagePrice(
                price: package.price,
                originalPrice: package.originalPrice,
                discountPercent: package.discountPercent,
                isStartingAtPrice: package.isStartingAtPrice,
                priceUnit: package.priceUnit,
                priceFontSize: 14,
                priceColor: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityStrip() {
    final accountName = _auth.user.value?.name?.trim() ?? '';
    final accountMobile = (_auth.user.value?.phoneNumber ?? '').trim();
    final override = _contactOverride;

    // Account has no name yet (phone-only OTP login, never set a display name) and no override
    // has been saved — nothing trustworthy to show, so prompt instead of a blank/broken row.
    if (override == null && accountName.isEmpty) {
      return GestureDetector(
        onTap: _openContactSheet,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Iconsax.user, size: 18, color: AppColors.error),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Add your name & mobile number to continue',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12,
                color: AppColors.error,
              ),
            ],
          ),
        ),
      );
    }

    final name = override?.name ?? accountName;
    final mobile = override?.mobile ?? accountMobile;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.8)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary,
            child: Text(
              initial,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    if (override != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'For someone else',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  "We'll contact ${override != null ? 'them' : 'you'} on $mobile",
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: override != null
                ? () => setState(() => _contactOverride = null)
                : _openContactSheet,
            child: Text(
              override != null ? 'Use my account' : 'Not you?',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                decoration: TextDecoration.underline,
              ),
            ),
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
            child: const Text(
              'I agree to be contacted regarding this inquiry and confirm the details above are correct.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: AppColors.textLight,
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12 + AppInsets.bottomViewPadding(context),
      ),
      child: Obx(
        () => GradientButton(
          onPressed: (_inquiryCtrl.isSubmitting.value || !_agreedToTerms)
              ? null
              : _onSubmitPressed,
          isLoading: _inquiryCtrl.isSubmitting.value,
          label: 'Submit Inquiry',
        ),
      ),
    );
  }
}
