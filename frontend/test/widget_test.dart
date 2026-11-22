import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:translation_platform/l10n/app_localizations_extensions.dart';
import 'package:translation_platform/l10n/generated/app_localizations.dart';
import 'package:translation_platform/screens/auth/auth_screen.dart';
import 'package:translation_platform/providers/auth_provider.dart';
import 'package:translation_platform/screens/home/home_screen.dart';
import 'package:translation_platform/widgets/app_header.dart';
import 'package:translation_platform/widgets/app_sidebar.dart';
import 'package:translation_platform/main.dart' as app;

void expectLoginBlueButton(
  WidgetTester tester,
  Key key, {
  bool disabled = false,
}) {
  final button = tester.widget<ElevatedButton>(find.byKey(key));
  expect(
    button.style?.backgroundColor?.resolve(
      disabled ? {WidgetState.disabled} : {},
    ),
    const Color(0xFF00A1DE),
  );
}

void main() {
  testWidgets('Kinyarwanda locale retains Flutter material localizations',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'auth_access_token': 'test-token',
      'auth_token_expiry':
          DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch,
      'auth_username': 'jean_claude',
      'auth_email': 'jean@example.com',
    });
    final provider = AuthProvider(dio: _fakeAuthDio());
    await provider.restoreSession();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: provider),
          ChangeNotifierProvider(create: (_) => AppSidebarController()),
        ],
        child: const app.MyApp(),
      ),
    );

    await tester.tap(find.byTooltip('Select language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('French'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Choisir la langue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kinyarwanda'));
    await tester.pumpAndSettle();

    expect(find.text('Tangira gusemura'), findsOneWidget);
    expect(provider.systemLanguage, 'rw');
    expect(tester.takeException(), isNull);
  });

  testWidgets('language selector changes the displayed interface language',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'auth_access_token': 'test-token',
      'auth_token_expiry':
          DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch,
      'auth_username': 'jean_claude',
      'auth_email': 'jean@example.com',
    });
    final provider = AuthProvider(dio: _fakeAuthDio());
    await provider.restoreSession();

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: provider,
        child: Consumer<AuthProvider>(
          builder: (context, auth, _) => MaterialApp(
            locale: Locale(auth.systemLanguage),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              appBar: AppBar(actions: const [AppLanguageSelector()]),
              body: Builder(
                builder: (context) => Text(context.l10n.home),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Home'), findsOneWidget);
    await tester.tap(find.byTooltip('Select language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('French'));
    await tester.pumpAndSettle();

    expect(find.text('Accueil'), findsOneWidget);
    expect(provider.systemLanguage, 'fr');
    expect(tester.takeException(), isNull);
  });

  testWidgets('home logo is beside the sidebar menu', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: _TestAuthProvider(),
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final menuPosition =
        tester.getCenter(find.byTooltip('Open navigation menu'));
    final logoPosition = tester.getCenter(find.byType(AppBrandLogo));
    final languagePosition =
        tester.getCenter(find.byTooltip('Select language'));

    expect(logoPosition.dx, greaterThan(menuPosition.dx));
    expect(logoPosition.dx - menuPosition.dx, lessThan(60));
    expect(languagePosition.dx, greaterThan(logoPosition.dx));
    expect((logoPosition.dy - menuPosition.dy).abs(), lessThan(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('auth flow starts at login and opens signup', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpAuthApp(tester);

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
    expectLoginBlueButton(tester, const ValueKey('login-submit'));

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('STEP 1 OF 2'), findsOneWidget);
    expectLoginBlueButton(tester, const ValueKey('signup-continue'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('login eye toggles password visibility', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpAuthApp(tester);
    final passwordField = find.byKey(const ValueKey('login-password'));
    final editablePassword = find.descendant(
      of: passwordField,
      matching: find.byType(EditableText),
    );
    expect(tester.widget<EditableText>(editablePassword).obscureText, isTrue);

    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pump();

    expect(tester.widget<EditableText>(editablePassword).obscureText, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('auth layout fits phone, tablet, and desktop viewports',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final size in [
      const Size(360, 640),
      const Size(390, 844),
      const Size(768, 1024),
      const Size(1440, 900),
    ]) {
      tester.view.physicalSize = size;
      await _pumpAuthApp(tester);
      await tester.pumpAndSettle();

      expect(find.text('Welcome back'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'Viewport $size');
    }
  });

  testWidgets('auth layout handles a zero-sized startup viewport',
      (tester) async {
    tester.view.physicalSize = Size.zero;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpAuthApp(tester);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('signup can preview the OTP and verified screens',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpAuthApp(tester);
    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('signup-username')),
      'jean_claude',
    );
    await tester.enterText(
      find.byKey(const ValueKey('signup-email')),
      'jean@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('signup-phone')),
      '781234567',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('signup-continue')));
    await tester.tap(find.byKey(const ValueKey('signup-continue')));
    await tester.pumpAndSettle();

    expect(find.text('About you & security'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Male'));
    final selectedGenderButton = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('Male'),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(
      selectedGenderButton.style?.backgroundColor?.resolve({}),
      const Color(0xFF00A1DE),
    );
    expect(
      tester
          .widget<ElevatedButton>(
            find.byKey(const ValueKey('signup-submit')),
          )
          .onPressed,
      isNull,
    );
    expectLoginBlueButton(
      tester,
      const ValueKey('signup-submit'),
      disabled: true,
    );
    await tester.enterText(
      find.byKey(const ValueKey('signup-password')),
      'Mpuza@2026',
    );
    await tester.enterText(
      find.byKey(const ValueKey('signup-confirm-password')),
      'Mpuza@2026',
    );
    await tester.pump();
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('signup-password')),
          )
          .controller!
          .text,
      'Mpuza@2026',
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('signup-confirm-password')),
          )
          .controller!
          .text,
      'Mpuza@2026',
    );
    expect(
      tester
          .widget<ElevatedButton>(
            find.byKey(const ValueKey('signup-submit')),
          )
          .onPressed,
      isNotNull,
    );
    expectLoginBlueButton(tester, const ValueKey('signup-submit'));
    await tester.ensureVisible(find.byKey(const ValueKey('signup-submit')));
    await tester.tap(find.byKey(const ValueKey('signup-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Verify your email'), findsOneWidget);
    expectOtpExpiryShown(tester, minutes: 15);
    expectLoginBlueButton(tester, const ValueKey('verify-submit'));
    expect(tester.takeException(), isNull);
    for (var index = 0; index < 6; index++) {
      await tester.enterText(find.byType(TextField).at(index), '1');
    }
    await tester.ensureVisible(find.byKey(const ValueKey('verify-submit')));
    await tester.tap(find.byKey(const ValueKey('verify-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Email verified!'), findsOneWidget);
    expectLoginBlueButton(tester, const ValueKey('verified-login'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('password recovery requests and submits a reset code',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpAuthApp(tester);
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Enter the email address linked to your MPUZA account. We will send you a reset code.'),
        findsOneWidget);
    for (final size in [
      const Size(360, 640),
      const Size(390, 844),
      const Size(768, 1024),
      const Size(1440, 900),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Forgot viewport $size');
    }
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('recovery-email')),
      'jean@example.com',
    );
    await tester.tap(find.byKey(const ValueKey('recovery-request')));
    await tester.pumpAndSettle();
    expect(find.text('Reset your password'), findsOneWidget);
    expectOtpExpiryShown(tester, minutes: 15);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text && widget.data?.startsWith('Resend in 01:') == true,
      ),
      findsOneWidget,
    );
    for (final size in [
      const Size(360, 640),
      const Size(390, 844),
      const Size(768, 1024),
      const Size(1440, 900),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Reset viewport $size');
    }
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();

    for (var index = 0; index < 6; index++) {
      await tester.enterText(find.byType(TextField).at(index), '1');
    }
    await tester.enterText(
      find.byKey(const ValueKey('recovery-password')),
      'Mpuza@2026',
    );
    await tester.enterText(
      find.byKey(const ValueKey('recovery-confirm-password')),
      'Mpuza@2026',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('recovery-reset')));
    await tester.tap(find.byKey(const ValueKey('recovery-reset')));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home landing page shows the localized translation action',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = _TestAuthProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: provider,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomeScreen(),
        ),
      ),
    );

    expect(find.text('Start Translating'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sidebar logout returns to the login and signup screen',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = _TestAuthProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: provider),
          ChangeNotifierProvider(create: (_) => AppSidebarController()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer<AuthProvider>(
            builder: (context, auth, _) => auth.isAuthenticated
                ? const _AuthenticatedTestHome()
                : const AuthScreen(),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open translation'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(provider.isAuthenticated, isFalse);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void expectOtpExpiryShown(WidgetTester tester, {required int minutes}) {
  expect(
    find.byWidgetPredicate(
      (widget) =>
          widget is RichText &&
          widget.text.toPlainText().startsWith('Code expires in $minutes:'),
    ),
    findsOneWidget,
  );
}

Future<void> _pumpAuthApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => AuthProvider(dio: _fakeAuthDio()),
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AuthScreen(),
      ),
    ),
  );
}

Dio _fakeAuthDio() {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final response = switch (options.path) {
          '/api/users/me/system-language' => (
              200,
              {
                'system_language':
                    (options.data as Map<String, dynamic>)['system_language'],
              },
            ),
          '/api/users/signup' => (
              201,
              {
                'message': 'Verification code sent to your email address.',
                'expires_in': 937,
                'resend_in': 83,
              },
            ),
          '/api/users/verify-email' => (
              200,
              {'message': 'Email address verified.'},
            ),
          '/api/users/login' => (
              200,
              {
                'access_token': 'test-token',
                'token_type': 'Bearer',
                'expires_in': 3600,
                'user': {
                  'username': 'jean_claude',
                  'email': 'jean@example.com',
                },
              },
            ),
          '/api/users/forgot-password' => (
              202,
              {
                'message': 'If the account exists, a reset code has been sent.',
                'expires_in': 937,
                'resend_in': 83,
              },
            ),
          '/api/users/reset-password' => (
              200,
              {'message': 'Password has been reset.'},
            ),
          '/api/users/resend-verification' => (
              202,
              {
                'message': 'Verification code resent.',
                'expires_in': 937,
                'resend_in': 83,
              },
            ),
          _ => (200, <String, Object>{}),
        };
        handler.resolve(
          Response<dynamic>(
            requestOptions: options,
            statusCode: response.$1,
            data: response.$2,
          ),
        );
      },
    ),
  );
  return dio;
}

class _TestAuthProvider extends AuthProvider {
  bool _loggedOut = false;

  @override
  bool get isAuthenticated => !_loggedOut;

  @override
  UserModel? get user => UserModel(
        name: 'jean_claude',
        email: 'jean@example.com',
        photoURL: '',
      );

  @override
  Future<void> logout() async {
    _loggedOut = true;
    notifyListeners();
  }
}

class _AuthenticatedTestHome extends StatelessWidget {
  const _AuthenticatedTestHome();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const _AuthenticatedTestPage(),
              ),
            );
          },
          child: const Text('Open translation'),
        ),
      ),
    );
  }
}

class _AuthenticatedTestPage extends StatelessWidget {
  const _AuthenticatedTestPage();

  @override
  Widget build(BuildContext context) {
    return AppPageShell(
      child: Scaffold(
        appBar: AppBar(leading: const AppMenuButton()),
        body: const SizedBox.shrink(),
      ),
    );
  }
}
