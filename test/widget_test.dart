import 'package:flutter_test/flutter_test.dart';
import 'package:nova_hub/main.dart';

void main() {
  testWidgets('App should render', (WidgetTester tester) async {
    await tester.pumpWidget(const NovaHubApp());
    expect(find.text('NOVA HUB'), findsOneWidget);
  });
}
