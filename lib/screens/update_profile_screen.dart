import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../config/app_colors.dart';
import '../controllers/auth_controller.dart';
import '../utils/app_toast.dart';
import '../widgets/gradient_button.dart';

class UpdateProfileScreen extends StatefulWidget {
  const UpdateProfileScreen({super.key});

  @override
  State<UpdateProfileScreen> createState() => _UpdateProfileScreenState();
}

class _UpdateProfileScreenState extends State<UpdateProfileScreen> {
  final _auth = Get.find<AuthController>();
  late final TextEditingController _nameCtrl;
  late final RxBool _isContactVisible;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: _auth.profileName.value);
    _isContactVisible = (_auth.user.value?.isContactVisible ?? true).obs;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      AppToast.error('Name is required.');
      return;
    }
    if (name.length > 100) {
      AppToast.error('Name cannot exceed 100 characters.');
      return;
    }
    final ok = await _auth.updateProfile(
      name,
      isContactVisible: _isContactVisible.value,
    );
    if (ok && mounted) {
      AppToast.success('Profile updated');
      Get.back();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FF),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: Get.back,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text(
          'Update Profile',
          style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name field
                  _label('Full Name'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    maxLength: 100,
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: 'Your full name',
                      hintStyle: const TextStyle(
                          fontFamily: 'Poppins', color: AppColors.textHint),
                      prefixIcon: const Icon(Iconsax.user,
                          color: AppColors.primaryLight, size: 20),
                    ),
                    onFieldSubmitted: (_) => _save(),
                  ),
                  const SizedBox(height: 28),

                  // Contact visibility
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Iconsax.eye,
                              color: AppColors.primaryLight, size: 20),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Contact visible to public',
                                  style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textDark)),
                              SizedBox(height: 2),
                              Text('Show call & WhatsApp on your listings',
                                  style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 11,
                                      color: AppColors.textLight)),
                            ],
                          ),
                        ),
                        Obx(() => Switch(
                          value: _isContactVisible.value,
                          onChanged: (v) => _isContactVisible.value = v,
                          activeThumbColor: AppColors.primary,
                          activeTrackColor: AppColors.primaryLight,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildSaveButton(),
        ],
      ),
    );
  }


  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textMedium),
      );

  Widget _buildSaveButton() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4)),
        ],
      ),
      child: Obx(() => GradientButton(
        onPressed: _auth.isLoading.value ? null : _save,
        isLoading: _auth.isLoading.value,
        label: 'Save Profile',
      )),
    );
  }
}
