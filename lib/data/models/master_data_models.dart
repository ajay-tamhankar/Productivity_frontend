class MachineModel {
  final String id;
  final String machineNumber;
  final String name;
  final String status;

  MachineModel({
    required this.id, 
    required this.machineNumber,
    required this.name, 
    required this.status,
  });

  factory MachineModel.fromJson(Map<String, dynamic> json) {
    return MachineModel(
      id: json['id'] ?? json['_id'] ?? '',
      machineNumber: json['machineNumber'] ?? '',
      name: json['name'] ?? '',
      status: json['status'] ?? '',
    );
  }
}

class ItemModel {
  final String id;
  final String itemCode;
  final String description;
  final double finishWeightG;

  ItemModel({
    required this.id,
    required this.itemCode,
    required this.description,
    required this.finishWeightG,
  });

  factory ItemModel.fromJson(Map<String, dynamic> json) {
    return ItemModel(
      id: json['id'] ?? json['_id'] ?? '',
      itemCode: json['itemCode'] ?? '',
      description: json['description'] ?? '',
      finishWeightG: double.tryParse(json['finishWeight']?.toString() ?? '0') ?? 0.0,
    );
  }
}

class CustomerModel {
  final String id;
  final String name;

  CustomerModel({required this.id, required this.name});

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['customerName'] ?? json['name'] ?? '',
    );
  }
}

class RcNumberModel {
  final String id;
  final String rcNumber;
  final String description;
  final String status;

  RcNumberModel({
    required this.id,
    required this.rcNumber,
    required this.description,
    required this.status,
  });

  factory RcNumberModel.fromJson(Map<String, dynamic> json) {
    return RcNumberModel(
      id: json['id'] ?? json['_id'] ?? '',
      rcNumber: json['rcNumber'] ?? json['number'] ?? '',
      description: json['description'] ?? '',
      status: json['status'] ?? '',
    );
  }
}
