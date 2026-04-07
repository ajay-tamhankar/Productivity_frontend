import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/models/production_entry_model.dart';
import '../../data/api_services/api_client.dart';

part 'production_entry_provider.g.dart';

@riverpod
class ProductionEntryController extends _$ProductionEntryController {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  // Utility to calculate Running Hours
  double calculateRunningHours(TimeOfDay start, TimeOfDay end, {TimeOfDay? downtimeStart, TimeOfDay? downtimeEnd}) {
    int startMinutes = start.hour * 60 + start.minute;
    int endMinutes = end.hour * 60 + end.minute;
    
    // Handle shift crossing midnight
    if (endMinutes < startMinutes) {
      endMinutes += 24 * 60;
    }
    
    double runningHours = (endMinutes - startMinutes) / 60.0;

    if (downtimeStart != null && downtimeEnd != null) {
      int downStartMins = downtimeStart.hour * 60 + downtimeStart.minute;
      int downEndMins = downtimeEnd.hour * 60 + downtimeEnd.minute;

      if (downEndMins < downStartMins) {
        downEndMins += 24 * 60;
      }
      double downtimeHours = (downEndMins - downStartMins) / 60.0;
      
      runningHours -= downtimeHours;
      if (runningHours < 0) runningHours = 0;
    }

    return runningHours;
  }

  // Utility to calculate Parts per Hour
  double calculatePartsPerHour(int actualQty, double runningHours) {
    if (runningHours <= 0) return 0;
    return actualQty / runningHours;
  }

  // Utility to calculate Weight in KGs
  double calculateWeightInKGs(int actualQty, double finishWeightGrams) {
    return (actualQty * finishWeightGrams) / 1000.0;
  }

  Future<void> submitEntry(ProductionEntryModel entry) async {
    state = const AsyncValue.loading();
    try {
      final client = ref.read(apiClientProvider);
      
      await client.post('/production/entry', data: entry.toJson());

      // If successful, reset state
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}
