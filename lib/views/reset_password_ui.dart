import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import 'widgets/snack_message.dart';
import 'widgets/colors.dart';
import 'login_ui.dart';

class ResetPasswordUi extends StatefulWidget {
  const ResetPasswordUi({Key? key}) : super(key: key);

  @override
  State<ResetPasswordUi> createState() => _ResetPasswordUiState();
}

class _ResetPasswordUiState extends State<ResetPasswordUi> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _hasValidRecoverySession = false;

  @override
  void initState() {
    super.initState();
    _checkRecoverySession();
  }

  void _checkRecoverySession() {
    // Check if we have a valid recovery session
    final session = Supabase.instance.client.auth.currentSession;

    if (session != null) {
      final user = session.user;
      debugPrint('Reset Password - User ID: ${user.id}');
      debugPrint('Reset Password - Recovery sent at: ${user.recoverySentAt}');

      // Check if this is a recent recovery session
      if (user.recoverySentAt != null) {
        final recoverySentAt = DateTime.parse(user.recoverySentAt!);
        final now = DateTime.now();
        final difference = now.difference(recoverySentAt);

        debugPrint('Recovery sent ${difference.inMinutes} minutes ago');

        if (difference.inMinutes < 60) {
          setState(() {
            _hasValidRecoverySession = true;
          });
          debugPrint('Valid recovery session found');
          return;
        }
      }
    }

    // No valid recovery session
    debugPrint('No valid recovery session found');
    setState(() {
      _hasValidRecoverySession = false;
    });

    // Show error and redirect to login
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        SnackMessage.showError(
          context,
          'ลิงก์รีเซ็ตรหัสผ่านไม่ถูกต้องหรือหมดอายุ',
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginUi()),
        );
      }
    });
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xff10B981), size: 30),
            SizedBox(width: 10),
            Text('เปลี่ยนรหัสผ่านสำเร็จ'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'รหัสผ่านของคุณได้รับการเปลี่ยนแปลงเรียบร้อยแล้ว',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 15),
            Text(
              'กรุณาเข้าสู่ระบบด้วยรหัสผ่านใหม่',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginUi()),
                (route) => false,
              );
            },
            child: const Text(
              'ไปหน้าเข้าสู่ระบบ',
              style: TextStyle(color: Color(0xff10B981), fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await AuthService.updatePassword(
        newPassword: _newPasswordController.text,
      );

      if (mounted) {
        setState(() => _isLoading = false);

        if (result['success']) {
          // Sign out user after successful password reset
          await AuthService.signOut();
          debugPrint('เปลี่ยนรหัสผ่านสำเร็จ, ลงชื่อออกเรียบร้อย');

          SnackMessage.showSuccess(context, result['message']);
          // Show success dialog and navigate to login
          _showSuccessDialog();
        } else {
          SnackMessage.showError(context, result['message']);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        SnackMessage.showError(context, 'เกิดข้อผิดพลาด: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading state while checking session
    if (!_hasValidRecoverySession) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                'กำลังตรวจสอบสิทธิ์...',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back Button (disabled during recovery)
                IconButton(
                  icon: Icon(Icons.arrow_back_ios_new, color: Colors.grey[400]),
                  onPressed: null, // Disable back button during password reset
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(height: 24),

                // Header
                Center(
                  child: Column(
                    children: [
                      // Icon
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.lock_reset_rounded,
                          size: 64,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Title
                      const Text(
                        'รีเซ็ตรหัสผ่าน',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Subtitle
                      Text(
                        'กรุณากรอกรหัสผ่านใหม่ของคุณ',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // Form Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // New Password Field
                        const Text(
                          'รหัสผ่านใหม่',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _newPasswordController,
                          obscureText: _obscureNewPassword,
                          decoration: InputDecoration(
                            hintText: 'กรอกรหัสผ่านใหม่',
                            hintStyle: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                            prefixIcon: Icon(
                              Icons.lock_outline_rounded,
                              color: AppTheme.primary,
                              size: 22,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureNewPassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: Colors.grey[600],
                                size: 22,
                              ),
                              onPressed: () => setState(() =>
                                  _obscureNewPassword = !_obscureNewPassword),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: AppTheme.primary, width: 2),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.red),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: Colors.red, width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'กรุณากรอกรหัสผ่านใหม่';
                            }
                            if (value.length < 6) {
                              return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Confirm Password Field
                        const Text(
                          'ยืนยันรหัสผ่านใหม่',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          decoration: InputDecoration(
                            hintText: 'กรอกรหัสผ่านอีกครั้ง',
                            hintStyle: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                            prefixIcon: Icon(
                              Icons.lock_outline_rounded,
                              color: AppTheme.primary,
                              size: 22,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: Colors.grey[600],
                                size: 22,
                              ),
                              onPressed: () => setState(() =>
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: AppTheme.primary, width: 2),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.red),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: Colors.red, width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'กรุณายืนยันรหัสผ่าน';
                            }
                            if (value != _newPasswordController.text) {
                              return 'รหัสผ่านไม่ตรงกัน';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // Info Box
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.blue[200]!,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: Colors.blue[700],
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร และควรมีตัวอักษรพิมพ์ใหญ่ พิมพ์เล็ก และตัวเลขผสมกัน',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue[900],
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _resetPassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.check_circle_outline,
                                          size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'ยืนยันการเปลี่ยนรหัสผ่าน',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
