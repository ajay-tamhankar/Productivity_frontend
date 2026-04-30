class RejectionDetailModel {
  final String reason;
  final int quantity;

  RejectionDetailModel({required this.reason, required this.quantity});

  Map<String, dynamic> toJson() => {'reason': reason, 'quantity': quantity};
}

class ProductionEntryModel {
  final String? id;
  final String entryDate;
  final String shift;
  final String operatorId;
  final String? operatorName;
  final String machineId;
  final String itemId;
  final String? itemCode;
  final String? machineName;
  final String? itemDescription;
  final String? customerId;
  final String? customerName;
  final int ccd1Quantity;
  final int actualQuantity;
  final int rejectionQuantity;
  final String startTime;
  final String endTime;
  final String? notes;
  final String? machineDowntimeStartTime;
  final String? machineDowntimeEndTime;
  final String? rcNumber;
  final String? location;
  final List<RejectionDetailModel> rejectionDetails;

  // Calculated fields (computed by backend, thus optional on creation)
  final double runningHours;
  final double partsPerHour;
  final double weightInKGs;
  final double finishWeight;
  final String? approvalStatus;

  ProductionEntryModel({
    this.id,
    required this.entryDate,
    required this.shift,
    required this.operatorId,
    this.operatorName,
    required this.machineId,
    required this.itemId,
    this.itemCode,
    this.machineName,
    this.itemDescription,
    this.customerId,
    this.customerName,
    required this.ccd1Quantity,
    required this.actualQuantity,
    required this.rejectionQuantity,
    required this.startTime,
    required this.endTime,
    this.notes,
    this.machineDowntimeStartTime,
    this.machineDowntimeEndTime,
    this.rcNumber,
    this.location,
    this.rejectionDetails = const [],
    this.runningHours = 0.0,
    this.partsPerHour = 0.0,
    this.weightInKGs = 0.0,
    this.finishWeight = 0.0,
    this.approvalStatus,
  });

  factory ProductionEntryModel.fromJson(Map<String, dynamic> json) {
    String readString(dynamic value) => (value ?? '').toString();

    String readNestedString(Map<dynamic, dynamic>? map, List<String> keys) {
      if (map == null) return '';
      for (final key in keys) {
        final value = map[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString();
        }
      }
      return '';
    }

    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is double) return value.round();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    double parseDouble(dynamic value) {
      if (value is int) return value.toDouble();
      if (value is double) return value;
      return double.tryParse(value?.toString() ?? '') ?? 0.0;
    }

    final machineObj = json['machine'] is Map ? json['machine'] as Map : null;
    final itemObj = json['item'] is Map ? json['item'] as Map : null;
    final operatorObj = json['operator'] is Map
        ? json['operator'] as Map
        : null;
    final customerObj = json['customer'] is Map
        ? json['customer'] as Map
        : null;
    final machineRaw = json['machine'];
    final itemRaw = json['item'];

    final operatorName = readString(json['operatorName']).trim().isNotEmpty
        ? readString(json['operatorName'])
        : readNestedString(operatorObj, ['name', 'username', 'operatorName']);

    final customerName = readString(json['customerName']).trim().isNotEmpty
        ? readString(json['customerName'])
        : readNestedString(customerObj, ['name', 'customerName']);

    final machineName = readString(json['machineName']).trim().isNotEmpty
        ? readString(json['machineName'])
        : readString(json['machineDisplayName']).trim().isNotEmpty
        ? readString(json['machineDisplayName'])
        : (machineRaw is String && machineRaw.trim().isNotEmpty
              ? machineRaw
              : readNestedString(machineObj, [
                  'name',
                  'machineName',
                  'displayName',
                ]));

    final itemDescription =
        readString(json['itemDescription']).trim().isNotEmpty
        ? readString(json['itemDescription'])
        : readString(json['itemName']).trim().isNotEmpty
        ? readString(json['itemName'])
        : (itemRaw is String && itemRaw.trim().isNotEmpty
              ? itemRaw
              : readNestedString(itemObj, [
                  'description',
                  'name',
                  'itemDescription',
                ]));

    final machineId = readString(json['machineId']).trim().isNotEmpty
        ? readString(json['machineId'])
        : readNestedString(machineObj, ['id', 'machineId']);

    final itemId = readString(json['itemId']).trim().isNotEmpty
        ? readString(json['itemId'])
        : readNestedString(itemObj, ['id', 'itemId']);

    final itemCode = readString(json['itemCode']).trim().isNotEmpty
        ? readString(json['itemCode'])
        : readNestedString(itemObj, ['code', 'itemCode', 'partNo']);

    return ProductionEntryModel(
      id: json['id'],
      entryDate: (json['entryDate'] ?? json['date'] ?? '').toString(),
      shift: json['shift'] ?? '',
      operatorId: json['operatorId'] ?? '',
      operatorName: operatorName.isNotEmpty ? operatorName : null,
      machineId: machineId.isNotEmpty ? machineId : machineName,
      itemId: itemId.isNotEmpty ? itemId : itemDescription,
      itemCode: itemCode.isNotEmpty ? itemCode : null,
      machineName: machineName.isNotEmpty ? machineName : null,
      itemDescription: itemDescription.isNotEmpty ? itemDescription : null,
      customerId: json['customerId'],
      customerName: customerName.isNotEmpty ? customerName : null,
      ccd1Quantity: parseInt(json['ccd1Quantity']),
      actualQuantity: parseInt(json['actualQuantity']),
      rejectionQuantity: parseInt(json['rejectionQuantity']),
      startTime: json['startTime'] ?? '',
      endTime: json['endTime'] ?? '',
      notes: json['notes'],
      machineDowntimeStartTime: json['machineDowntimeStartTime'],
      machineDowntimeEndTime: json['machineDowntimeEndTime'],
      rcNumber: json['rcNumber']?.toString(),
      location: json['location']?.toString(),
      runningHours: parseDouble(json['runningHours']),
      partsPerHour: parseDouble(json['partsPerHour']),
      weightInKGs: parseDouble(json['weightInKGs'] ?? json['weightInKgs']),
      finishWeight: parseDouble(json['finishWeight'] ?? json['finishWt']),
      approvalStatus: json['approvalStatus'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'entryDate': entryDate,
      'shift': shift,
      'operatorId': operatorId,
      'machineId': machineId,
      'itemId': itemId,
      'ccd1Quantity': ccd1Quantity,
      'actualQuantity': actualQuantity,
      'rejectionQuantity': rejectionQuantity,
      'startTime': startTime,
      'endTime': endTime,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
      if (machineDowntimeStartTime != null &&
          machineDowntimeStartTime!.isNotEmpty)
        'machineDowntimeStartTime': machineDowntimeStartTime,
      if (machineDowntimeEndTime != null && machineDowntimeEndTime!.isNotEmpty)
        'machineDowntimeEndTime': machineDowntimeEndTime,
      if (rcNumber != null && rcNumber!.isNotEmpty) 'rcNumber': rcNumber,
      if (location != null && location!.isNotEmpty) 'location': location,
      if (rejectionDetails.isNotEmpty)
        'rejectionDetails': rejectionDetails.map((e) => e.toJson()).toList(),
    };
  }

  ProductionEntryModel copyWith({
    String? id,
    String? entryDate,
    String? shift,
    String? operatorId,
    String? operatorName,
    String? machineId,
    String? itemId,
    String? itemCode,
    String? machineName,
    String? itemDescription,
    String? customerId,
    String? customerName,
    int? ccd1Quantity,
    int? actualQuantity,
    int? rejectionQuantity,
    String? startTime,
    String? endTime,
    String? notes,
    String? machineDowntimeStartTime,
    String? machineDowntimeEndTime,
    String? rcNumber,
    String? location,
    List<RejectionDetailModel>? rejectionDetails,
    double? runningHours,
    double? partsPerHour,
    double? weightInKGs,
    double? finishWeight,
    String? approvalStatus,
  }) {
    return ProductionEntryModel(
      id: id ?? this.id,
      entryDate: entryDate ?? this.entryDate,
      shift: shift ?? this.shift,
      operatorId: operatorId ?? this.operatorId,
      operatorName: operatorName ?? this.operatorName,
      machineId: machineId ?? this.machineId,
      itemId: itemId ?? this.itemId,
      itemCode: itemCode ?? this.itemCode,
      machineName: machineName ?? this.machineName,
      itemDescription: itemDescription ?? this.itemDescription,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      ccd1Quantity: ccd1Quantity ?? this.ccd1Quantity,
      actualQuantity: actualQuantity ?? this.actualQuantity,
      rejectionQuantity: rejectionQuantity ?? this.rejectionQuantity,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      notes: notes ?? this.notes,
      machineDowntimeStartTime:
          machineDowntimeStartTime ?? this.machineDowntimeStartTime,
      machineDowntimeEndTime:
          machineDowntimeEndTime ?? this.machineDowntimeEndTime,
      rcNumber: rcNumber ?? this.rcNumber,
      location: location ?? this.location,
      rejectionDetails: rejectionDetails ?? this.rejectionDetails,
      runningHours: runningHours ?? this.runningHours,
      partsPerHour: partsPerHour ?? this.partsPerHour,
      weightInKGs: weightInKGs ?? this.weightInKGs,
      finishWeight: finishWeight ?? this.finishWeight,
      approvalStatus: approvalStatus ?? this.approvalStatus,
    );
  }
}
