import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../config/app_colors.dart';
import '../controllers/auth_controller.dart';
import '../utils/app_toast.dart';
import '../widgets/gradient_button.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _auth = Get.find<AuthController>();
  final _nameCtrl = TextEditingController();
  bool _isContactVisible = true;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = _auth.user.value?.name ?? '';
    _isContactVisible = _auth.user.value?.isContactVisible ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      AppToast.error('Name is required.');
      return;
    }
    if (name.length > 100) {
      AppToast.error('Name cannot exceed 100 characters.');
      return;
    }
    final ok = await _auth.updateProfile(name, isContactVisible: _isContactVisible);
    if (ok && mounted) _showSuccess();
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 48),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 68, height: 68,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, size: 36, color: AppColors.success),
            ),
            const SizedBox(height: 18),
            const Text('Profile Updated',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark)),
            const SizedBox(height: 8),
            const Text('Your profile has been saved successfully.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: AppColors.textMedium,
                    height: 1.5)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Get.back();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Done',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Edit Profile',
            style: TextStyle(
                fontFamily: 'Poppins', fontSize: 17, fontWeight: FontWeight.w600)),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 20,
                  offset: const Offset(0, 6))
            ],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildField('Full Name', Iconsax.user, _nameCtrl),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Contact visible to public',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMedium)),
                  const SizedBox(height: 2),
                  const Text('Show call & WhatsApp on your listings',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: AppColors.textLight)),
                ]),
              ),
              Switch(
                value: _isContactVisible,
                onChanged: (v) => setState(() => _isContactVisible = v),
                activeColor: AppColors.primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ]),
            const SizedBox(height: 28),
            Obx(() => GradientButton(
              onPressed: _auth.isLoading.value ? null : _save,
              isLoading: _auth.isLoading.value,
              label: 'Save Changes',
            )),
          ]),
        ),
      ),
    );
  }

  Widget _buildField(String label, IconData icon, TextEditingController ctrl) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textMedium)),
      const SizedBox(height: 8),
      TextFormField(
        controller: ctrl,
        style: const TextStyle(fontFamily: 'Poppins', fontSize: 15),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: AppColors.primaryLight, size: 20),
          hintText: 'Enter $label',
        ),
      ),
    ]);
  }
}
