`import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enchante_app/main.dart';

void main() {
  testWidgets('uses Enchante green as the primary theme color', (tester) async {
    await tester.pumpWidget(const EnchanteApp(home: SizedBox.shrink()));
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme!.colorScheme.primary, const Color(0xFF2E6F40));
  });

  testWidgets('sign in requires username, email, and password', (tester) async {
    await tester.pumpWidget(const EnchanteApp(home: AuthScreen()));
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('New here? Create an account'), findsNothing);
    expect(find.text('Create account'), findsNothing);
  });
}
