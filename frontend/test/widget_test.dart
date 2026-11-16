import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:translation_platform/core/network/api_client.dart';
import 'package:translation_platform/main.dart';
import 'package:translation_platform/models/user_model.dart';
import 'package:translation_platform/providers/auth_provider.dart';
import 'package:translation_platform/repositories/auth_repository.dart';
import 'package:translation_platform/screens/auth/auth_screen.dart';
import 'package:translation_platform/screens/translation/text_translation_screen.dart';
import 'package:translation_platform/widgets/app_header.dart';
import 'package:translation_platform/widgets/app_sidebar.dart';

const _flutterTtsChannel = MethodChannel('flutter_tts');

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository() : super(ApiClient());

  @override
  void setSessionExpiredHandler(void Function()? handler) {}

  @override
  Future<bool> hasStoredSession() async => false;

  @override
  Future<UserModel> getCurrentUser() async => _testUser;

  @override
  Future<UserModel> login({
    required String identifier,
    required String password,
  }) async =>
      _testUser;

  @override
  Future<String> register({
    required String email,
    required String username,
    required String phoneNumber,
    required String gender,
    required String password,
    required String confirmPassword,
  }) async =>
      'Registration successful. Verify your email before signing in.';

  @override
  Future<String> resendVerification(String email) async => 'Email sent.';

  @override
  Future<String> requestPasswordReset(String email) async => 'Email sent.';

  @override
  Future<void> logout() async {}
}

const _testUser = UserModel(
  email: 'user@example.com',
  username: 'testuser',
  name: 'Test User',
  phoneNumber: '+250788123456',
  gender: 'other',
  emailVerified: true,
);

class _TestFeatureScreen extends StatelessWidget {
  const _TestFeatureScreen();

  @override
  Widget build(BuildContext context) => AppPageShell(
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Feature page'),
            automaticallyImplyLeading: false,
            leading: const AppMenuButton(),
            actions: const [AppBrandControls()],
          ),
          body: const Text('Feature content'),
        ),
      );
}

class _TestHomeScreen extends StatelessWidget {
  const _TestHomeScreen();

  @override
  Widget build(BuildContext context) => AppPageShell(
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            leading: const AppMenuButton(),
            actions: const [AppBrandControls()],
          ),
          body: const Text('Starting page'),
        ),
      );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_flutterTtsChannel, (_) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_flutterTtsChannel, null);
  });

  testWidgets('unauthenticated app opens Home without sign-in', (tester) async {
    final repository = _FakeAuthRepository();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiClient>(
            create: (_) => ApiClient(),
            dispose: (_, client) => client.dispose(),
          ),
          ChangeNotifierProvider(
            create: (_) => AppSidebarController(),
          ),
          ChangeNotifierProvider(
            create: (_) => AuthProvider(repository),
          ),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Start Translating'), findsOneWidget);
    expect(find.text('Email or phone number'), findsNothing);
    expect(find.text('MPUZA'), findsOneWidget);
    expect(find.text('Connecting People'), findsOneWidget);
    expect(find.byTooltip('Open navigation menu'), findsOneWidget);
    expect(find.byTooltip('Select language'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Icon &&
            widget.icon == Icons.translate &&
            widget.size == 80,
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Start Translating'));
    await tester.pumpAndSettle();
    expect(find.text('Text Translation'), findsWidgets);
  });

  testWidgets('registration screen collects required account fields',
      (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider(_FakeAuthRepository()),
        child: const MaterialApp(home: AuthScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();

    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Phone number (include country code)'), findsOneWidget);
    expect(find.text('Gender'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
  });

  testWidgets('sidebar starts collapsed and menu items navigate',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => AuthProvider(_FakeAuthRepository()),
          ),
          ChangeNotifierProvider(
            create: (_) => AppSidebarController(),
          ),
        ],
        child: MaterialApp(
          routes: {
            AppRoutes.home: (_) => const _TestHomeScreen(),
            AppRoutes.textTranslation: (_) => const _TestFeatureScreen(),
          },
          home: const _TestHomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.menu), findsOneWidget);
    expect(find.byTooltip('Text Translation'), findsNothing);
    final menuButton = find.byTooltip('Open navigation menu');
    expect(menuButton, findsOneWidget);
    expect(find.byType(AppSidebar), findsNothing);
    expect(find.text('Starting page'), findsOneWidget);

    await tester.tap(menuButton);
    await tester.pumpAndSettle();
    expect(find.text('Text Translation'), findsOneWidget);
    expect(find.text('Starting page'), findsOneWidget);
    await tester.tap(find.text('Text Translation'));
    await tester.pumpAndSettle();

    expect(find.text('Starting page'), findsNothing);
    expect(find.text('Feature page'), findsOneWidget);
    expect(find.text('Feature content'), findsOneWidget);
    expect(find.text('Text Translation'), findsNothing);
    expect(find.byTooltip('Open navigation menu'), findsOneWidget);
    expect(find.text('Feature page'), findsOneWidget);

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Starting page'), findsOneWidget);
  });

  testWidgets('narrow screens keep the sidebar collapsed and responsive',
      (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => AuthProvider(_FakeAuthRepository()),
          ),
          ChangeNotifierProvider(
            create: (_) => AppSidebarController(),
          ),
        ],
        child: const MaterialApp(
          home: _TestFeatureScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Text Translation'), findsNothing);
    expect(find.byTooltip('Open navigation menu'), findsOneWidget);
    expect(find.text('Feature content'), findsOneWidget);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.text('Text Translation'), findsOneWidget);
    expect(find.text('Feature content'), findsOneWidget);
  });

  testWidgets(
      'translation screen fits Kinyarwanda and keeps typed text visible',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiClient>(
            create: (_) => ApiClient(),
            dispose: (_, client) => client.dispose(),
          ),
          ChangeNotifierProvider(
            create: (_) => AppSidebarController(),
          ),
          ChangeNotifierProvider(
            create: (_) => AuthProvider(_FakeAuthRepository()),
          ),
        ],
        child: const MaterialApp(
          home: TextTranslationScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButton<String>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kinyarwanda').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    const enteredText = 'This text should remain visible while typing.';
    final sourceField = find.byType(TextField);
    await tester.enterText(sourceField, enteredText);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(sourceField).controller!.text, enteredText);
    expect(tester.getRect(sourceField).height, greaterThan(100));
    expect(find.text('Translate'), findsNothing);
    expect(find.text('Translation'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
