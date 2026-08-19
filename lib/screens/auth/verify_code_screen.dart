import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/primary_button.dart';
import 'reset_password_screen.dart';

/// Step 2 of password recovery: verify the 6-digit code that was emailed in
/// [ForgotPasswordScreen]. On success we hand the (email, code) pair to
/// [ResetPasswordScreen], which re-validates it server-side when the new
/// password is actually saved.
class VerifyCodeScreen extends StatefulWidget {
  const VerifyCodeScreen({super.key, required this.email});

  final String email;

  @override
  State<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  bool _isLoading = false;
  bool _isResending = false;
  String? _errorText;

  Timer? _cooldownTimer;
  int _cooldownSeconds = 30;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = 30);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _cooldownSeconds = 0);
      } else {
        setState(() => _cooldownSeconds -= 1);
      }
    });
  }

  Future<void> _resend() async {
    setState(() => _isResending = true);
    try {
      await context.read<AuthService>().sendPasswordResetCode(widget.email);
      _startCooldown();
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorText = e.message);
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    final code = _codeController.text.trim();

    try {
      await context.read<AuthService>().verifyPasswordResetCode(email: widget.email, code: code);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ResetPasswordScreen(email: widget.email, code: code)),
      );
    } on ApiException catch (e) {
      setState(() => _errorText = e.message);
    } catch (_) {
      setState(() => _errorText = 'Could not reach the server. Please check your connection.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 4),
                Image.asset('assets/logo.png', height: 90),
                const SizedBox(height: 12),
                Image.asset('assets/letter-skillmatch.png', height: 40),
                const SizedBox(height: 20),
                const Text(
                  'Enter Verification Code',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
                const SizedBox(height: 8),
                Text(
                  'We sent a 6-digit code to ${widget.email}.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 15),
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  style: const TextStyle(fontSize: 24, letterSpacing: 12, fontWeight: FontWeight.w600),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(counterText: '', hintText: '••••••'),
                  validator: (value) {
                    if (value == null || value.length != 6) return 'Enter the 6-digit code';
                    return null;
                  },
                  onFieldSubmitted: (_) => _submit(),
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: 12),
                  Text(_errorText!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                ],
                const SizedBox(height: 24),
                PrimaryButton(label: 'Verify Code', isLoading: _isLoading, onPressed: _submit),
                const SizedBox(height: 20),
                Center(
                  child: _isResending
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : TextButton(
                          onPressed: _cooldownSeconds == 0 ? _resend : null,
                          child: Text(
                            _cooldownSeconds == 0 ? 'Resend code' : 'Resend code in ${_cooldownSeconds}s',
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
