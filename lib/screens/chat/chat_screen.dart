import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../models/message_model.dart';
import '../../services/chat/chat_service.dart';

class ChatScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String? userAvatar;
  final bool isOnline;

  const ChatScreen({
    super.key,
    required this.userId,
    required this.userName,
    this.userAvatar,
    this.isOnline = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<MessageModel> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;

  String? get _currentUserId =>
      Supabase.instance.client.auth.currentUser?.id;

  Color get _primaryColor => AppColors.malePrimary;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _listenToNewMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return;

    setState(() => _isLoading = true);

    try {
      final messages = await _chatService.getConversation(
        userId: currentUserId,
        otherUserId: widget.userId,
        limit: 100,
      );

      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load messages: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _listenToNewMessages() {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return;

    _chatService.getMessageStream(currentUserId).listen((data) {
      if (data.isEmpty) return;

      final senderId = data['sender_id'] as String?;
      final receiverId = data['receiver_id'] as String?;

      // Only process messages from/to this conversation
      if (senderId == widget.userId || receiverId == widget.userId) {
        try {
          final newMessage = MessageModel.fromJson(data);

          if (mounted) {
            setState(() {
              // Avoid duplicates
              final exists = _messages.any((m) => m.id == newMessage.id);
              if (!exists) {
                _messages.add(newMessage);
              }
            });
            _scrollToBottom();
          }
        } catch (e) {
          // Ignore parse errors for stream messages
        }
      }
    });
  }

  Future<void> _sendMessage() async {
    final currentUserId = _currentUserId;
    final content = _messageController.text.trim();

    if (currentUserId == null || content.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    try {
      await _chatService.sendMessage(
        senderId: currentUserId,
        receiverId: widget.userId,
        content: content,
        type: MessageType.text,
      );

      _messageController.clear();

      // Reload to get the new message
      await _loadMessages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatMessageTime(DateTime time) {
    return DateFormat('h:mm a').format(time);
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return DateFormat('MMMM d, yyyy').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Message list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isSent = message.senderId == _currentUserId;

                          // Show date header if this is the first message or date changed
                          final showDateHeader = index == 0 ||
                              !_isSameDay(
                                message.createdAt,
                                _messages[index - 1].createdAt,
                              );

                          return Column(
                            children: [
                              if (showDateHeader)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  child: _buildDateHeader(
                                    _formatDateHeader(message.createdAt),
                                  ),
                                ),
                              _buildMessageBubble(
                                message: message,
                                isSent: isSent,
                              ),
                            ],
                          );
                        },
                      ),
          ),
          // Message input
          _buildMessageInput(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _primaryColor,
      elevation: 2,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppColors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          // Profile picture
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.white.withOpacity(0.3),
            backgroundImage: widget.userAvatar != null
                ? CachedNetworkImageProvider(widget.userAvatar!)
                : null,
            child: widget.userAvatar == null
                ? const Icon(
                    Icons.person,
                    size: 20,
                    color: AppColors.white,
                  )
                : null,
          ),
          const SizedBox(width: 10),
          // Name and online status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.userName,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    color: widget.isOnline
                        ? AppColors.white.withOpacity(0.9)
                        : AppColors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.videocam, color: AppColors.white),
          onPressed: () {
            // Video call placeholder
          },
        ),
        IconButton(
          icon: const Icon(Icons.call, color: AppColors.white),
          onPressed: () {
            // Voice call placeholder
          },
        ),
      ],
    );
  }

  Widget _buildDateHeader(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.divider.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.darkGrey,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildMessageBubble({
    required MessageModel message,
    required bool isSent,
  }) {
    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSent ? _primaryColor : AppColors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isSent ? 16 : 4),
            bottomRight: Radius.circular(isSent ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowColor,
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Message content
            if (message.type == MessageType.image)
              _buildImagePlaceholder(message.content)
            else
              Text(
                message.content,
                style: TextStyle(
                  color: isSent ? AppColors.white : AppColors.darkGrey,
                  fontSize: 15,
                  height: 1.3,
                ),
              ),
            const SizedBox(height: 4),
            // Timestamp and read receipt
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatMessageTime(message.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: isSent
                        ? AppColors.white.withOpacity(0.7)
                        : AppColors.grey,
                  ),
                ),
                if (isSent) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.isRead ? Icons.done_all : Icons.done,
                    size: 14,
                    color: message.isRead
                        ? Colors.blue
                        : AppColors.white.withOpacity(0.7),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder(String imageUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 200,
        height: 200,
        color: AppColors.divider,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: AppColors.divider,
                  child: const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => const Center(
                  child: Icon(
                    Icons.broken_image,
                    size: 40,
                    color: AppColors.grey,
                  ),
                ),
              )
            else
              const Center(
                child: Icon(
                  Icons.image,
                  size: 40,
                  color: AppColors.grey,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Image attachment button (placeholder)
            IconButton(
              icon: const Icon(
                Icons.image,
                color: AppColors.grey,
                size: 24,
              ),
              onPressed: () {
                // Image picker placeholder
              },
            ),
            // Text input
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.lightGrey,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(
                      color: AppColors.grey,
                      fontSize: 15,
                    ),
                    border: InputBorder.none,
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Send button
            Container(
              decoration: BoxDecoration(
                color: _primaryColor,
                shape: BoxShape.circle,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isSending ? null : _sendMessage,
                  customBorder: const CircleBorder(),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.white,
                            ),
                          )
                        : const Icon(
                            Icons.send,
                            color: AppColors.white,
                            size: 20,
                          ),
                  ),
                ),
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
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.darkGrey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Say hello!',
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

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}
