import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/chat/chat_service.dart';
import '../../services/profile/profile_service.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatService _chatService = ChatService();
  final ProfileService _profileService = ProfileService();

  List<Map<String, dynamic>> _conversations = [];
  Map<String, UserModel> _userCache = {};
  Map<String, int> _unreadCounts = {};
  Map<String, bool> _onlineStatus = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;

    setState(() => _isLoading = true);

    try {
      final conversations = await _chatService.getConversations(currentUserId);

      // Fetch user details for each conversation partner
      final userCache = <String, UserModel>{};
      final unreadCounts = <String, int>{};
      final onlineStatus = <String, bool>{};

      for (final conv in conversations) {
        final partnerId = conv['userId'] as String;

        // Fetch partner profile
        if (!userCache.containsKey(partnerId)) {
          try {
            final user = await _profileService.getUserProfile(partnerId);
            if (user != null) {
              userCache[partnerId] = user;
              onlineStatus[partnerId] = user.isActive;
            } else {
              userCache[partnerId] = UserModel(
                id: partnerId,
                email: '',
                fullName: 'Unknown User',
                gender: Gender.male,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );
              onlineStatus[partnerId] = false;
            }
          } catch (e) {
            // Silently fail
          }
        }

        // Get unread count
        final unread = await _chatService.getUnreadCount(
          userId: currentUserId,
          otherUserId: partnerId,
        );
        unreadCounts[partnerId] = unread;
      }

      // Sort conversations by last message time (newest first)
      conversations.sort((a, b) {
        final timeA = DateTime.parse(a['lastMessageTime'] as String);
        final timeB = DateTime.parse(b['lastMessageTime'] as String);
        return timeB.compareTo(timeA);
      });

      if (mounted) {
        setState(() {
          _conversations = conversations;
          _userCache = userCache;
          _unreadCounts = unreadCounts;
          _onlineStatus = onlineStatus;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load conversations: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _refresh() async {
    await _loadConversations();
  }

  String _formatTime(String isoTime) {
    final dateTime = DateTime.parse(isoTime);
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  Color _getPrimaryColor() {
    // Default to male primary color
    return AppColors.malePrimary;
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = _getPrimaryColor();

    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        title: const Text(
          'Messages',
          style: TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _refresh,
              color: primaryColor,
              child: _conversations.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      itemCount: _conversations.length,
                      separatorBuilder: (context, index) => const Divider(
                        height: 1,
                        thickness: 1,
                        color: AppColors.divider,
                      ),
                      itemBuilder: (context, index) {
                        final conversation = _conversations[index];
                        final partnerId = conversation['userId'] as String;
                        final partner = _userCache[partnerId];
                        final lastMessage =
                            conversation['lastMessage'] as String? ?? '';
                        final lastMessageTime =
                            conversation['lastMessageTime'] as String;
                        final unreadCount = _unreadCounts[partnerId] ?? 0;
                        final isOnline = _onlineStatus[partnerId] ?? false;

                        if (partner == null) {
                          return const SizedBox.shrink();
                        }

                        return _buildConversationTile(
                          partner: partner,
                          lastMessage: lastMessage,
                          lastMessageTime: lastMessageTime,
                          unreadCount: unreadCount,
                          isOnline: isOnline,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  userId: partnerId,
                                  userName: partner.fullName ?? 'Unknown',
                                  userAvatar: partner.profilePictureUrl,
                                  isOnline: isOnline,
                                ),
                              ),
                            ).then((_) => _loadConversations());
                          },
                        );
                      },
                    ),
            ),
    );
  }

  Widget _buildConversationTile({
    required UserModel partner,
    required String lastMessage,
    required String lastMessageTime,
    required int unreadCount,
    required bool isOnline,
    required VoidCallback onTap,
  }) {
    final primaryColor = _getPrimaryColor();

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Profile picture with online indicator
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.divider,
                  backgroundImage: partner.profilePictureUrl != null
                      ? CachedNetworkImageProvider(partner.profilePictureUrl!)
                      : null,
                  child: partner.profilePictureUrl == null
                      ? Icon(
                          Icons.person,
                          size: 32,
                          color: AppColors.grey,
                        )
                      : null,
                ),
                // Online/offline indicator
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: isOnline ? AppColors.success : AppColors.grey,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.white,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            // Conversation details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          partner.fullName ?? 'Unknown User',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: unreadCount > 0
                                ? FontWeight.bold
                                : FontWeight.w600,
                            color: AppColors.darkGrey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatTime(lastMessageTime),
                        style: TextStyle(
                          fontSize: 12,
                          color: unreadCount > 0
                              ? primaryColor
                              : AppColors.grey,
                          fontWeight: unreadCount > 0
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMessage,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.grey,
                            fontWeight: unreadCount > 0
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unreadCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              unreadCount > 99 ? '99+' : '$unreadCount',
                              style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
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
              Icons.chat_bubble_outline,
              size: 80,
              color: AppColors.grey.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'No messages yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.darkGrey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start a conversation by matching with someone',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
