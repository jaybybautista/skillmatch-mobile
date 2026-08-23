import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
import '../../../core/error_message.dart';
import '../../../services/auth_service.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/primary_button.dart';
import '../forgot_password_screen.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key, required this.onSwitchToRegister});

  final VoidCallback onSwitchToRegister;

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _rememberMe = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      await context.read<AuthService>().login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;
      // The session gate at the root routes to the setup wizard or Home, so a
      // student who never finished setup still lands there after signing in.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on ApiException catch (e) {
      _showLoginError(e.message);
    } catch (e) {
      // Names the real cause rather than assuming the network: a timeout and
      // an unreadable reply are different problems.
      _showLoginError(
        messageForError(
          e,
          'Could not reach the server. Please check your connection.',
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitGoogle() async {
    setState(() {
      _isGoogleLoading = true;
      _errorText = null;
    });

    // Both resolved before the await. The native account picker takes over the
    // screen, and this State can be disposed while it is up; a `mounted` check
    // afterwards would then skip the navigation even though the sign-in
    // succeeded, which looks exactly like the button having done nothing.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final user = await context.read<AuthService>().loginWithGoogle();

      if (user == null) {
        // The account picker was dismissed. Said out loud rather than passed
        // over in silence: a button that visibly does nothing reads as broken
        // even when it worked exactly as asked.
        messenger.showSnackBar(
          const SnackBar(content: Text('Google sign-in was cancelled.')),
        );
        return;
      }

      // The session gate at the root routes to the setup wizard or Home, so a
      // student who never finished setup still lands there after signing in.
      navigator.popUntil((route) => route.isFirst);
    } on ApiException catch (e) {
      _showGoogleError(e.message);
    } catch (e) {
      debugPrint('Google sign-in failed: $e');
      // The cause is shown, not just logged. "Please try again" on a sign-in
      // that actually succeeded server-side is what made this take days to
      // pin down.
      _showGoogleError(
        messageForError(e, 'Google sign-in failed. Please try again.'),
      );
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  /// Shows the message twice over: inline under the fields, and as a snack
  /// bar. The inline line alone is easy to miss on a full screen, and a login
  /// that appears to do nothing is the most confusing failure there is.
  void _showLoginError(String message) {
    if (!mounted) return;
    setState(() => _errorText = message);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showGoogleError(String message) {
    if (!mounted) return;
    setState(() => _errorText = message);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Google sign-in failed'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            label: 'Email address',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Email is required';
              }
              if (!value.contains('@')) return 'Enter a valid email address';
              return null;
            },
          ),
          const SizedBox(height: 18),
          AppTextField(
            label: 'Password',
            controller: _passwordController,
            obscureText: true,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            validator: (value) => (value == null || value.isEmpty)
                ? 'Password is required'
                : null,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => setState(() => _rememberMe = !_rememberMe),
                child: Row(
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      activeColor: AppColors.primary,
                      onChanged: (value) =>
                          setState(() => _rememberMe = value ?? true),
                    ),
                    const Text('Remember me'),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ForgotPasswordScreen(),
                  ),
                ),
                child: const Text('Forgot password?'),
              ),
            ],
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 4),
            Text(
              _errorText!,
              style: const TextStyle(color: AppColors.danger, fontSize: 13),
            ),
          ],
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Log In',
            isLoading: _isLoading,
            onPressed: _submit,
          ),
          const SizedBox(height: 24),
          Row(
            children: const [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Or with',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
              Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _isGoogleLoading ? null : _submitGoogle,
            icon: _isGoogleLoading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : Image.asset('assets/google-logo.png', height: 20, width: 20),
            label: const Text('Google'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
