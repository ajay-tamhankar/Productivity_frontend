import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/api_services/api_client.dart';
import '../../data/models/master_data_models.dart';

class MasterManagementRepository {
  final ApiClient _apiClient;

  MasterManagementRepository(this._apiClient);

  Future<List<MachineModel>> listMachines() async {
    try {
      final response = await _apiClient.get('/machines');
      final raw = _extractList(response.data);
      return raw
          .whereType<Map>()
          .map((e) => MachineModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      throw Exception(_mapDioError(e, fallback: 'Failed to load machines.'));
    } catch (_) {
      throw Exception('Failed to load machines.');
    }
  }

  Future<void> createMachine({
    required String machineNumber,
    required String name,
  }) async {
    try {
      await _apiClient.post(
        '/machines',
        data: {
          'machineNumber': machineNumber,
          'name': name,
        },
      );
    } on DioException catch (e) {
      throw Exception(_mapDioError(e, fallback: 'Failed to create machine.'));
    } catch (_) {
      throw Exception('Failed to create machine.');
    }
  }

  Future<void> updateMachine({
    required String id,
    String? name,
    String? status,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null && name.trim().isNotEmpty) payload['name'] = name.trim();
    if (status != null && status.trim().isNotEmpty) payload['status'] = status.trim();
    if (payload.isEmpty) {
      throw Exception('No machine changes to update.');
    }

    try {
      await _apiClient.patch('/machines/$id', data: payload);
    } on DioException catch (e) {
      throw Exception(_mapDioError(e, fallback: 'Failed to update machine.'));
    } catch (_) {
      throw Exception('Failed to update machine.');
    }
  }

  Future<void> deleteMachine(String id) async {
    try {
      await _apiClient.delete('/machines/$id');
    } on DioException catch (e) {
      throw Exception(_mapDioError(e, fallback: 'Failed to delete machine.'));
    } catch (_) {
      throw Exception('Failed to delete machine.');
    }
  }

  Future<List<ItemModel>> listItems() async {
    try {
      final response = await _apiClient.get('/items');
      final raw = _extractList(response.data);
      return raw
          .whereType<Map>()
          .map((e) => ItemModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      throw Exception(_mapDioError(e, fallback: 'Failed to load items.'));
    } catch (_) {
      throw Exception('Failed to load items.');
    }
  }

  Future<void> createItem({
    required String itemCode,
    required String description,
    required double finishWeight,
  }) async {
    try {
      await _apiClient.post(
        '/items',
        data: {
          'itemCode': itemCode,
          'description': description,
          'finishWeight': finishWeight,
        },
      );
    } on DioException catch (e) {
      throw Exception(_mapDioError(e, fallback: 'Failed to create item.'));
    } catch (_) {
      throw Exception('Failed to create item.');
    }
  }

  Future<void> updateItem({
    required String id,
    String? itemCode,
    String? description,
    double? finishWeight,
  }) async {
    final payload = <String, dynamic>{};
    if (itemCode != null && itemCode.trim().isNotEmpty) payload['itemCode'] = itemCode.trim();
    if (description != null && description.trim().isNotEmpty) {
      payload['description'] = description.trim();
    }
    if (finishWeight != null) payload['finishWeight'] = finishWeight;
    if (payload.isEmpty) {
      throw Exception('No item changes to update.');
    }

    try {
      await _apiClient.patch('/items/$id', data: payload);
    } on DioException catch (e) {
      throw Exception(_mapDioError(e, fallback: 'Failed to update item.'));
    } catch (_) {
      throw Exception('Failed to update item.');
    }
  }

  Future<void> deleteItem(String id) async {
    try {
      await _apiClient.delete('/items/$id');
    } on DioException catch (e) {
      throw Exception(_mapDioError(e, fallback: 'Failed to delete item.'));
    } catch (_) {
      throw Exception('Failed to delete item.');
    }
  }

  Future<List<CustomerModel>> listCustomers() async {
    try {
      final response = await _apiClient.get('/customers');
      final raw = _extractList(response.data);
      return raw
          .whereType<Map>()
          .map((e) => CustomerModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      throw Exception(_mapDioError(e, fallback: 'Failed to load customers.'));
    } catch (_) {
      throw Exception('Failed to load customers.');
    }
  }

  Future<void> createCustomer({
    required String customerName,
  }) async {
    try {
      await _apiClient.post(
        '/customers',
        data: {'customerName': customerName.trim()},
      );
    } on DioException catch (e) {
      throw Exception(_mapDioError(e, fallback: 'Failed to create customer.'));
    } catch (_) {
      throw Exception('Failed to create customer.');
    }
  }

  Future<void> updateCustomer({
    required String id,
    required String customerName,
  }) async {
    try {
      await _apiClient.patch(
        '/customers/$id',
        data: {'customerName': customerName.trim()},
      );
    } on DioException catch (e) {
      throw Exception(_mapDioError(e, fallback: 'Failed to update customer.'));
    } catch (_) {
      throw Exception('Failed to update customer.');
    }
  }

  Future<void> deleteCustomer(String id) async {
    try {
      await _apiClient.delete('/customers/$id');
    } on DioException catch (e) {
      throw Exception(_mapDioError(e, fallback: 'Failed to delete customer.'));
    } catch (_) {
      throw Exception('Failed to delete customer.');
    }
  }

  // ── RC Numbers ────────────────────────────────────────────────────────────

  Future<List<RcNumberModel>> listRcNumbers() async {
    try {
      final response = await _apiClient.get('/rc-numbers');
      final raw = _extractList(response.data);
      return raw
          .whereType<Map>()
          .map((e) => RcNumberModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      throw Exception(_mapDioError(e, fallback: 'Failed to load RC numbers.'));
    } catch (_) {
      throw Exception('Failed to load RC numbers.');
    }
  }

  Future<void> createRcNumber({
    required String rcNumber,
    required String description,
  }) async {
    try {
      await _apiClient.post(
        '/rc-numbers',
        data: {'rcNumber': rcNumber, 'description': description},
      );
    } on DioException catch (e) {
      throw Exception(_mapDioError(e, fallback: 'Failed to create RC number.'));
    } catch (_) {
      throw Exception('Failed to create RC number.');
    }
  }

  Future<void> updateRcNumber({
    required String id,
    String? rcNumber,
    String? description,
    String? status,
  }) async {
    final payload = <String, dynamic>{};
    if (rcNumber != null && rcNumber.trim().isNotEmpty) payload['rcNumber'] = rcNumber.trim();
    if (description != null && description.trim().isNotEmpty) payload['description'] = description.trim();
    if (status != null && status.trim().isNotEmpty) payload['status'] = status.trim();
    if (payload.isEmpty) throw Exception('No RC number changes to update.');
    try {
      await _apiClient.patch('/rc-numbers/$id', data: payload);
    } on DioException catch (e) {
      throw Exception(_mapDioError(e, fallback: 'Failed to update RC number.'));
    } catch (_) {
      throw Exception('Failed to update RC number.');
    }
  }

  Future<void> deleteRcNumber(String id) async {
    try {
      await _apiClient.delete('/rc-numbers/$id');
    } on DioException catch (e) {
      throw Exception(_mapDioError(e, fallback: 'Failed to delete RC number.'));
    } catch (_) {
      throw Exception('Failed to delete RC number.');
    }
  }

  List<dynamic> _extractList(dynamic responseData) {
    if (responseData is List) return responseData;
    if (responseData is Map) {
      final map = Map<String, dynamic>.from(responseData);
      if (map['data'] is List) return map['data'] as List<dynamic>;
      if (map['items'] is List) return map['items'] as List<dynamic>;
      if (map['results'] is List) return map['results'] as List<dynamic>;
      if (map['machines'] is List) return map['machines'] as List<dynamic>;
      if (map['customers'] is List) return map['customers'] as List<dynamic>;
    }
    return const [];
  }

  String _mapDioError(
    DioException error, {
    required String fallback,
  }) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return 'Request timed out. Please check your internet and try again.';
    }
    if (error.type == DioExceptionType.connectionError) {
      return 'Unable to connect to server. Please check your network.';
    }

    final statusCode = error.response?.statusCode;
    final data = error.response?.data;
    String? apiMessage;

    if (data is Map<String, dynamic>) {
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) {
        apiMessage = message.trim();
      }
    } else if (data is String && data.trim().isNotEmpty) {
      apiMessage = data.trim();
    }

    if (statusCode == 400) return apiMessage ?? 'Please check input values.';
    if (statusCode == 401) return apiMessage ?? 'Session expired. Please login again.';
    if (statusCode == 403) return apiMessage ?? 'You do not have permission for this action.';
    if (statusCode == 404) return apiMessage ?? 'Record not found.';
    if (statusCode == 409) return apiMessage ?? 'Record already exists.';
    if (statusCode != null && statusCode >= 500) {
      return 'Server is temporarily unavailable. Please try again shortly.';
    }

    return apiMessage ?? fallback;
  }
}

final masterManagementRepositoryProvider = Provider<MasterManagementRepository>((ref) {
  return MasterManagementRepository(ref.watch(apiClientProvider));
});
