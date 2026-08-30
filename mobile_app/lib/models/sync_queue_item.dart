import 'package:hive/hive.dart';

part 'sync_queue_item.g.dart';

@HiveType(typeId: 3)
class SyncQueueItem extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String operationType; // UPDATE_HABITATION, UPDATE_SHELTER

  @HiveField(2)
  late String status; // pending, in_progress, completed, failed

  @HiveField(3)
  late String payload;

  @HiveField(4)
  late DateTime createdAt;

  @HiveField(5)
  int retryCount;

  @HiveField(6)
  String? errorMessage;

  SyncQueueItem({
    required this.id,
    required this.operationType,
    required this.status,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
    this.errorMessage,
  });

  SyncQueueItem copyWith({
    String? id,
    String? operationType,
    String? status,
    String? payload,
    DateTime? createdAt,
    int? retryCount,
    String? errorMessage,
  }) {
    return SyncQueueItem(
      id: id ?? this.id,
      operationType: operationType ?? this.operationType,
      status: status ?? this.status,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'operation_type': operationType,
      'status': status,
      'payload': payload,
      'created_at': createdAt.toIso8601String(),
      'retry_count': retryCount,
      'error_message': errorMessage,
    };
  }
}
