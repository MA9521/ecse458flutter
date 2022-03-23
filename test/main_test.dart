import 'package:flutter_test/flutter_test.dart';

import 'package:ecse458flutter/main.dart';

void main() {
  group('Propofol calculator', () {
    test('correctly determines number of bottles', () {
      expect(MyHomePageState().neededBottlesAndWaste(265.5), [1, 1, 2, 4.5]);
    });
    test('correctly determines the GHG impact of used propofol', () {
      expect(
          MyHomePageState().getPropofolImpact(
            265.5,
            isUsed: true,
            duration: 60,
            nbSyringes: 1,
          ),
          0.00543166666 * 265.5 + 0.6795 + 60 * 0.00009476);
    });

    test('correctly determines the GHG impact of uwasted propofol', () {
      expect(MyHomePageState().getPropofolImpact(4.5), 0.00543166666 * 4.5);
    });
  });

  group('Gas calculator', () {
    test('correctly computes the GHG based on a primary gas', () {
      expect(MyHomePageState().getGasImpact('sevo', 1.5, 80),
          49.3115 * 1.5 * 80 / 70);
    });
  });

  group('GHG to km Converter', () {
    test('correctly computes the km driven based on GHG', () {
      expect(MyHomePageState().convertKgCO2ToKmDriven(1), 5.57413600892);
    });
  });
}
