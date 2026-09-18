import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/primary_button.dart';

/// The last step of sign-up, like the web's verify page: the six-digit code
/// from the email creates the account. On success the session is already
/// stored, so the screen unwinds to the launch gate, which lands a student
/// in the setup wizard and a company on its home.
class RegisterVerifyScreen extends StatefulWidget {
  const RegisterVerifyScreen({super.key, required this.email, this.message});

  final String email;
  final String? message;

  @override
  State<RegisterVerifyScreen> createState() => _RegisterVerifyScreenState();
}

class _RegisterVerifyScreenState extends State<RegisterVerifyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();

  bool _isLoading = false;
  bool _isResending = false;
  String? _errorText;
  String? _infoText;
  Timer? _cooldownTimer;
  int _cooldownSeconds = 30;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _code.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = 30);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => _cooldownSeconds = 0);
      } else if (mounted) {
        setState(() => _cooldownSeconds -= 1);
      }
    });
  }

  Future<void> _resend() async {
    setState(() {
      _isResending = true;
      _errorText = null;
    });
    try {
      final message = await context.read<AuthService>().resendRegistrationCode(widget.email);
      if (!mounted) return;
      setState(() => _infoText = message);
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

    try {
      await context.read<AuthService>().verifyRegistration(email: widget.email, code: _code.text.trim());
      if (!mounted) return;
      // The gate is watching the session; it decides between the setup
      // wizard, Home and the company home.
      Navigator.of(context).popUntil((route) => route.isFirst);
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
                Text('Verify your email', textAlign: TextAlign.center, style: AppFonts.title(fontSize: 24, color: AppColors.textDark)),
                const SizedBox(height: 8),
                Text(
                  widget.message ?? 'We sent a six-digit code to ${widget.email}. Enter it to finish creating your account.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 14.5, height: 1.45),
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  autofocus: true,
                  style: const TextStyle(fontSize: 24, letterSpacing: 12, fontWeight: FontWeight.w600),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(counterText: '', hintText: '••••••'),
                  validator: (value) => (value == null || value.length != 6) ? 'Enter the 6-digit code' : null,
                  onFieldSubmitted: (_) => _submit(),
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: 12),
                  Text(_errorText!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                ] else if (_infoText != null) ...[
                  const SizedBox(height: 12),
                  Text(_infoText!, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                ],
                const SizedBox(height: 24),
                PrimaryButton(label: 'Create account', isLoading: _isLoading, onPressed: _submit),
                const SizedBox(height: 20),
                Center(
                  child: _isResending
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
                      : TextButton(
                          onPressed: _cooldownSeconds == 0 ? _resend : null,
                          child: Text(_cooldownSeconds == 0 ? 'Resend code' : 'Resend code in ${_cooldownSeconds}s'),
                        ),
                ),
                const Text(
                  'The code expires in 10 minutes. Check your spam folder if it does not arrive.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Second step of sign-in for accounts with two-factor authentication: the
/// six-digit code from the authenticator app, or one of the recovery codes.
class TwoFactorScreen extends StatefulWidget {
  const TwoFactorScreen({super.key, required this.challenge, this.message});

  final String challenge;
  final String? message;

  @override
  State<TwoFactorScreen> createState() => _TwoFactorScreenState();
}

class _TwoFactorScreenState extends State<TwoFactorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  bool _useRecovery = false;
  bool _isLoading = false;
  String? _errorText;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      await context.read<AuthService>().verifyTwoFactor(
            challenge: widget.challenge,
            code: _useRecovery ? null : _code.text.trim(),
            recoveryCode: _useRecovery ? _code.text.trim() : null,
          );
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
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
                const SizedBox(height: 20),
                Text('Two-factor authentication', textAlign: TextAlign.center, style: AppFonts.title(fontSize: 22, color: AppColors.textDark)),
                const SizedBox(height: 8),
                Text(
                  _useRecovery
                      ? 'Enter one of the recovery codes you saved when you set up two-factor authentication.'
                      : (widget.message ?? 'Enter the 6-digit code from your authenticator app.'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 14.5, height: 1.45),
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _code,
                  keyboardType: _useRecovery ? TextInputType.text : TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: _useRecovery ? 32 : 6,
                  autofocus: true,
                  autocorrect: false,
                  style: TextStyle(fontSize: _useRecovery ? 18 : 24, letterSpacing: _useRecovery ? 2 : 12, fontWeight: FontWeight.w600),
                  inputFormatters: _useRecovery ? null : [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(counterText: '', hintText: _useRecovery ? 'recovery code' : '••••••'),
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (_useRecovery) return v.isEmpty ? 'Enter a recovery code' : null;
                    return v.length != 6 ? 'Enter the 6-digit code' : null;
                  },
                  onFieldSubmitted: (_) => _submit(),
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: 12),
                  Text(_errorText!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                ],
                const SizedBox(height: 24),
                PrimaryButton(label: 'Verify', isLoading: _isLoading, onPressed: _submit),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () => setState(() {
                      _useRecovery = !_useRecovery;
                      _code.clear();
                      _errorText = null;
                    }),
                    child: Text(_useRecovery ? 'Use the authenticator code instead' : 'Use a recovery code instead'),
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
