import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:momentum/screens/onboarding_screen.dart';

void main() {
  testWidgets('OnboardingScreen renders correctly and shows slides', (
    WidgetTester tester,
  ) async {
    // Build the widget tree with ProviderScope as Onboarding Screen uses settings providers
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: OnboardingScreen())),
    );

    // 1. Verify Welcome Slide renders
    expect(find.text('Build Stronger Habits'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);

    // 2. Click "Next" to progress the PageView
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle(); // Allow page animations to settle

    // 3. Verify Coach Personality choice slide renders
    expect(find.text('Choose Your Coach Style'), findsOneWidget);
    expect(find.text('Strict Coach'), findsOneWidget);
    expect(find.text('Friendly'), findsOneWidget);
  });
}
