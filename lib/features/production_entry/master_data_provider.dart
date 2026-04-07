import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/models/master_data_models.dart';

import '../../data/api_services/api_client.dart';

part 'master_data_provider.g.dart';

class MasterDataState {
  final List<MachineModel> machines;
  final List<ItemModel> items;
  final List<CustomerModel> customers;
  final List<RcNumberModel> rcNumbers;

  MasterDataState({
    this.machines = const [],
    this.items = const [],
    this.customers = const [],
    this.rcNumbers = const [],
  });
}

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
        client.get('/master-data/rc-numbers'),
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
      final rcNumbers = (responses[3].data as List)
          .map((json) => RcNumberModel.fromJson(json))
          .toList();

      return MasterDataState(
        machines: machines,
        items: items,
        customers: customers,
        rcNumbers: rcNumbers,
      );
    } catch (e) {
      throw Exception('Failed to load master data: $e');
    }
  }
}
