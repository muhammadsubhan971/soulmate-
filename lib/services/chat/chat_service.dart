import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/message_model.dart';

class ChatService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Send message
  Future<MessageModel> sendMessage({
    required String senderId,
    required String receiverId,
    required String content,
    MessageType type = MessageType.text,
  }) async {
    try {
      final response = await _supabase
          .from('messages')
          .insert({
            'sender_id': senderId,
            'receiver_id': receiverId,
            'content': content,
            'type': type.toString().split('.').last,
          })
          .select()
          .single();

      return MessageModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to send message');
    }
  }

  // Get conversation between two users
  Future<List<MessageModel>> getConversation({
    required String userId,
    required String otherUserId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase
          .from('messages')
          .select()
          .or('and(sender_id.eq.$userId,receiver_id.eq.$otherUserId),and(sender_id.eq.$otherUserId,receiver_id.eq.$userId)')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final messages = (response as List)
          .map((json) => MessageModel.fromJson(json))
          .toList();

      // Mark messages as read
      await markMessagesAsRead(
        userId: userId,
        otherUserId: otherUserId,
      );

      return messages.reversed.toList();
    } catch (e) {
      throw Exception('Failed to fetch conversation');
    }
  }

  // Mark messages as read
  Future<void> markMessagesAsRead({
    required String userId,
    required String otherUserId,
  }) async {
    try {
      await _supabase
          .from('messages')
          .update({'is_read': true})
          .eq('sender_id', otherUserId)
          .eq('receiver_id', userId)
          .eq('is_read', false);
    } catch (e) {
      // Silently fail - not critical
    }
  }

  // Get unread message count
  Future<int> getUnreadCount({
    required String userId,
    required String otherUserId,
  }) async {
    try {
      final response = await _supabase
          .from('messages')
          .select('id')
          .eq('sender_id', otherUserId)
          .eq('receiver_id', userId)
          .eq('is_read', false)
          .count();

      return response.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // Get all conversations for user
  Future<List<Map<String, dynamic>>> getConversations(String userId) async {
    try {
      // Get all messages where user is sender or receiver
      final response = await _supabase
          .from('messages')
          .select('sender_id, receiver_id, content, created_at')
          .or('sender_id.eq.$userId,receiver_id.eq.$userId')
          .order('created_at', ascending: false);

      // Group by conversation partner
      final conversations = <String, Map<String, dynamic>>{};

      for (final message in response as List) {
        final otherUserId = message['sender_id'] == userId
            ? message['receiver_id']
            : message['sender_id'];

        if (!conversations.containsKey(otherUserId)) {
          conversations[otherUserId] = {
            'userId': otherUserId,
            'lastMessage': message['content'],
            'lastMessageTime': message['created_at'],
          };
        }
      }

      return conversations.values.toList();
    } catch (e) {
      throw Exception('Failed to fetch conversations');
    }
  }

  // Listen to new messages (real-time)
  Stream<Map<String, dynamic>> getMessageStream(String userId) {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('receiver_id', userId)
        .map((data) {
      if (data.isNotEmpty) {
        return data.last;
      }
      return {};
    });
  }

  // Delete message
  Future<void> deleteMessage(String messageId) async {
    try {
      await _supabase
          .from('messages')
          .delete()
          .eq('id', messageId);
    } catch (e) {
      throw Exception('Failed to delete message');
    }
  }
}
