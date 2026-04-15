import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../models/notification_model.dart';
import '../../models/user_model.dart';
import '../../services/notification/notification_service.dart';
import '../../services/profile/profile_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationService _notificationService = NotificationService();
  final ProfileService _profileService = ProfileService();

  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  UserModel? _currentUser;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        setState(() => _isLoading = false);
        return;
      }

      await Future.wait([
        _loadCurrentUser(),
        _loadNotifications(userId),
        _loadUnreadCount(userId),
      ]);
    } catch (e) {
      // Handle error silently
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadCurrentUser() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      _currentUser = await _profileService.getUserProfile(userId);
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _loadNotifications(String userId) async {
    try {
      final notifications = await _notificationService.getUserNotifications(
        userId: userId,
        limit: 50,
      );
      setState(() {
        _notifications = notifications;
      });
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _loadUnreadCount(String userId) async {
    try {
      final count = await _notificationService.getUnreadCount(userId);
      setState(() => _unreadCount = count);
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _refresh() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        await Future.wait([
          _loadNotifications(userId),
          _loadUnreadCount(userId),
        ]);
      }
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await _notificationService.markAsRead(notificationId);
      setState(() {
        final index = _notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1) {
          _notifications[index] = NotificationModel(
            id: _notifications[index].id,
            userId: _notifications[index].userId,
            type: _notifications[index].type,
            title: _notifications[index].title,
            message: _notifications[index].message,
            relatedUserId: _notifications[index].relatedUserId,
            isRead: true,
            createdAt: _notifications[index].createdAt,
          );
        }
        if (_unreadCount > 0) _unreadCount--;
      });
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      await _notificationService.markAllAsRead(userId);
      setState(() {
        _notifications = _notifications
            .map((n) => NotificationModel(
                  id: n.id,
                  userId: n.userId,
                  type: n.type,
                  title: n.title,
                  message: n.message,
                  relatedUserId: n.relatedUserId,
                  isRead: true,
                  createdAt: n.createdAt,
                ))
            .toList();
        _unreadCount = 0;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications marked as read'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
        );
      }
    } catch (e) {
      // Silently fail
    }
  }

  Color _getPrimaryColor() {
    return _currentUser?.gender == Gender.female
        ? AppColors.femalePrimary
        : AppColors.malePrimary;
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.newMatch:
        return Icons.favorite;
      case NotificationType.likeReceived:
        return Icons.thumb_up;
      case NotificationType.profileView:
        return Icons.visibility;
      case NotificationType.subscriptionUpdate:
        return Icons.workspace_premium;
      case NotificationType.mutualMatch:
        return Icons.favorite;
      case NotificationType.message:
        return Icons.chat_bubble;
      case NotificationType.system:
        return Icons.info;
    }
  }

  Color _getIconColor(NotificationType type) {
    switch (type) {
      case NotificationType.newMatch:
        return AppColors.femalePrimary;
      case NotificationType.likeReceived:
        return AppColors.femaleAccent;
      case NotificationType.profileView:
        return AppColors.info;
      case NotificationType.subscriptionUpdate:
        return AppColors.gold;
      case NotificationType.mutualMatch:
        return AppColors.success;
      case NotificationType.message:
        return _getPrimaryColor();
      case NotificationType.system:
        return AppColors.grey;
    }
  }

  Color _getIconBackground(NotificationType type) {
    switch (type) {
      case NotificationType.newMatch:
        return AppColors.femalePrimary.withOpacity(0.1);
      case NotificationType.likeReceived:
        return AppColors.femaleAccent.withOpacity(0.1);
      case NotificationType.profileView:
        return AppColors.info.withOpacity(0.1);
      case NotificationType.subscriptionUpdate:
        return AppColors.gold.withOpacity(0.15);
      case NotificationType.mutualMatch:
        return AppColors.success.withOpacity(0.1);
      case NotificationType.message:
        return _getPrimaryColor().withOpacity(0.1);
      case NotificationType.system:
        return AppColors.grey.withOpacity(0.1);
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, yyyy').format(dateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = _getPrimaryColor();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.darkGrey),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Notifications',
              style: TextStyle(
                color: AppColors.darkGrey,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            if (_unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _unreadCount > 99 ? '99+' : '$_unreadCount',
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: Text(
                'Mark all read',
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              color: primaryColor,
              child: _notifications.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: _notifications.length,
                      separatorBuilder: (context, index) => const Divider(
                        height: 1,
                        indent: 72,
                        endIndent: 16,
                      ),
                      itemBuilder: (context, index) {
                        final notification = _notifications[index];
                        return _buildNotificationTile(notification);
                      },
                    ),
            ),
    );
  }

  Widget _buildNotificationTile(NotificationModel notification) {
    final iconColor = _getIconColor(notification.type);
    final iconBackground = _getIconBackground(notification.type);

    return Material(
      color: notification.isRead ? AppColors.white : AppColors.lightGrey,
      child: InkWell(
        onTap: () => _markAsRead(notification.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getNotificationIcon(notification.type),
                  color: iconColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: notification.isRead
                                  ? FontWeight.w500
                                  : FontWeight.bold,
                              color: AppColors.darkGrey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _getPrimaryColor(),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: TextStyle(
                        fontSize: 13,
                        color: notification.isRead
                            ? AppColors.grey
                            : AppColors.darkGrey,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatTime(notification.createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none,
              size: 80,
              color: AppColors.grey.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            const Text(
              'No notifications yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.darkGrey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'When you get matches, likes, or messages,\nyou\'ll see them here',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.grey,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
