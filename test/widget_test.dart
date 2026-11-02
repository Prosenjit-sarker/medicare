// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:medicare_bd/app/theme.dart';
import 'package:medicare_bd/features/auth/presentation/welcome_screen.dart';

void main() {
  testWidgets('app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: Center(child: Text('MediCare'))),
        ),
      ),
    );

    expect(find.text('MediCare'), findsOneWidget);
  });

  testWidgets('Get started opens sign in', (WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/welcome',
      routes: [
        GoRoute(path: '/welcome', builder: (_, _) => const WelcomePage()),
        GoRoute(
          path: '/login',
          builder: (_, _) => const Scaffold(body: Text('Sign in screen')),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router, theme: buildTheme()));
    expect(find.text('Get started'), findsOneWidget);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in screen'), findsOneWidget);
    router.dispose();
  });
}
