import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ecse458flutter/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets("Verify UI functionality and display of results after inputs",
      (WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle();

    final administrationDropdown =
        find.byKey(const ValueKey('administrationdropdown'));
    await pumpUntilFound(tester, administrationDropdown,
        timeout: const Duration(seconds: 30));
    await tester.tap(administrationDropdown);
    await tester.pumpAndSettle();

    await tester.tap(find.text('IV (Propofol)').last);
    await tester.pumpAndSettle();

    final durationField = find.byKey(const ValueKey('durationfield'));
    await tester.tap(durationField);
    await tester.enterText(durationField, '60');

    final volumeField = find.byKey(const ValueKey('volumefield'));
    await tester.tap(volumeField);
    await tester.enterText(volumeField, '265');

    final nbSyringesField = find.byKey(const ValueKey('nbsyringesfield'));
    await tester.tap(nbSyringesField);
    await tester.enterText(nbSyringesField, '1');

    expect(find.textContaining('You will need'), findsNothing);

    final computeButton = find.byKey(const ValueKey('computebutton'));
    await tester.tap(computeButton);
    await tester.pumpAndSettle();
    await pumpUntilFound(tester, find.textContaining('You will need'));
    expect(find.textContaining('You will need'), findsOneWidget);
    expect(
        find.textContaining(
            'The total propofol (270 mL) and 1 syringes are responsible '
            'for 2.152 kg CO'),
        findsOneWidget);
  });
}

Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  bool timerDone = false;
  final timer =
      Timer(timeout, () => throw TimeoutException("Pump until has timed out"));
  while (timerDone != true) {
    await tester.pump();

    final found = tester.any(finder);
    if (found) {
      timerDone = true;
    }
  }
  timer.cancel();
}
