import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enchante_app/main.dart';

void main() {
  testWidgets('uses Enchante green as the primary theme color', (
    tester,
  ) async {
    await tester.pumpWidget(const EnchanteApp(home: SizedBox.shrink()));
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme!.colorScheme.primary, const Color(0xFF2E6F40));
  });

  testWidgets('signup asks for a searchable username', (tester) async {
    await tester.pumpWidget(const EnchanteApp(home: AuthScreen()));
    await tester.tap(find.text('New here? Create an account'));
    await tester.pumpAndSettle();
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
  });
}
