import 'package:flutter_test/flutter_test.dart';

import 'package:listen_up/app/app.dart';

void main() {
  testWidgets('App renders home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const App());

    // Verify that the app title is displayed
    expect(find.text('Listen Up'), findsOneWidget);

    // Verify that the text input hint is displayed
    expect(find.text('Paste or type your text here...'), findsOneWidget);
  });
}
