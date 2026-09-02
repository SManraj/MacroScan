import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dietingapp2026/services/water_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final today = DateTime(2026, 9, 1);
  late WaterService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = WaterService();
  });

  group('unit conversion', () {
    test('presets convert to whole millilitres', () {
      expect(WaterUnit.ml.toMl(250), 250);
      expect(WaterUnit.flOz.toMl(8), 237);
      expect(WaterUnit.cup.toMl(1), 237);
    });

    test('round-trips a goal through every unit without drifting', () {
      for (final unit in WaterUnit.values) {
        expect(unit.toMl(unit.fromMl(2000)), 2000, reason: unit.label);
      }
    });

    test('survives values that would overflow or crash round()', () {
      // double.tryParse('9e999') yields infinity, and round() is undefined for
      // it — the conversion must clamp rather than throw.
      expect(WaterUnit.ml.toMl(double.infinity), WaterService.maxEntryMl);
      expect(WaterUnit.cup.toMl(double.infinity), WaterService.maxEntryMl);
      expect(WaterUnit.ml.toMl(1e30), WaterService.maxEntryMl);
      expect(WaterUnit.ml.toMl(double.nan), 0);
      expect(WaterUnit.ml.toMl(-5), 0);
    });

    test('formats whole values without a decimal, fractions with one', () {
      expect(WaterUnit.ml.format(WaterUnit.ml.fromMl(2000)), '2000');
      expect(WaterUnit.cup.format(WaterUnit.cup.fromMl(1183)), '5');
      expect(WaterUnit.cup.format(WaterUnit.cup.fromMl(1000)), '4.2');
    });
  });

  group('logging', () {
    test('adds accumulate and persist across a fresh service', () async {
      await service.add('user-a', today, 250);
      await service.add('user-a', today, 500);
      expect(service.peek('user-a', today)!.totalMl, 750);

      final reopened = WaterService();
      await reopened.ensureLoaded('user-a', today);
      expect(reopened.peek('user-a', today)!.totalMl, 750);
    });

    test('undo removes the last entry exactly, not a fixed amount', () async {
      await service.add('user-a', today, 250);
      await service.add('user-a', today, 500);
      await service.undoLast('user-a', today);

      final day = service.peek('user-a', today)!;
      expect(day.totalMl, 250);
      expect(day.entries.single.ml, 250);
    });

    test('undo on an empty day is a no-op', () async {
      await service.ensureLoaded('user-a', today);
      await service.undoLast('user-a', today);
      expect(service.peek('user-a', today)!.totalMl, 0);
    });

    test('entries get unique client ids', () async {
      await service.add('user-a', today, 250);
      await service.add('user-a', today, 250);

      final ids = service
          .peek('user-a', today)!
          .entries
          .map((e) => e.clientEntryId)
          .toSet();
      expect(ids, hasLength(2));
      expect(ids.every((id) => id.startsWith('user-a-')), isTrue);
    });

    test('days are scoped independently', () async {
      final yesterday = today.subtract(const Duration(days: 1));
      await service.add('user-a', today, 250);
      await service.ensureLoaded('user-a', yesterday);

      expect(service.peek('user-a', today)!.totalMl, 250);
      expect(service.peek('user-a', yesterday)!.totalMl, 0);
    });

    test('one account cannot read another account\'s water', () async {
      await service.add('user-a', today, 750);
      await service.ensureLoaded('user-b', today);
      expect(service.peek('user-b', today)!.totalMl, 0);

      // Switching back restores the first account's data from disk.
      await service.ensureLoaded('user-a', today);
      expect(service.peek('user-a', today)!.totalMl, 750);
    });
  });

  group('goal and unit', () {
    test('defaults to 2000 ml in millilitres', () async {
      await service.loadFor('user-a');
      expect(service.goalMl, WaterService.defaultGoalMl);
      expect(service.unit, WaterUnit.ml);
    });

    test('goal persists per user, unit persists device-wide', () async {
      await service.loadFor('user-a');
      await service.setGoalMl('user-a', 3000);
      await service.setUnit(WaterUnit.cup);

      await service.loadFor('user-b');
      expect(service.goalMl, WaterService.defaultGoalMl);
      expect(service.unit, WaterUnit.cup);

      await service.loadFor('user-a');
      expect(service.goalMl, 3000);
    });

    test('goal is clamped to a sane range', () async {
      await service.loadFor('user-a');
      await service.setGoalMl('user-a', 999999);
      expect(service.goalMl, WaterService.maxGoalMl);
    });
  });
}
