import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _identifierController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isRegistering = false;
  bool _isResettingPassword = false;
  String _gender = 'prefer_not_to_say';

  @override
  void dispose() {
    _emailController.dispose();
    _identifierController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _isResettingPassword
                              ? 'We will email you a password reset link.'
                              : 'Mpuza',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        if (_isResettingPassword) ...[
                          _textField(
                            controller: _emailController,
                            label: 'Email',
                            keyboardType: TextInputType.emailAddress,
                            validator: _emailValidator,
                          ),
                        ] else if (_isRegistering) ...[
                          _textField(
                            controller: _emailController,
                            label: 'Email',
                            keyboardType: TextInputType.emailAddress,
                            validator: _emailValidator,
                          ),
                          const SizedBox(height: 14),
                          _textField(
                            controller: _usernameController,
                            label: 'Username',
                            validator: _requiredValidator,
                          ),
                          const SizedBox(height: 14),
                          _textField(
                            controller: _phoneController,
                            label: 'Phone number (include country code)',
                            keyboardType: TextInputType.phone,
                            validator: _phoneValidator,
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            initialValue: _gender,
                            decoration: const InputDecoration(
                              labelText: 'Gender',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'male',
                                child: Text('Male'),
                              ),
                              DropdownMenuItem(
                                value: 'female',
                                child: Text('Female'),
                              ),
                              DropdownMenuItem(
                                value: 'other',
                                child: Text('Other'),
                              ),
                              DropdownMenuItem(
                                value: 'prefer_not_to_say',
                                child: Text('Prefer not to say'),
                              ),
                            ],
                            onChanged: auth.isBusy
                                ? null
                                : (value) {
                                    if (value != null) {
                                      setState(() => _gender = value);
                                    }
                                  },
                          ),
                        ] else ...[
                          _textField(
                            controller: _identifierController,
                            label: 'Email or phone number',
                            keyboardType: TextInputType.emailAddress,
                            validator: _requiredValidator,
                          ),
                        ],
                        if (!_isResettingPassword) ...[
                          const SizedBox(height: 14),
                          _textField(
                            controller: _passwordController,
                            label: 'Password',
                            obscureText: true,
                            validator: _requiredValidator,
                          ),
                          if (_isRegistering) ...[
                            const SizedBox(height: 14),
                            _textField(
                              controller: _confirmPasswordController,
                              label: 'Confirm password',
                              obscureText: true,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Enter your password again.';
                                }
                                if (value != _passwordController.text) {
                                  return 'Passwords do not match.';
                                }
                                return null;
                              },
                            ),
                          ],
                        ],
                        if (auth.errorMessage != null) ...[
                          const SizedBox(height: 16),
                          _message(auth.errorMessage!, isError: true),
                        ],
                        if (auth.noticeMessage != null) ...[
                          const SizedBox(height: 16),
                          _message(auth.noticeMessage!),
                        ],
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: auth.isBusy ? null : _submit,
                          child: auth.isBusy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _isResettingPassword
                                      ? 'Send reset link'
                                      : _isRegistering
                                          ? 'Create account'
                                          : 'Sign in',
                                ),
                        ),
                        const SizedBox(height: 8),
                        if (_isResettingPassword)
                          TextButton(
                            onPressed: auth.isBusy
                                ? null
                                : () => setState(
                                      () => _isResettingPassword = false,
                                    ),
                            child: const Text('Back to sign in'),
                          )
                        else if (_isRegistering)
                          TextButton(
                            onPressed: auth.isBusy
                                ? null
                                : () => setState(() => _isRegistering = false),
                            child: const Text('Already registered? Sign in'),
                          )
                        else ...[
                          TextButton(
                            onPressed: auth.isBusy
                                ? null
                                : () => setState(
                                      () => _isResettingPassword = true,
                                    ),
                            child: const Text('Forgot password?'),
                          ),
                          TextButton(
                            onPressed: auth.isBusy ? null : _resendVerification,
                            child: const Text('Resend verification email'),
                          ),
                          TextButton(
                            onPressed: auth.isBusy
                                ? null
                                : () => setState(() => _isRegistering = true),
                            child: const Text('Create an account'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool obscureText = false,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _message(String text, {bool isError = false}) {
    final color = isError ? Colors.red.shade700 : Colors.green.shade800;
    return Text(text, style: TextStyle(color: color));
  }

  String? _requiredValidator(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required.' : null;

  String? _emailValidator(String? value) {
    if (value == null || !value.contains('@') || !value.contains('.')) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  String? _phoneValidator(String? value) {
    if (value == null || !RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(value.trim())) {
      return 'Use international format, for example +2507XXXXXXXX.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();

    if (_isResettingPassword) {
      await auth.requestPasswordReset(_emailController.text.trim());
      return;
    }
    if (_isRegistering) {
      await auth.register(
        email: _emailController.text.trim(),
        username: _usernameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        gender: _gender,
        password: _passwordController.text,
        confirmPassword: _confirmPasswordController.text,
      );
      if (mounted && auth.errorMessage == null && auth.noticeMessage != null) {
        setState(() {
          _isRegistering = false;
          _identifierController.text = _emailController.text.trim();
        });
      }
      return;
    }

    await auth.login(
      identifier: _identifierController.text.trim(),
      password: _passwordController.text,
    );
  }

  Future<void> _resendVerification() async {
    final emailController = TextEditingController(
      text: _identifierController.text.contains('@')
          ? _identifierController.text.trim()
          : '',
    );
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resend verification email'),
        content: TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, emailController.text.trim()),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    emailController.dispose();
    if (email == null || email.isEmpty || !mounted) return;
    await context.read<AuthProvider>().resendVerification(email);
  }
}
