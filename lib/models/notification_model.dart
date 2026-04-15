class NotificationModel {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String message;
  final String? relatedUserId;
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.relatedUserId,
    this.isRead = false,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      userId: json['user_id'],
      type: NotificationType.values.firstWhere(
        (e) => e.toString() == 'NotificationType.${json['type']}',
        orElse: () => NotificationType.newMatch,
      ),
      title: json['title'],
      message: json['message'],
      relatedUserId: json['related_user_id'],
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'type': type.toString().split('.').last,
      'title': title,
      'message': message,
      'related_user_id': relatedUserId,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

enum NotificationType {
  newMatch,
  likeReceived,
  profileView,
  subscriptionUpdate,
  mutualMatch,
  message,
  system,
}
