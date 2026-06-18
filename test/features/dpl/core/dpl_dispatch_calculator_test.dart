import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_tracker/features/dpl/core/dpl_dispatch_calculator.dart';

void main() {
  group('DplDispatchCalculator.calculatePart', () {
    test(
        'worked example 103D1: needs 50, GA has 80, dispatches 50, '
        'closes TML at buffer target', () {
      final result = DplDispatchCalculator.calculatePart(
        const DispatchCalcInput(
          partId: 1,
          customerPn: '549169500103D1',
          description: '103D1',
          bufferTargetAtTml: 35,
          trolleyCapacity: 25,
          tmlOpeningStock: 10,
          customerPlanToday: 25,
          gaOpeningStock: 50,
          gaProductionToday: 30,
        ),
      );

      expect(result.neededAtTml, 50, reason: '35 − 10 + 25 = 50');
      expect(result.availableAtGa, 80, reason: '50 + 30 = 80');
      expect(result.dispatchToday, 50, reason: 'min(50, 80) = 50');
      expect(result.shortage, 0, reason: 'GA can fully cover');
      expect(result.hasShortage, isFalse);
      expect(result.isQuiet, isFalse);

      expect(
        result.projectedTmlClosingStock,
        35,
        reason: 'TML closes exactly at buffer target',
      );
      expect(
        result.projectedGaClosingStock,
        30,
        reason: 'GA keeps 30 NOS at end of day',
      );

      // 50 NOS / 25-cap trolleys = 2 trolleys → split across 6 trips:
      //   [1, 1, 0, 0, 0, 0]
      expect(result.totalTrolleys, 2);
      expect(result.tripTrolleySplit, [1, 1, 0, 0, 0, 0]);
      expect(result.tripQtySplit, [25, 25, 0, 0, 0, 0]);
      expect(
        result.tripQtySplit.fold<int>(0, (s, v) => s + v),
        equals(result.dispatchToday),
        reason: 'trip qty split must sum to dispatchToday',
      );
    });

    test('shortage: GA can\'t fully cover the customer need', () {
      final result = DplDispatchCalculator.calculatePart(
        const DispatchCalcInput(
          partId: 2,
          customerPn: '546469500114ZY',
          description: '114ZY',
          bufferTargetAtTml: 100,
          trolleyCapacity: 20,
          tmlOpeningStock: 18,
          customerPlanToday: 0,
          gaOpeningStock: 30,
          gaProductionToday: 30,
        ),
      );

      // needed = max(0, 100 − 18 + 0) = 82
      // available = 30 + 30 = 60
      // dispatch = min(82, 60) = 60
      // shortage = 82 − 60 = 22
      expect(result.neededAtTml, 82);
      expect(result.availableAtGa, 60);
      expect(result.dispatchToday, 60);
      expect(result.shortage, 22);
      expect(result.hasShortage, isTrue);

      // TML doesn't reach buffer target due to shortage.
      // closing = 18 − 0 + 60 = 78 (target 100, short by 22 ✓)
      expect(result.projectedTmlClosingStock, 78);
      expect(result.projectedGaClosingStock, 0);

      // 60 / 20 = 3 trolleys. Split across 6 trips → [1, 1, 1, 0, 0, 0].
      expect(result.totalTrolleys, 3);
      expect(result.tripTrolleySplit, [1, 1, 1, 0, 0, 0]);
      expect(result.tripQtySplit.fold<int>(0, (s, v) => s + v), 60);
    });

    test('customer over-stocked: no dispatch needed', () {
      final result = DplDispatchCalculator.calculatePart(
        const DispatchCalcInput(
          partId: 3,
          customerPn: '999',
          description: 'OVR',
          bufferTargetAtTml: 30,
          trolleyCapacity: 25,
          tmlOpeningStock: 60, // already over the 30+0 buffer-and-call
          customerPlanToday: 0,
          gaOpeningStock: 40,
          gaProductionToday: 20,
        ),
      );

      // needed = max(0, 30 − 60 + 0) = 0
      expect(result.neededAtTml, 0);
      expect(result.dispatchToday, 0);
      expect(result.shortage, 0);
      expect(result.isQuiet, isTrue);
      expect(result.totalTrolleys, 0);
      expect(result.tripTrolleySplit, [0, 0, 0, 0, 0, 0]);
      expect(result.tripQtySplit, [0, 0, 0, 0, 0, 0]);
      expect(result.projectedTmlClosingStock, 60);
      expect(result.projectedGaClosingStock, 60);
    });

    test('uneven split: 8 trolleys over 6 trips front-loads correctly', () {
      // dispatch 200, trolley cap 25 → 8 trolleys, 6 trips
      // → [2, 2, 1, 1, 1, 1] = 8 total
      final result = DplDispatchCalculator.calculatePart(
        const DispatchCalcInput(
          partId: 4,
          customerPn: 'TEST',
          description: 'T',
          bufferTargetAtTml: 200,
          trolleyCapacity: 25,
          tmlOpeningStock: 0,
          customerPlanToday: 0,
          gaOpeningStock: 0,
          gaProductionToday: 200,
        ),
      );
      expect(result.dispatchToday, 200);
      expect(result.totalTrolleys, 8);
      expect(result.tripTrolleySplit, [2, 2, 1, 1, 1, 1]);
      expect(result.tripQtySplit, [50, 50, 25, 25, 25, 25]);
      expect(result.tripQtySplit.fold<int>(0, (s, v) => s + v), 200);
    });

    test(
        'partial trolley at end of day: last trip carries fewer NOS than '
        'capacity to make the sum match exactly', () {
      // dispatch 45, trolley cap 20 → 3 trolleys (would carry 60 if full).
      // Split [1, 1, 1, 0, 0, 0] = qty [20, 20, 20] = 60 raw.
      // Overshoot = 60 − 45 = 15; reduce the last loaded trip: 20 − 15 = 5.
      // Final tripQtySplit = [20, 20, 5, 0, 0, 0] = 45 ✓.
      final result = DplDispatchCalculator.calculatePart(
        const DispatchCalcInput(
          partId: 5,
          customerPn: 'TEST',
          description: 'T',
          bufferTargetAtTml: 45,
          trolleyCapacity: 20,
          tmlOpeningStock: 0,
          customerPlanToday: 0,
          gaOpeningStock: 0,
          gaProductionToday: 45,
        ),
      );
      expect(result.dispatchToday, 45);
      expect(result.totalTrolleys, 3);
      expect(result.tripQtySplit, [20, 20, 5, 0, 0, 0]);
      expect(result.tripQtySplit.fold<int>(0, (s, v) => s + v), 45);
    });

    test('zero buffer target with positive call-off → still tops up', () {
      final result = DplDispatchCalculator.calculatePart(
        const DispatchCalcInput(
          partId: 6,
          customerPn: 'TEST',
          description: 'T',
          bufferTargetAtTml: 0,
          trolleyCapacity: 25,
          tmlOpeningStock: 0,
          customerPlanToday: 50,
          gaOpeningStock: 30,
          gaProductionToday: 30,
        ),
      );
      // needed = max(0, 0 − 0 + 50) = 50
      // available = 60, dispatch = 50, no shortage
      expect(result.dispatchToday, 50);
      expect(result.shortage, 0);
      expect(result.projectedTmlClosingStock, 0);
      expect(result.projectedGaClosingStock, 10);
    });

    test('negative inputs are clamped to 0 (defensive)', () {
      final result = DplDispatchCalculator.calculatePart(
        const DispatchCalcInput(
          partId: 7,
          customerPn: 'X',
          description: 'X',
          bufferTargetAtTml: -10,
          trolleyCapacity: 0,
          tmlOpeningStock: -5,
          customerPlanToday: -3,
          gaOpeningStock: -1,
          gaProductionToday: -2,
        ),
      );
      // Everything normalises to 0 → no dispatch.
      expect(result.neededAtTml, 0);
      expect(result.availableAtGa, 0);
      expect(result.dispatchToday, 0);
      expect(result.totalTrolleys, 0);
    });

    test('GA has zero stock + zero production → dispatch 0 even if needed', () {
      final result = DplDispatchCalculator.calculatePart(
        const DispatchCalcInput(
          partId: 8,
          customerPn: 'X',
          description: 'X',
          bufferTargetAtTml: 50,
          trolleyCapacity: 25,
          tmlOpeningStock: 0,
          customerPlanToday: 25,
          gaOpeningStock: 0,
          gaProductionToday: 0,
        ),
      );
      expect(result.neededAtTml, 75);
      expect(result.availableAtGa, 0);
      expect(result.dispatchToday, 0);
      expect(result.shortage, 75);
      expect(result.hasShortage, isTrue);
    });
  });

  group('DplDispatchCalculator.calculateBatch', () {
    test('rolls up totals + flags shortages across multiple parts', () {
      final batch = DplDispatchCalculator.calculateBatch(
        planDate: DateTime(2026, 6, 17),
        inputs: const [
          // 103D1 — full dispatch, no shortage (worked example)
          DispatchCalcInput(
            partId: 1,
            customerPn: '549169500103D1',
            description: '103D1',
            bufferTargetAtTml: 35,
            trolleyCapacity: 25,
            tmlOpeningStock: 10,
            customerPlanToday: 25,
            gaOpeningStock: 50,
            gaProductionToday: 30,
          ),
          // 114ZY — shortage scenario
          DispatchCalcInput(
            partId: 2,
            customerPn: '546469500114ZY',
            description: '114ZY',
            bufferTargetAtTml: 100,
            trolleyCapacity: 20,
            tmlOpeningStock: 18,
            customerPlanToday: 0,
            gaOpeningStock: 30,
            gaProductionToday: 30,
          ),
          // Over-stocked — no dispatch
          DispatchCalcInput(
            partId: 3,
            customerPn: 'X',
            description: 'X',
            bufferTargetAtTml: 30,
            trolleyCapacity: 25,
            tmlOpeningStock: 60,
            customerPlanToday: 0,
            gaOpeningStock: 40,
            gaProductionToday: 20,
          ),
        ],
      );

      expect(batch.perPart.length, 3);
      expect(batch.totalDispatchQty, 50 + 60 + 0);
      expect(batch.totalTrolleys, 2 + 3 + 0);
      expect(batch.shortageCount, 1);
      expect(batch.totalShortageQty, 22);
      expect(batch.hasAnyShortage, isTrue);
      expect(batch.planDate, DateTime(2026, 6, 17));
    });

    test('empty input list → zero totals, no shortage', () {
      final batch = DplDispatchCalculator.calculateBatch(
        planDate: DateTime(2026, 6, 17),
        inputs: const [],
      );
      expect(batch.perPart, isEmpty);
      expect(batch.totalDispatchQty, 0);
      expect(batch.totalTrolleys, 0);
      expect(batch.shortageCount, 0);
      expect(batch.totalShortageQty, 0);
      expect(batch.hasAnyShortage, isFalse);
    });
  });
}
