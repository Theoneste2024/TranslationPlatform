import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations_extensions.dart';
import '../../providers/auth_provider.dart';

enum _AuthStage {
  login,
  signupDetails,
  signupSecurity,
  verifyEmail,
  verified,
  forgotPassword,
  resetPassword,
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static const _navy = Color(0xFF0B3C5D);
  static const _blue = Color(0xFF00A1DE);
  static const _green = Color(0xFF20603D);
  static const _yellow = Color(0xFFFAD201);
  static const _border = Color(0xFFD3E2EC);
  static const _fieldFill = Color(0xFFF7FBFD);
  static const _muted = Color(0xFF5C7486);

  final _signupDetailsKey = GlobalKey<FormState>();
  final _signupSecurityKey = GlobalKey<FormState>();
  final _loginKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _recoveryEmailController = TextEditingController();
  final _resetPasswordController = TextEditingController();
  final _resetConfirmPasswordController = TextEditingController();
  final _forgotPasswordKey = GlobalKey<FormState>();
  final _resetPasswordKey = GlobalKey<FormState>();
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());
  final Set<String> _validFields = {};

  _AuthStage _stage = _AuthStage.login;
  String _gender = 'Male';
  String _country = 'Rwanda';
  String? _focusedField;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoginPasswordVisible = false;
  int _otpExpiresIn = 0;
  int _resendIn = 0;
  Timer? _otpTimer;

  @override
  void initState() {
    super.initState();
    for (final focusNode in _otpFocusNodes) {
      focusNode.addListener(_onOtpFocusChanged);
    }
  }

  @override
  void dispose() {
    _otpTimer?.cancel();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _loginController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _loginPasswordController.dispose();
    _recoveryEmailController.dispose();
    _resetPasswordController.dispose();
    _resetConfirmPasswordController.dispose();
    for (final controller in _otpControllers) {
      controller.dispose();
    }
    for (final focusNode in _otpFocusNodes) {
      focusNode.removeListener(_onOtpFocusChanged);
      focusNode.dispose();
    }
    super.dispose();
  }

  void _onOtpFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isAuthLoading = context.watch<AuthProvider>().isLoading;
    return Scaffold(
      backgroundColor: const Color(0xFF17482E),
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth <= 36 || constraints.maxHeight <= 0) {
                return const SizedBox.shrink();
              }

              final isMobile = constraints.maxWidth < 600;
              final cardWidth = math.min(constraints.maxWidth - 36, 400.0);

              return Theme(
                data: Theme.of(context).copyWith(
                  textTheme:
                      GoogleFonts.interTextTheme(Theme.of(context).textTheme),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(
                      painter: _BrandBackdropPainter(isMobile: isMobile),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: EdgeInsets.only(top: isMobile ? 24 : 0),
                        child: LayoutBuilder(
                          builder: (context, viewport) {
                            final headerGap = isMobile
                                ? math.min(viewport.maxHeight * 0.12, 88.0)
                                : 16.0;
                            final panelHeight = isMobile
                                ? math.max(600.0, viewport.maxHeight * 0.79)
                                : _desktopPanelHeight;
                            final group = SizedBox(
                              width: cardWidth,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const SizedBox(
                                    height: 48,
                                    child: _BrandHeader(),
                                  ),
                                  SizedBox(height: headerGap),
                                  _buildStagePanel(
                                    minHeight: panelHeight,
                                    compact: isMobile,
                                  ),
                                ],
                              ),
                            );

                            return SingleChildScrollView(
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: viewport.maxHeight,
                                ),
                                child: isMobile
                                    ? Align(
                                        alignment: Alignment.topCenter,
                                        child: group,
                                      )
                                    : Center(child: group),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          if (isAuthLoading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                minHeight: 2,
                color: _blue,
                backgroundColor: Colors.transparent,
              ),
            ),
        ],
      ),
    );
  }

  double get _desktopPanelHeight => switch (_stage) {
        _AuthStage.signupDetails => 520,
        _AuthStage.signupSecurity => 550,
        _AuthStage.resetPassword => 590,
        _ => 464,
      };

  Widget _buildStagePanel({
    required double minHeight,
    required bool compact,
  }) {
    switch (_stage) {
      case _AuthStage.login:
        return _buildLoginPanel(minHeight, compact);
      case _AuthStage.signupDetails:
        return _buildSignupDetailsPanel(minHeight, compact);
      case _AuthStage.signupSecurity:
        return _buildSignupSecurityPanel(minHeight, compact);
      case _AuthStage.verifyEmail:
        return _buildVerificationPanel(minHeight, compact);
      case _AuthStage.verified:
        return _buildVerifiedPanel(minHeight, compact);
      case _AuthStage.forgotPassword:
        return _buildForgotPasswordPanel(minHeight, compact);
      case _AuthStage.resetPassword:
        return _buildResetPasswordPanel(minHeight, compact);
    }
  }

  Widget _panel({
    required List<Widget> content,
    required Widget footer,
    required double minHeight,
    required bool compact,
    EdgeInsetsGeometry? padding,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xF2F7FAF8),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: SizedBox(
        height: minHeight,
        child: Padding(
          padding: padding ??
              EdgeInsets.fromLTRB(
                compact ? 22 : 26,
                compact ? 22 : 25,
                compact ? 22 : 26,
                compact ? 20 : 22,
              ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: content,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              footer,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginPanel(double minHeight, bool compact) {
    return _panel(
      minHeight: minHeight,
      compact: compact,
      content: [
        Text(context.l10n.welcomeBack, style: _titleStyle),
        const SizedBox(height: 4),
        Text(
          context.l10n.loginToContinue,
          style: const TextStyle(color: _muted, fontSize: 14),
        ),
        const SizedBox(height: 20),
        Form(
          key: _loginKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _fieldLabel(context.l10n.emailOrUsername),
              _textField(
                controller: _loginController,
                hint: 'jean_claude',
                icon: Icons.person_outline,
                validator: _requiredValidator,
                textInputAction: TextInputAction.next,
                key: const ValueKey('login-identifier'),
              ),
              const SizedBox(height: 18),
              _fieldLabel(context.l10n.password),
              _textField(
                controller: _loginPasswordController,
                hint: context.l10n.enterPassword,
                icon: Icons.lock_outline,
                obscureText: !_isLoginPasswordVisible,
                validator: _requiredValidator,
                textInputAction: TextInputAction.done,
                key: const ValueKey('login-password'),
                suffix: IconButton(
                  tooltip: _isLoginPasswordVisible
                      ? context.l10n.hidePassword
                      : context.l10n.showPassword,
                  onPressed: () => setState(
                    () => _isLoginPasswordVisible = !_isLoginPasswordVisible,
                  ),
                  icon: Icon(
                    _isLoginPasswordVisible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: _muted,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _openForgotPassword,
                  style: TextButton.styleFrom(
                    foregroundColor: _blue,
                    padding: const EdgeInsets.only(top: 7),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    context.l10n.forgotPassword,
                    style: GoogleFonts.inter(
                      color: _blue,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
      footer: Column(
        children: [
          _primaryButton(
            label: context.l10n.login,
            onPressed: _isAuthLoading ? null : _submitLogin,
            key: const ValueKey('login-submit'),
          ),
          const SizedBox(height: 12),
          _inlineLink(
            lead: context.l10n.newToMpuza,
            action: context.l10n.createAccount,
            onTap: () => setState(() => _stage = _AuthStage.signupDetails),
          ),
        ],
      ),
    );
  }

  Widget _buildSignupDetailsPanel(double minHeight, bool compact) {
    return _panel(
      minHeight: minHeight,
      compact: compact,
      content: [
        _stepProgress(1),
        const SizedBox(height: 13),
        Text(context.l10n.signupStepOne, style: _eyebrowStyle),
        const SizedBox(height: 5),
        Text(context.l10n.createAccount, style: _titleStyle),
        const SizedBox(height: 4),
        Text(
          context.l10n.joinMpuza,
          style: const TextStyle(color: _muted, fontSize: 14),
        ),
        const SizedBox(height: 21),
        Form(
          key: _signupDetailsKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _fieldLabel(context.l10n.username),
              _textField(
                controller: _usernameController,
                hint: 'jean_claude',
                icon: Icons.person_outline,
                validator: _requiredValidator,
                textInputAction: TextInputAction.next,
                key: const ValueKey('signup-username'),
              ),
              const SizedBox(height: 16),
              _fieldLabel(context.l10n.emailAddress),
              _textField(
                controller: _emailController,
                hint: 'jean@example.com',
                icon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  final requiredError = _requiredValidator(value);
                  if (requiredError != null) return requiredError;
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                      .hasMatch(value!.trim())) {
                    return context.l10n.invalidEmailAddress;
                  }
                  return null;
                },
                textInputAction: TextInputAction.next,
                key: const ValueKey('signup-email'),
              ),
              const SizedBox(height: 16),
              _fieldLabel(context.l10n.phoneNumber),
              _textField(
                controller: _phoneController,
                hint: '78 123 4567',
                icon: Icons.call_outlined,
                keyboardType: TextInputType.phone,
                validator: _requiredValidator,
                textInputAction: TextInputAction.done,
                prefix: const Padding(
                  padding: EdgeInsets.only(left: 14, right: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'RW +250',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: _navy,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: 10),
                      SizedBox(
                        height: 22,
                        child: VerticalDivider(
                          color: _border,
                          width: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                key: const ValueKey('signup-phone'),
              ),
            ],
          ),
        ),
      ],
      footer: Column(
        children: [
          _primaryButton(
            label: context.l10n.continueLabel,
            onPressed: _continueToSignupSecurity,
            key: const ValueKey('signup-continue'),
          ),
          const SizedBox(height: 12),
          _inlineLink(
            lead: context.l10n.alreadyHaveAccount,
            action: context.l10n.login,
            onTap: () => setState(() => _stage = _AuthStage.login),
          ),
        ],
      ),
    );
  }

  Widget _buildSignupSecurityPanel(double minHeight, bool compact) {
    return _panel(
      minHeight: math.max(minHeight, compact ? 630 : 510),
      compact: compact,
      padding:
          EdgeInsets.fromLTRB(compact ? 20 : 26, 20, compact ? 20 : 26, 20),
      content: [
        _stepProgress(2),
        const SizedBox(height: 13),
        Text(context.l10n.signupStepTwo, style: _eyebrowStyle),
        const SizedBox(height: 4),
        Text(context.l10n.aboutYouAndSecurity, style: _titleStyle),
        const SizedBox(height: 12),
        _fieldLabel(context.l10n.gender),
        Row(
          children: [
            _genderChoice('Male', context.l10n.male),
            const SizedBox(width: 8),
            _genderChoice('Female', context.l10n.female),
            const SizedBox(width: 8),
            _genderChoice('Prefer not to say', context.l10n.preferNotToSay),
          ],
        ),
        const SizedBox(height: 14),
        _fieldLabel(context.l10n.country),
        DropdownButtonFormField<String>(
          initialValue: _country,
          isExpanded: true,
          decoration: _inputDecoration(
            prefixIcon: const Icon(Icons.language, color: _muted, size: 20),
          ),
          icon: const Icon(Icons.keyboard_arrow_down, color: _muted),
          items: [
            DropdownMenuItem(
              value: 'Rwanda',
              child: Text(context.l10n.countryRwanda),
            ),
            DropdownMenuItem(
              value: 'Burundi',
              child: Text(context.l10n.countryBurundi),
            ),
            DropdownMenuItem(
              value: 'Democratic Republic of the Congo',
              child: Text(context.l10n.countryDrCongo),
            ),
            DropdownMenuItem(
              value: 'Kenya',
              child: Text(context.l10n.countryKenya),
            ),
            DropdownMenuItem(
              value: 'Tanzania',
              child: Text(context.l10n.countryTanzania),
            ),
            DropdownMenuItem(
              value: 'Uganda',
              child: Text(context.l10n.countryUganda),
            ),
          ],
          onChanged: (country) {
            if (country != null) setState(() => _country = country);
          },
        ),
        const SizedBox(height: 14),
        Form(
          key: _signupSecurityKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _fieldLabel(context.l10n.password),
              _textField(
                controller: _passwordController,
                hint: context.l10n.createStrongPassword,
                icon: Icons.lock_outline,
                obscureText: !_isPasswordVisible,
                validator: _passwordValidator,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.next,
                key: const ValueKey('signup-password'),
                suffix: IconButton(
                  tooltip: _isPasswordVisible
                      ? context.l10n.hidePassword
                      : context.l10n.showPassword,
                  onPressed: () =>
                      setState(() => _isPasswordVisible = !_isPasswordVisible),
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: _blue,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _passwordStrengthIndicator(_passwordController.text),
              const SizedBox(height: 13),
              _fieldLabel(context.l10n.confirmPassword),
              _textField(
                controller: _confirmPasswordController,
                hint: context.l10n.reenterPassword,
                icon: Icons.lock_outline,
                obscureText: !_isConfirmPasswordVisible,
                validator: (value) {
                  final requiredError = _requiredValidator(value);
                  if (requiredError != null) return requiredError;
                  if (value != _passwordController.text) {
                    return context.l10n.passwordsDoNotMatch;
                  }
                  return null;
                },
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.done,
                key: const ValueKey('signup-confirm-password'),
                suffix: IconButton(
                  tooltip: _isConfirmPasswordVisible
                      ? context.l10n.hidePassword
                      : context.l10n.showPassword,
                  onPressed: () => setState(
                    () =>
                        _isConfirmPasswordVisible = !_isConfirmPasswordVisible,
                  ),
                  icon: Icon(
                    _isConfirmPasswordVisible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: _blue,
                  ),
                ),
              ),
              if (_confirmPasswordController.text.isNotEmpty &&
                  _confirmPasswordController.text ==
                      _passwordController.text) ...[
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(Icons.check, color: _green, size: 15),
                    const SizedBox(width: 5),
                    Text(
                      context.l10n.passwordsMatch,
                      style: const TextStyle(
                        color: _green,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
      footer: _primaryButton(
        label: context.l10n.createAccount,
        onPressed: _isSignupValid && !_isAuthLoading ? _createAccount : null,
        key: const ValueKey('signup-submit'),
      ),
    );
  }

  Widget _buildVerificationPanel(double minHeight, bool compact) {
    return _panel(
      minHeight: minHeight,
      compact: compact,
      padding:
          EdgeInsets.fromLTRB(compact ? 18 : 26, 22, compact ? 18 : 26, 20),
      content: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              _otpTimer?.cancel();
              setState(() => _stage = _AuthStage.signupSecurity);
            },
            icon: const Icon(Icons.arrow_back, size: 20),
            label: Text(context.l10n.back),
            style: TextButton.styleFrom(
              foregroundColor: _navy,
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Center(child: _verificationIcon()),
        const SizedBox(height: 20),
        Text(
          context.l10n.verifyYourEmail,
          textAlign: TextAlign.center,
          style: _titleStyle,
        ),
        const SizedBox(height: 5),
        Text(
          context.l10n.verificationCodeSentTo(
            _maskedEmail(_emailController.text),
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted, height: 1.35),
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final boxWidth = math.min(44.0, (constraints.maxWidth - 20) / 6);
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                6,
                (index) => Padding(
                  padding: EdgeInsets.only(right: index == 5 ? 0 : 4),
                  child: SizedBox(
                    width: boxWidth,
                    child: _otpField(index),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Text.rich(
          TextSpan(
            style: const TextStyle(color: _muted, fontSize: 13),
            children: [
              TextSpan(text: context.l10n.codeExpiresInPrefix),
              TextSpan(
                text: _formatDuration(_otpExpiresIn),
                style: const TextStyle(
                  color: _navy,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 7),
        Text.rich(
          TextSpan(
            style: const TextStyle(color: _muted, fontSize: 13),
            children: [
              TextSpan(text: context.l10n.didntGetIt),
              TextSpan(
                text: _resendIn > 0
                    ? context.l10n.resendIn(_formatDuration(_resendIn))
                    : context.l10n.resendCode,
                style: TextStyle(
                  color: _resendIn > 0 ? _blue.withValues(alpha: 0.65) : _blue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        if (_resendIn == 0)
          Center(
            child: TextButton(
              onPressed: _isAuthLoading ? null : _resendCode,
              child: Text(context.l10n.resendCode),
            ),
          ),
      ],
      footer: Column(
        children: [
          _primaryButton(
            label: context.l10n.verify,
            onPressed: _isAuthLoading ? null : _verifyCode,
            key: const ValueKey('verify-submit'),
          ),
          const SizedBox(height: 12),
          _inlineLink(
            lead: context.l10n.wrongEmail,
            action: context.l10n.changeIt,
            onTap: () {
              _otpTimer?.cancel();
              setState(() => _stage = _AuthStage.signupDetails);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVerifiedPanel(double minHeight, bool compact) {
    return _panel(
      minHeight: minHeight,
      compact: compact,
      padding: EdgeInsets.fromLTRB(
        compact ? 22 : 26,
        compact ? 28 : 32,
        compact ? 22 : 26,
        compact ? 20 : 22,
      ),
      content: [
        SizedBox(height: compact ? 70 : 38),
        const Center(child: _SuccessMark()),
        const SizedBox(height: 30),
        Text(
          context.l10n.emailVerified,
          textAlign: TextAlign.center,
          style: _titleStyle,
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.accountReadyMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted, height: 1.45, fontSize: 14),
        ),
      ],
      footer: _primaryButton(
        label: context.l10n.goToLogin,
        onPressed: () => setState(() => _stage = _AuthStage.login),
        key: const ValueKey('verified-login'),
      ),
    );
  }

  Widget _buildForgotPasswordPanel(double minHeight, bool compact) {
    return _panel(
      minHeight: minHeight,
      compact: compact,
      content: [
        Text(context.l10n.forgotPassword, style: _titleStyle),
        const SizedBox(height: 5),
        Text(
          context.l10n.forgotPasswordInstructions,
          style: const TextStyle(color: _muted, height: 1.4),
        ),
        const SizedBox(height: 22),
        Form(
          key: _forgotPasswordKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _fieldLabel(context.l10n.emailAddress),
              _textField(
                controller: _recoveryEmailController,
                hint: 'jean@example.com',
                icon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
                validator: _emailValidator,
                textInputAction: TextInputAction.done,
                key: const ValueKey('recovery-email'),
              ),
            ],
          ),
        ),
      ],
      footer: Column(
        children: [
          _primaryButton(
            label: context.l10n.sendResetCode,
            onPressed: _isAuthLoading ? null : _requestPasswordReset,
            key: const ValueKey('recovery-request'),
          ),
          const SizedBox(height: 12),
          _inlineLink(
            lead: context.l10n.rememberPassword,
            action: context.l10n.login,
            onTap: () => setState(() => _stage = _AuthStage.login),
          ),
        ],
      ),
    );
  }

  Widget _buildResetPasswordPanel(double minHeight, bool compact) {
    return _panel(
      minHeight: math.max(minHeight, compact ? 700 : 590),
      compact: compact,
      content: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _stage = _AuthStage.forgotPassword),
            icon: const Icon(Icons.arrow_back, size: 20),
            label: Text(context.l10n.back),
            style: TextButton.styleFrom(
              foregroundColor: _navy,
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(child: _verificationIcon()),
        const SizedBox(height: 12),
        Text(
          context.l10n.resetYourPassword,
          textAlign: TextAlign.center,
          style: _titleStyle,
        ),
        const SizedBox(height: 5),
        Text(
          context.l10n.resetCodeSentTo(
            _maskedEmail(_recoveryEmailController.text),
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted, height: 1.35),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final boxWidth = math.min(44.0, (constraints.maxWidth - 20) / 6);
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                6,
                (index) => Padding(
                  padding: EdgeInsets.only(right: index == 5 ? 0 : 4),
                  child: SizedBox(width: boxWidth, child: _otpField(index)),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          '${context.l10n.codeExpiresInPrefix}'
          '${_formatDuration(_otpExpiresIn)}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted, fontSize: 13),
        ),
        Center(
          child: TextButton(
            onPressed:
                _resendIn == 0 && !_isAuthLoading ? _resendResetCode : null,
            child: Text(
              _resendIn == 0
                  ? context.l10n.resendCode
                  : context.l10n.resendIn(_formatDuration(_resendIn)),
            ),
          ),
        ),
        Form(
          key: _resetPasswordKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _fieldLabel(context.l10n.newPassword),
              _textField(
                controller: _resetPasswordController,
                hint: context.l10n.createStrongPassword,
                icon: Icons.lock_outline,
                obscureText: !_isPasswordVisible,
                validator: _passwordValidator,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.next,
                key: const ValueKey('recovery-password'),
                suffix: IconButton(
                  tooltip: _isPasswordVisible
                      ? context.l10n.hidePassword
                      : context.l10n.showPassword,
                  onPressed: () =>
                      setState(() => _isPasswordVisible = !_isPasswordVisible),
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: _blue,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _passwordStrengthIndicator(_resetPasswordController.text),
              const SizedBox(height: 12),
              _fieldLabel(context.l10n.confirmNewPassword),
              _textField(
                controller: _resetConfirmPasswordController,
                hint: context.l10n.reenterPassword,
                icon: Icons.lock_outline,
                obscureText: !_isConfirmPasswordVisible,
                validator: (value) {
                  final requiredError = _requiredValidator(value);
                  if (requiredError != null) return requiredError;
                  if (value != _resetPasswordController.text) {
                    return context.l10n.passwordsDoNotMatch;
                  }
                  return null;
                },
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.done,
                key: const ValueKey('recovery-confirm-password'),
                suffix: IconButton(
                  tooltip: _isConfirmPasswordVisible
                      ? context.l10n.hidePassword
                      : context.l10n.showPassword,
                  onPressed: () => setState(
                    () =>
                        _isConfirmPasswordVisible = !_isConfirmPasswordVisible,
                  ),
                  icon: Icon(
                    _isConfirmPasswordVisible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: _blue,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
      footer: _primaryButton(
        label: context.l10n.resetPassword,
        onPressed: _isAuthLoading ? null : _resetPassword,
        key: const ValueKey('recovery-reset'),
      ),
    );
  }

  Widget _stepProgress(int currentStep) {
    return Row(
      children: [
        Expanded(
          child: _progressSegment(
            active: currentStep == 1,
            complete: currentStep == 2,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: _progressSegment(active: currentStep == 2)),
      ],
    );
  }

  Widget _progressSegment({bool active = false, bool complete = false}) {
    return Container(
      height: 5,
      decoration: BoxDecoration(
        color: active
            ? _yellow
            : complete
                ? _green
                : const Color(0xFFDCE7EC),
        borderRadius: BorderRadius.circular(5),
      ),
    );
  }

  Widget _genderChoice(String gender, String label) {
    final selected = _gender == gender;
    return Expanded(
      child: SizedBox(
        height: 43,
        child: OutlinedButton(
          onPressed: () => setState(() => _gender = gender),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            backgroundColor: selected ? _blue : _fieldFill,
            foregroundColor: selected ? Colors.white : _muted,
            side: BorderSide(
              color: selected ? _blue : _border,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12),
          ),
        ),
      ),
    );
  }

  Widget _passwordStrengthIndicator(String password) {
    final checks = <bool>[
      password.length >= 8,
      RegExp(r'[A-Z]').hasMatch(password),
      RegExp(r'[a-z]').hasMatch(password),
      RegExp(r'[0-9]').hasMatch(password) &&
          RegExp(r'[^A-Za-z0-9]').hasMatch(password),
    ];
    final strength = checks.where((check) => check).length;
    final strengthLabel = strength < 2
        ? context.l10n.weak
        : strength < 4
            ? context.l10n.fair
            : context.l10n.strong;
    final strengthColor = strength < 2
        ? const Color(0xFFB34343)
        : strength < 4
            ? const Color(0xFFBD8A00)
            : _green;

    return Column(
      children: [
        Row(
          children: List.generate(
            4,
            (index) => Expanded(
              child: Container(
                height: 5,
                margin: EdgeInsets.only(right: index == 3 ? 0 : 5),
                decoration: BoxDecoration(
                  color: index < strength
                      ? strengthColor
                      : const Color(0xFFDCE7EC),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.l10n.passwordStrength,
              style: const TextStyle(color: _muted, fontSize: 11),
            ),
            Text(
              strengthLabel,
              style: TextStyle(
                color: strengthColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Column(
          children: [
            Row(
              children: [
                _passwordCheck(context.l10n.eightPlusCharacters, checks[0]),
                _passwordCheck(context.l10n.uppercase, checks[1]),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _passwordCheck(context.l10n.lowercase, checks[2]),
                _passwordCheck(context.l10n.numberAndSymbol, checks[3]),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _passwordCheck(String label, bool passed) {
    return Expanded(
      child: Row(
        children: [
          Icon(
            passed ? Icons.check_circle : Icons.circle_outlined,
            color: passed ? _green : _muted,
            size: 14,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(color: _navy, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _otpField(int index) {
    final focused = _otpFocusNodes[index].hasFocus;
    final filled = _otpControllers[index].text.isNotEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: _yellow.withValues(alpha: 0.38),
                  blurRadius: 9,
                  spreadRadius: 2,
                ),
              ]
            : const [],
      ),
      child: TextField(
        controller: _otpControllers[index],
        focusNode: _otpFocusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: _navy,
          fontSize: 21,
          fontWeight: FontWeight.w700,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(1),
        ],
        decoration: InputDecoration(
          filled: true,
          fillColor: _fieldFill,
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide(
              color: filled ? _green : _border,
              width: 1.2,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: _yellow, width: 2),
          ),
        ),
        onChanged: (value) {
          setState(() {});
          if (value.isNotEmpty && index < _otpFocusNodes.length - 1) {
            _otpFocusNodes[index + 1].requestFocus();
          } else if (value.isEmpty && index > 0) {
            _otpFocusNodes[index - 1].requestFocus();
          }
        },
      ),
    );
  }

  Widget _verificationIcon() {
    return Container(
      width: 78,
      height: 78,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFFAF1B6),
      ),
      child: Center(
        child: Container(
          width: 57,
          height: 57,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: _yellow,
          ),
          child: const Icon(Icons.mail_outline, color: _navy, size: 27),
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: _navy,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Key key,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    bool obscureText = false,
    Widget? suffix,
    Widget? prefix,
    ValueChanged<String>? onChanged,
  }) {
    final fieldId = key.toString();
    return Focus(
      onFocusChange: (focused) {
        setState(() => _focusedField = focused ? fieldId : null);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          boxShadow: _focusedField == fieldId
              ? [
                  BoxShadow(
                    color: _blue.withValues(alpha: 0.22),
                    blurRadius: 8,
                    spreadRadius: 1.5,
                  ),
                ]
              : const [],
        ),
        child: TextFormField(
          key: key,
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          obscureText: obscureText,
          onChanged: (value) {
            setState(() {
              if (validator?.call(value) == null && value.trim().isNotEmpty) {
                _validFields.add(fieldId);
              } else {
                _validFields.remove(fieldId);
              }
            });
            onChanged?.call(value);
          },
          style: _fieldTextStyle,
          decoration: _inputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: _muted, size: 20),
            prefix: prefix,
            suffixIcon: suffix,
            borderColor: _validFields.contains(fieldId) ? _green : _border,
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    String? hintText,
    Widget? prefixIcon,
    Widget? prefix,
    Widget? suffixIcon,
    Color borderColor = _border,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF9AAEBC), fontSize: 14),
      filled: true,
      fillColor: _fieldFill,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      prefixIcon: prefixIcon,
      prefixIconConstraints: const BoxConstraints(minWidth: 42, minHeight: 46),
      prefix: prefix,
      suffixIcon: suffixIcon,
      suffixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 46),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: borderColor, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: _blue, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Color(0xFFB34343)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Color(0xFFB34343), width: 1.5),
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required VoidCallback? onPressed,
    required Key key,
    Color color = _blue,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        key: key,
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: color,
          disabledForegroundColor: Colors.white.withValues(alpha: 0.82),
          elevation: 8,
          shadowColor: _navy.withValues(alpha: 0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          textStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        child: Text(label),
      ),
    );
  }

  Widget _inlineLink({
    required String lead,
    required String action,
    required VoidCallback onTap,
  }) {
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        Text(lead, style: const TextStyle(color: _muted, fontSize: 13)),
        GestureDetector(
          onTap: onTap,
          child: Text(
            action,
            style: const TextStyle(
              color: _blue,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return context.l10n.requiredField;
    }
    return null;
  }

  String? _emailValidator(String? value) {
    final requiredError = _requiredValidator(value);
    if (requiredError != null) return requiredError;
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value!.trim())) {
      return context.l10n.invalidEmailAddress;
    }
    return null;
  }

  String? _passwordValidator(String? value) {
    if (value == null || value.isEmpty) return context.l10n.requiredField;
    if (value.length < 8 ||
        !RegExp(r'[A-Z]').hasMatch(value) ||
        !RegExp(r'[a-z]').hasMatch(value) ||
        !RegExp(r'[0-9]').hasMatch(value) ||
        !RegExp(r'[^A-Za-z0-9]').hasMatch(value)) {
      return context.l10n.passwordStrengthRequirement;
    }
    return null;
  }

  void _continueToSignupSecurity() {
    if (_signupDetailsKey.currentState?.validate() ?? false) {
      setState(() => _stage = _AuthStage.signupSecurity);
    }
  }

  Future<void> _createAccount() async {
    if (_gender.isEmpty) {
      _showMessage(context.l10n.selectGender);
      return;
    }
    if (!(_signupSecurityKey.currentState?.validate() ?? false)) return;

    final timing = await _performOtpAuth(
      () => context.read<AuthProvider>().register(
            username: _usernameController.text.trim(),
            email: _emailController.text.trim(),
            phoneNumber: _rwandaPhoneNumber(_phoneController.text),
            country: _country,
            gender: _gender.toLowerCase().replaceAll(' ', '_'),
            password: _passwordController.text,
            confirmPassword: _confirmPasswordController.text,
          ),
    );
    if (timing == null || !mounted) return;
    _startOtpTimer(timing);
    setState(() => _stage = _AuthStage.verifyEmail);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _otpFocusNodes.first.requestFocus();
    });
  }

  Future<void> _submitLogin() async {
    if (!(_loginKey.currentState?.validate() ?? false)) return;
    await _performAuth(
      () => context.read<AuthProvider>().login(
            identifier: _loginController.text.trim(),
            password: _loginPasswordController.text,
          ),
    );
  }

  Future<void> _verifyCode() async {
    final code = _otpControllers.map((controller) => controller.text).join();
    if (code.length != 6) {
      _showMessage(context.l10n.enterSixDigitCode);
      return;
    }
    final verified = await _performAuth(
      () => context.read<AuthProvider>().verifyEmail(
            email: _emailController.text.trim(),
            otp: code,
          ),
    );
    if (!verified || !mounted) return;
    _otpTimer?.cancel();
    setState(() => _stage = _AuthStage.verified);
  }

  void _openForgotPassword() {
    final identifier = _loginController.text.trim();
    _recoveryEmailController.text = identifier.contains('@') ? identifier : '';
    setState(() => _stage = _AuthStage.forgotPassword);
  }

  Future<void> _requestPasswordReset() async {
    if (!(_forgotPasswordKey.currentState?.validate() ?? false)) return;
    final timing = await _performOtpAuth(
      () => context.read<AuthProvider>().requestPasswordReset(
            email: _recoveryEmailController.text.trim(),
          ),
    );
    if (timing == null || !mounted) return;
    _startOtpTimer(timing);
    setState(() => _stage = _AuthStage.resetPassword);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _otpFocusNodes.first.requestFocus();
    });
  }

  Future<void> _resendResetCode() async {
    final timing = await _performOtpAuth(
      () => context.read<AuthProvider>().requestPasswordReset(
            email: _recoveryEmailController.text.trim(),
          ),
    );
    if (timing != null && mounted) _startOtpTimer(timing);
  }

  Future<void> _resetPassword() async {
    if (!(_resetPasswordKey.currentState?.validate() ?? false)) return;
    final code = _otpControllers.map((controller) => controller.text).join();
    if (code.length != 6) {
      _showMessage(context.l10n.enterSixDigitCode);
      return;
    }
    final reset = await _performAuth(
      () => context.read<AuthProvider>().resetPassword(
            email: _recoveryEmailController.text.trim(),
            otp: code,
            newPassword: _resetPasswordController.text,
            confirmPassword: _resetConfirmPasswordController.text,
          ),
    );
    if (!reset || !mounted) return;
    _otpTimer?.cancel();
    _resetPasswordController.clear();
    _resetConfirmPasswordController.clear();
    for (final controller in _otpControllers) {
      controller.clear();
    }
    setState(() => _stage = _AuthStage.login);
    _showMessage(context.l10n.passwordResetComplete);
  }

  Future<void> _resendCode() async {
    final timing = await _performOtpAuth(
      () => context.read<AuthProvider>().resendVerification(
            email: _emailController.text.trim(),
          ),
    );
    if (timing != null && mounted) _startOtpTimer(timing);
  }

  Future<bool> _performAuth(Future<void> Function() action) async {
    try {
      await action();
      return true;
    } on AuthException catch (error) {
      if (mounted) _showMessage(error.message);
      return false;
    }
  }

  Future<OtpTiming?> _performOtpAuth(
    Future<OtpTiming> Function() action,
  ) async {
    try {
      return await action();
    } on AuthException catch (error) {
      if (mounted) _showMessage(error.message);
      return null;
    }
  }

  void _startOtpTimer(OtpTiming timing) {
    _otpTimer?.cancel();
    setState(() {
      _otpExpiresIn = timing.expiresInSeconds;
      _resendIn = timing.resendInSeconds;
      for (final controller in _otpControllers) {
        controller.clear();
      }
    });
    _otpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_otpExpiresIn > 0) _otpExpiresIn--;
        if (_resendIn > 0) _resendIn--;
      });
    });
  }

  String _rwandaPhoneNumber(String phone) {
    var digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('250')) digits = digits.substring(3);
    return '+250$digits';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _maskedEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2 || parts.first.isEmpty) return email;
    final visible = parts.first.length == 1 ? parts.first : parts.first[0];
    return '$visible***@${parts.last}';
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${remainder.toString().padLeft(2, '0')}';
  }

  bool get _isSignupValid =>
      _gender.isNotEmpty &&
      _passwordValidator(_passwordController.text) == null &&
      _confirmPasswordController.text == _passwordController.text &&
      _confirmPasswordController.text.isNotEmpty;

  bool get _isAuthLoading => context.read<AuthProvider>().isLoading;

  static final _titleStyle = GoogleFonts.poppins(
    color: _navy,
    fontSize: 23,
    height: 1.15,
    fontWeight: FontWeight.w700,
  );
  static final _eyebrowStyle = GoogleFonts.inter(
    color: _green,
    fontSize: 11.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
  );
  static const _fieldTextStyle = TextStyle(
    fontFamily: 'Inter',
    color: _navy,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _BrandMark(size: 42),
          const SizedBox(width: 9),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MPUZA',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Connecting People',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.25,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF073B5B),
        border: Border.all(color: Colors.white, width: 2),
      ),
      padding: const EdgeInsets.all(4),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF0B3C5D),
        ),
        child: const Center(
          child: Icon(Icons.equalizer, color: Color(0xFFFAD201), size: 23),
        ),
      ),
    );
  }
}

class _BrandBackdropPainter extends CustomPainter {
  const _BrandBackdropPainter({required this.isMobile});

  final bool isMobile;

  @override
  void paint(Canvas canvas, Size size) {
    const blueGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF0090CC), Color(0xFF37BAEA)],
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = blueGradient.createShader(Offset.zero & size),
    );

    final sunCenter = Offset(size.width * 0.85, size.height * 0.115);
    final sunRadius = math.min(size.width, size.height) * 0.15;
    canvas.drawCircle(
      sunCenter,
      sunRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFB4DB83).withValues(alpha: 0.60),
            const Color(0xFFB4DB83).withValues(alpha: 0.20),
            const Color(0x00B4DB83),
          ],
        ).createShader(Rect.fromCircle(center: sunCenter, radius: sunRadius)),
    );

    final waveTop = size.height * (isMobile ? 0.145 : 0.245);
    final waveBottom = size.height * (isMobile ? 0.205 : 0.315);
    final greenPath = Path()
      ..moveTo(0, waveBottom)
      ..cubicTo(
        size.width * 0.30,
        waveBottom - size.height * 0.026,
        size.width * 0.63,
        waveBottom - size.height * 0.006,
        size.width,
        waveBottom + size.height * 0.008,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      greenPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A7A4F), Color(0xFF17482E)],
        ).createShader(Offset.zero & size),
    );

    final yellowPath = Path()
      ..moveTo(0, waveTop)
      ..cubicTo(
        size.width * 0.28,
        waveTop - size.height * 0.018,
        size.width * 0.64,
        waveTop + size.height * 0.022,
        size.width,
        waveTop - size.height * 0.004,
      )
      ..lineTo(size.width, waveBottom + size.height * 0.008)
      ..cubicTo(
        size.width * 0.64,
        waveBottom - size.height * 0.014,
        size.width * 0.30,
        waveBottom - size.height * 0.026,
        0,
        waveBottom,
      )
      ..close();
    const yellowGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFFFE23A), Color(0xFFFAD201)],
    );
    canvas.drawPath(
      yellowPath,
      Paint()
        ..shader = yellowGradient.createShader(Offset.zero & size)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5),
    );
    canvas.drawPath(
      yellowPath,
      Paint()..shader = yellowGradient.createShader(Offset.zero & size),
    );

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (final offset in [0.038, 0.075]) {
      final path = Path()
        ..moveTo(0, size.height * offset)
        ..cubicTo(
          size.width * 0.27,
          size.height * (offset - 0.02),
          size.width * 0.67,
          size.height * (offset + 0.025),
          size.width,
          size.height * (offset + 0.003),
        );
      canvas.drawPath(path, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BrandBackdropPainter oldDelegate) =>
      isMobile != oldDelegate.isMobile;
}

class _SuccessMark extends StatelessWidget {
  const _SuccessMark();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 144,
      height: 144,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 144,
            height: 144,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFFAF1B6),
            ),
          ),
          Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF4C7F39),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF36663C).withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Color(0xFFE7E9BD),
              size: 54,
            ),
          ),
          const Positioned(
              top: 0, child: _SuccessDot(color: Color(0xFF20603D))),
          const Positioned(
            right: 8,
            top: 24,
            child: _SuccessDot(color: Color(0xFF00A1DE)),
          ),
          const Positioned(
            left: 8,
            top: 38,
            child: _SuccessDot(color: Color(0xFFFAD201)),
          ),
          const Positioned(
            right: 12,
            bottom: 20,
            child: _SuccessDot(color: Color(0xFFFAD201)),
          ),
          const Positioned(
            left: 14,
            bottom: 28,
            child: _SuccessDot(color: Color(0xFF20603D)),
          ),
        ],
      ),
    );
  }
}

class _SuccessDot extends StatelessWidget {
  const _SuccessDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
