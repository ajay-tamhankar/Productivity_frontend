import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/models/master_data_models.dart';

import '../../data/api_services/api_client.dart';

part 'master_data_provider.g.dart';

class MasterDataState {
  final List<MachineModel> machines;
  final List<ItemModel> items;
  final List<CustomerModel> customers;
  final List<String> rejectionReasons;

  MasterDataState({
    this.machines = const [],
    this.items = const [],
    this.customers = const [],
    this.rejectionReasons = const [],
  });
}

const List<String> _fallbackRejectionReasons = <String>[
  'Forging Defects',
  'Rolling Defects',
  'Finishing defects',
  'All Process defect',
];

@Riverpod(keepAlive: true)
class MasterDataController extends _$MasterDataController {
  @override
  FutureOr<MasterDataState> build() async {
    final client = ref.read(apiClientProvider);

    try {
      final responses = await Future.wait([
        client.get('/master-data/machines'),
        client.get('/master-data/items'),
        client.get('/master-data/customers'),
      ]);

      final machines = (responses[0].data as List)
          .map((json) => MachineModel.fromJson(json))
          .toList();
      final items = (responses[1].data as List)
          .map((json) => ItemModel.fromJson(json))
          .toList();
      final customers = (responses[2].data as List)
          .map((json) => CustomerModel.fromJson(json))
          .toList();
      var rejectionReasons = List<String>.from(_fallbackRejectionReasons);
      try {
        final rejectionRes = await client.get('/master-data/rejection-reasons');
        final parsed = _parseRejectionReasons(rejectionRes.data);
        if (parsed.isNotEmpty) {
          rejectionReasons = parsed;
        }
      } catch (_) {
        // Keep fallback reasons when endpoint is unavailable.
      }

      return MasterDataState(
        machines: machines,
        items: items,
        customers: customers,
        rejectionReasons: rejectionReasons,
      );
    } catch (e) {
      throw Exception('Failed to load master data: $e');
    }
  }
}

List<String> _parseRejectionReasons(dynamic data) {
  final output = <String>[];

  void appendFromList(List<dynamic> list) {
    for (final raw in list) {
      if (raw is String) {
        final text = raw.trim();
        if (text.isNotEmpty && !output.contains(text)) output.add(text);
        continue;
      }

      if (raw is Map) {
        final map = Map<String, dynamic>.from(raw);
        final candidates = <String>[
          (map['reason'] ?? '').toString().trim(),
          (map['name'] ?? '').toString().trim(),
          (map['label'] ?? '').toString().trim(),
        ];
        for (final candidate in candidates) {
          if (candidate.isNotEmpty && !output.contains(candidate)) {
            output.add(candidate);
            break;
          }
        }
      }
    }
  }

  if (data is List) {
    appendFromList(data);
    return output;
  }

  if (data is Map) {
    final map = Map<String, dynamic>.from(data);
    if (map['data'] is List) appendFromList(map['data'] as List<dynamic>);
    if (map['reasons'] is List) appendFromList(map['reasons'] as List<dynamic>);
  }

  return output;
}
