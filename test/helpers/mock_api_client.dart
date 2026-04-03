import 'package:dio/dio.dart';
import 'package:productivity_tracker/data/api_services/api_client.dart';

class MockApiClient extends ApiClient {
  MockApiClient() : super(Dio());

  @override
  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    final options = RequestOptions(path: path);

    if (path.contains('/master-data/machines')) {
      return Response(requestOptions: options, data: [
        {"id": "M1", "machineNumber": "m-01", "name": "Machine 1"}
      ]);
    }
    if (path.contains('/master-data/items')) {
      return Response(requestOptions: options, data: [
        {"id": "I1", "itemCode": "ITEM-100", "description": "Desc", "finishWeight": "1.0"}
      ]);
    }
    if (path.contains('/master-data/customers')) {
      return Response(requestOptions: options, data: [
        {"id": "C1", "customerName": "Cust 1"}
      ]);
    }
    if (path.contains('/production/operator-feed')) {
      return Response(requestOptions: options, data: {
        "page": 1,
        "totalPages": 1,
        "totalRecords": 1,
        "data": [
          {
            "id": "1", 
            "entryDate": "2024-03-15", 
            "shift": "A", 
            "operatorId": "o1", 
            "machineId": "M1", 
            "itemId": "ITEM-100", 
            "customerId": "C1", 
            "startTime": "10:00", 
            "endTime": "12:00", 
            "actualQuantity": 1500, 
            "rejectionQuantity": 0
          }
        ]
      });
    }
    if (path.contains('/reports/detailed')) {
      return Response(requestOptions: options, data: {
        "page": 1,
        "totalPages": 1,
        "totalRecords": 1,
        "data": [
          {
            "id": "1", 
            "entryDate": "2024-03-15", 
            "shift": "A", 
            "operatorId": "o1", 
            "machineId": "M1", 
            "itemId": "ITEM-100", 
            "customerId": "C1", 
            "startTime": "10:00", 
            "endTime": "12:00", 
            "actualQuantity": 1500, 
            "rejectionQuantity": 0
          }
        ]
      });
    }
    return Response(requestOptions: options, data: {});
  }

  @override
  Future<Response> post(String path, {dynamic data}) async {
    final options = RequestOptions(path: path);

    if (path.contains('/auth/login')) {
      return Response(requestOptions: options, data: {
        "token": "fake-token",
        "user": {"id": "1", "username": "admin", "name": "Admin", "role": "ADMIN"}
      });
    }
    if (path.contains('/production/entry')) {
      return Response(requestOptions: options, statusCode: 201, data: {"id": "123"});
    }
    return Response(requestOptions: options, data: {});
  }
}
