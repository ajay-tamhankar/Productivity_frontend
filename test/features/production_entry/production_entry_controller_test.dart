import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_tracker/features/production_entry/production_entry_provider.dart';

void main() {
  group('ProductionEntryController calculations', () {
    late ProductionEntryController controller;

    setUp(() {
      controller = ProductionEntryController();
    });

    test('calculateRunningHours should correctly compute the difference within the same day', () {
      final start = const TimeOfDay(hour: 8, minute: 0); // 8:00 AM
      final end = const TimeOfDay(hour: 16, minute: 30); // 4:30 PM
      
      final runningHours = controller.calculateRunningHours(start, end);
      expect(runningHours, 8.5); // 8 hours and 30 minutes
    });

    test('calculateRunningHours should correctly compute time crossing midnight', () {
      final start = const TimeOfDay(hour: 22, minute: 0); // 10:00 PM
      final end = const TimeOfDay(hour: 6, minute: 15); // 6:15 AM
      
      final runningHours = controller.calculateRunningHours(start, end);
      expect(runningHours, 8.25); // 8 hours and 15 minutes
    });

    test('calculatePartsPerHour returns correct rate', () {
      final rate = controller.calculatePartsPerHour(1000, 8.0);
      expect(rate, 125.0);
    });

    test('calculatePartsPerHour returns 0 when runningHours is 0 or negative', () {
      expect(controller.calculatePartsPerHour(1000, 0), 0);
      expect(controller.calculatePartsPerHour(1000, -5), 0);
    });

    test('calculateWeightInKGs converts grams correctly', () {
      // 1000 parts * 250 grams = 250,000 grams = 250 kgs
      final weight = controller.calculateWeightInKGs(1000, 250.0);
      expect(weight, 250.0);
    });
  });
}
