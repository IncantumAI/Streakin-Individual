// test/widget_test.dart
// Basic smoke test: app widget tree builds without errors.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streakin/app/app.dart';

void main() {
  testWidgets('App smoke test — widget tree builds', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: StreakinApp()),
    );
    expect(find.byType(ProviderScope), findsOneWidget);
  });
}
