import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/notification_model.dart';

class NotificationService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Create notification
  Future<void> createNotification({
    required String userId,
    required NotificationType type,
    required String title,
    required String message,
    String? relatedUserId,
  }) async {
    try {
      await _supabase
          .from('notifications')
          .insert({
            'user_id': userId,
            'type': type.toString().split('.').last,
            'title': title,
            'message': message,
            'related_user_id': relatedUserId,
          });
    } catch (e) {
      // Silently fail - notifications are not critical
    }
  }

  // Get user notifications
  Future<List<NotificationModel>> getUserNotifications({
    required String userId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List)
          .map((json) => NotificationModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch notifications');
    }
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      // Silently fail
    }
  }

  // Mark all notifications as read
  Future<void> markAllAsRead(String userId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (e) {
      // Silently fail
    }
  }

  // Get unread count
  Future<int> getUnreadCount(String userId) async {
    try {
      final response = await _supabase
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false)
          .count();

      return response.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // Notify about new match
  Future<void> notifyNewMatch({
    required String userId,
    required String matchedUserId,
    required String matchedUserName,
  }) async {
    await createNotification(
      userId: userId,
      type: NotificationType.newMatch,
      title: 'New Match!',
      message: 'You have a new match with $matchedUserName',
      relatedUserId: matchedUserId,
    );
  }

  // Notify about like received
  Future<void> notifyLikeReceived({
    required String userId,
    required String likerUserId,
    required String likerUserName,
  }) async {
    await createNotification(
      userId: userId,
      type: NotificationType.likeReceived,
      title: 'Someone liked you!',
      message: '$likerUserName liked your profile',
      relatedUserId: likerUserId,
    );
  }

  // Notify about profile view
  Future<void> notifyProfileView({
    required String userId,
    required String viewerUserId,
    required String viewerUserName,
  }) async {
    await createNotification(
      userId: userId,
      type: NotificationType.profileView,
      title: 'Profile Viewed',
      message: '$viewerUserName viewed your profile',
      relatedUserId: viewerUserId,
    );
  }

  // Notify about mutual match
  Future<void> notifyMutualMatch({
    required String userId,
    required String matchedUserId,
    required String matchedUserName,
  }) async {
    await createNotification(
      userId: userId,
      type: NotificationType.mutualMatch,
      title: 'It\'s a Match! 💕',
      message: 'You and $matchedUserName liked each other!',
      relatedUserId: matchedUserId,
    );
  }

  // Notify about new message
  Future<void> notifyNewMessage({
    required String userId,
    required String senderUserId,
    required String senderUserName,
    required String messagePreview,
  }) async {
    await createNotification(
      userId: userId,
      type: NotificationType.message,
      title: 'New Message',
      message: '$senderUserName: $messagePreview',
      relatedUserId: senderUserId,
    );
  }

  // Notify about subscription update
  Future<void> notifySubscriptionUpdate({
    required String userId,
    required String tier,
  }) async {
    await createNotification(
      userId: userId,
      type: NotificationType.subscriptionUpdate,
      title: 'Subscription Updated',
      message: 'Your subscription has been updated to $tier tier',
    );
  }

  // Listen to new notifications (real-time)
  Stream<Map<String, dynamic>> getNotificationStream(String userId) {
    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((data) {
      if (data.isNotEmpty) {
        return data.last;
      }
      return {};
    });
  }
}
