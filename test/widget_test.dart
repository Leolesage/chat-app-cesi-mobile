import 'package:flutter_test/flutter_test.dart';

import 'package:chat_app/app.dart';

void main() {
  testWidgets('Login screen shows required fields', (WidgetTester tester) async {
    await tester.pumpWidget(const ChatApp());

    expect(find.text('CESI Chat'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Mot de passe'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
  });
}
