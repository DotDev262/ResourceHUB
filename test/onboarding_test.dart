import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resourcehub/auth/signin.dart'; // Assuming SignInPage is in this path
import 'package:resourcehub/pages/onboarding.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('OnboardingPage Widget Tests', () {
    setUp(() async {
      // Mock SharedPreferences for testing
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('renders PageView and dots indicator with correct number of pages', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: OnboardingPage()));

      expect(find.byType(PageView), findsOneWidget);
      expect(find.byType(AnimatedContainer), findsNWidgets(3)); // One for each dot
    });

    testWidgets('initial page is the first page', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: OnboardingPage()));

      expect(find.text('Discover Resources'), findsOneWidget);
    });

    testWidgets('swiping PageView changes the current page and updates dots', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: OnboardingPage()));

      expect(find.text('Discover Resources'), findsOneWidget);
      expect(find.byWidgetPredicate((widget) =>
          widget is AnimatedContainer &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).color == Colors.white), findsOneWidget); // First dot active

      await tester.drag(find.byType(PageView), const Offset(-500.0, 0.0));
      await tester.pumpAndSettle();

      expect(find.text('Discover Resources'), findsNothing);
      expect(find.text('Stay Organized'), findsOneWidget);
      expect(find.byWidgetPredicate((widget) =>
          widget is AnimatedContainer &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).color == Colors.white), findsOneWidget); // Second dot active

      await tester.drag(find.byType(PageView), const Offset(-500.0, 0.0));
      await tester.pumpAndSettle();

      expect(find.text('Stay Organized'), findsNothing);
      expect(find.text('Ready to Start?'), findsOneWidget);
      expect(find.byWidgetPredicate((widget) =>
          widget is AnimatedContainer &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).color == Colors.white), findsOneWidget); // Third dot active
    });

    testWidgets('tapping "Skip" navigates to SignInPage', (WidgetTester tester) async {
      bool navigated = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Navigator(
            onGenerateRoute: (settings) {
              if (settings.name == '/') {
                return MaterialPageRoute(builder: (context) => const OnboardingPage());
              } else if (settings.name == '/signin') {
                navigated = true;
                return MaterialPageRoute(builder: (context) => const SignInPage());
              }
              return null;
            },
          ),
        ),
      );

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(navigated, isTrue);
    });

    testWidgets('tapping "Next" on first page moves to the second page', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: OnboardingPage()));

      expect(find.text('Discover Resources'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_forward));
      await tester.pumpAndSettle();

      expect(find.text('Discover Resources'), findsNothing);
      expect(find.text('Stay Organized'), findsOneWidget);
    });

    testWidgets('tapping "Get Started" on last page navigates to SignInPage', (WidgetTester tester) async {
      bool navigated = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Navigator(
            onGenerateRoute: (settings) {
              if (settings.name == '/') {
                return MaterialPageRoute(builder: (context) => const OnboardingPage());
              } else if (settings.name == '/signin') {
                navigated = true;
                return MaterialPageRoute(builder: (context) => const SignInPage());
              }
              return null;
            },
          ),
        ),
      );

      // Navigate to the last page
      await tester.drag(find.byType(PageView), const Offset(-500.0, 0.0));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(PageView), const Offset(-500.0, 0.0));
      await tester.pumpAndSettle();

      expect(find.text('Ready to Start?'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);

      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      expect(navigated, isTrue);
    });
  });
}