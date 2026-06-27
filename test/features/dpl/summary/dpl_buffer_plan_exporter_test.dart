import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_tracker/features/dpl/summary/services/dpl_buffer_plan_exporter.dart';

void main() {
  group('DplBufferPlanWorkbook.rollForward', () {
    test('seeds at first non-null then carries forward (reference formula)', () {
      // Opn Stock at TML: seed 35, plus = Dispatch, minus = Customer Plan.
      // day0 seed=35; day1 = 35 + disp0(10) - plan0(6) = 39;
      // day2 = 39 + disp1(0) - plan1(9) = 30; day3 = 30 + disp2(39) - plan2(52) = 17
      final out = DplBufferPlanWorkbook.rollForward(
        seedSeries: [35, null, null, null],
        plus: [10, 0, 39, 0],
        minus: [6, 9, 52, 0],
      );
      expect(out, [35, 39, 30, 17]);
    });

    test('treats null flows as zero', () {
      final out = DplBufferPlanWorkbook.rollForward(
        seedSeries: [14, null, null],
        plus: [null, 70, null],
        minus: [null, null, null],
      );
      expect(out, [14, 14, 84]);
    });

    test('leaves everything null when there is no seed', () {
      final out = DplBufferPlanWorkbook.rollForward(
        seedSeries: [null, null, null],
        plus: [5, 5, 5],
        minus: [1, 1, 1],
      );
      expect(out, [null, null, null]);
    });

    test('days before the seed stay null; seed mid-series rolls forward', () {
      final out = DplBufferPlanWorkbook.rollForward(
        seedSeries: [null, 100, null, null],
        plus: [9, 9, 20, 9], // only index>=seed matters
        minus: [9, 9, 5, 9],
      );
      // day0 null; day1 seed=100; day2 = 100 + 9 - 9 = 100; day3 = 100 + 20 - 5 = 115
      expect(out, [null, 100, 100, 115]);
    });
  });

  group('DplBufferPlanExporter.build', () {
    DplBufferPlanPlant samplePlant(String code, String name) {
      final parts = <DplBufferPlanPart>[
        const DplBufferPlanPart(
          partId: 1,
          customerPn: '546469500114ZY',
          description: '114ZY',
          partName: 'X0',
        ),
        const DplBufferPlanPart(
          partId: 2,
          customerPn: '546769500130D1',
          description: '130D1',
          partName: '6AB',
        ),
      ];
      final cells = <int, List<DplBufferPlanCell>>{
        1: const [
          DplBufferPlanCell(
            opnStockTml: 400,
            productionGa: 80,
            dispatchGa: 120,
            customerPlan: 100,
          ),
          DplBufferPlanCell(
            opnStockTml: 380,
            productionGa: 60,
            customerPlan: 100,
          ),
          DplBufferPlanCell(),
        ],
        2: const [
          DplBufferPlanCell(
            opnStockTml: 200,
            productionGa: 40,
            dispatchGa: 60,
            customerPlan: 50,
          ),
          DplBufferPlanCell(),
          DplBufferPlanCell(opnStockTml: 150, dispatchGa: 30),
        ],
      };
      return DplBufferPlanPlant(
        plantCode: code,
        plantName: name,
        parts: parts,
        cells: cells,
      );
    }

    DplBufferPlanWorkbook sampleWorkbook() {
      final days = <DateTime>[
        DateTime(2026, 5, 1),
        DateTime(2026, 5, 2),
        DateTime(2026, 5, 3),
      ];
      return DplBufferPlanWorkbook(
        year: 2026,
        month: 5,
        days: days,
        plants: [
          samplePlant('NEXON_EV', 'Nexon EV'),
          samplePlant('TML_PV', 'TML PV'),
          samplePlant('MG', 'MG Motors'),
        ],
      );
    }

    test('encodes a non-empty, valid xlsx (zip magic bytes), one sheet/plant',
        () {
      final bytes = DplBufferPlanExporter.build(sampleWorkbook());
      expect(bytes.length, greaterThan(0));
      // .xlsx is a ZIP container → first two bytes are 'P','K'.
      expect(bytes[0], 0x50);
      expect(bytes[1], 0x4B);
    });

    test('handles a fully-empty workbook without throwing', () {
      final wb = DplBufferPlanWorkbook(
        year: 2026,
        month: 2,
        days: <DateTime>[for (var d = 1; d <= 28; d++) DateTime(2026, 2, d)],
        plants: const [
          DplBufferPlanPlant(
            plantCode: 'MG',
            plantName: 'MG Motors',
            parts: [],
            cells: {},
          ),
        ],
      );
      final bytes = DplBufferPlanExporter.build(wb);
      expect(bytes[0], 0x50);
      expect(bytes[1], 0x4B);
    });

    test('handles plants with duplicate display names (unique sheet names)',
        () {
      final days = <DateTime>[DateTime(2026, 5, 1)];
      final wb = DplBufferPlanWorkbook(
        year: 2026,
        month: 5,
        days: days,
        plants: [
          DplBufferPlanPlant(
            plantCode: 'A',
            plantName: 'Plant',
            parts: const [
              DplBufferPlanPart(
                  partId: 1, customerPn: 'X', description: 'x', partName: ''),
            ],
            cells: const {
              1: [DplBufferPlanCell(productionGa: 5)],
            },
          ),
          DplBufferPlanPlant(
            plantCode: 'B',
            plantName: 'Plant',
            parts: const [
              DplBufferPlanPart(
                  partId: 2, customerPn: 'Y', description: 'y', partName: ''),
            ],
            cells: const {
              2: [DplBufferPlanCell(productionGa: 7)],
            },
          ),
        ],
      );
      final bytes = DplBufferPlanExporter.build(wb);
      expect(bytes[0], 0x50);
      expect(bytes[1], 0x4B);
    });
  });
}
