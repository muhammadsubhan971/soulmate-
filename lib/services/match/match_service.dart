import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user_model.dart';
import '../../models/match_model.dart';

class MatchService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Like a profile
  Future<void> likeProfile(String userId, String likedUserId) async {
    try {
      // Check if match already exists
      final existingMatch = await _supabase
          .from('matches')
          .select()
          .eq('user_id', userId)
          .eq('matched_user_id', likedUserId)
          .maybeSingle();

      if (existingMatch != null) {
        // Update existing match
        await _supabase
            .from('matches')
            .update({'is_liked': true, 'updated_at': DateTime.now().toIso8601String()})
            .eq('id', existingMatch['id']);
      } else {
        // Create new match
        await _supabase
            .from('matches')
            .insert({
              'user_id': userId,
              'matched_user_id': likedUserId,
              'is_liked': true,
              'is_skipped': false,
            });
      }

      // Check for mutual match
      await checkMutualMatch(userId, likedUserId);
    } catch (e) {
      throw Exception('Failed to like profile');
    }
  }

  // Skip a profile
  Future<void> skipProfile(String userId, String skippedUserId) async {
    try {
      await _supabase
          .from('matches')
          .upsert({
            'user_id': userId,
            'matched_user_id': skippedUserId,
            'is_liked': false,
            'is_skipped': true,
          });
    } catch (e) {
      throw Exception('Failed to skip profile');
    }
  }

  // Check for mutual match
  Future<bool> checkMutualMatch(String userId, String otherUserId) async {
    try {
      // Check if other user has liked current user
      final mutualMatch = await _supabase
          .from('matches')
          .select()
          .eq('user_id', otherUserId)
          .eq('matched_user_id', userId)
          .eq('is_liked', true)
          .maybeSingle();

      if (mutualMatch != null) {
        // Update both matches as mutual
        await _supabase
            .from('matches')
            .update({'is_mutual_match': true, 'updated_at': DateTime.now().toIso8601String()})
            .eq('user_id', userId)
            .eq('matched_user_id', otherUserId);

        await _supabase
            .from('matches')
            .update({'is_mutual_match': true, 'updated_at': DateTime.now().toIso8601String()})
            .eq('id', mutualMatch['id']);

        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  // Get matches for user
  Future<List<MatchModel>> getUserMatches(String userId) async {
    try {
      final response = await _supabase
          .from('matches')
          .select()
          .eq('user_id', userId)
          .eq('is_mutual_match', true)
          .order('created_at', ascending: false);

      return (response as List).map((json) => MatchModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch matches');
    }
  }

  // Get liked profiles
  Future<List<UserModel>> getLikedProfiles(String userId) async {
    try {
      final response = await _supabase
          .from('matches')
          .select('matched_user_id, profiles!matched_user_id(*)')
          .eq('user_id', userId)
          .eq('is_liked', true);

      final profiles = (response as List)
          .map((json) => UserModel.fromJson(json['profiles']))
          .toList();

      return profiles;
    } catch (e) {
      throw Exception('Failed to fetch liked profiles');
    }
  }

  // Get mutual matches (for chat)
  Future<List<UserModel>> getMutualMatches(String userId) async {
    try {
      final response = await _supabase
          .from('matches')
          .select('matched_user_id, profiles!matched_user_id(*)')
          .eq('user_id', userId)
          .eq('is_mutual_match', true);

      final profiles = (response as List)
          .map((json) => UserModel.fromJson(json['profiles']))
          .toList();

      return profiles;
    } catch (e) {
      throw Exception('Failed to fetch mutual matches');
    }
  }

  // Calculate compatibility score (AI-based matchmaking)
  Future<MatchModel> calculateCompatibility({
    required UserModel currentUser,
    required UserModel targetUser,
  }) async {
    double score = 0;
    final reasons = <String>[];

    // Age compatibility (max 20 points)
    if (currentUser.age != null && targetUser.age != null) {
      final ageDiff = (currentUser.age! - targetUser.age!).abs();
      if (ageDiff <= 3) {
        score += 20;
        reasons.add('Similar age');
      } else if (ageDiff <= 5) {
        score += 15;
      } else if (ageDiff <= 10) {
        score += 10;
      }
    }

    // Location match (max 20 points)
    if (currentUser.city != null && targetUser.city != null) {
      if (currentUser.city!.toLowerCase() == targetUser.city!.toLowerCase()) {
        score += 20;
        reasons.add('Same city');
      } else if (currentUser.country != null && targetUser.country != null) {
        if (currentUser.country!.toLowerCase() == targetUser.country!.toLowerCase()) {
          score += 10;
          reasons.add('Same country');
        }
      }
    }

    // Education compatibility (max 15 points)
    if (currentUser.qualification != null && targetUser.qualification != null) {
      score += 15;
      reasons.add('Similar education level');
    }

    // Profession compatibility (max 10 points)
    if (currentUser.profession != null && targetUser.profession != null) {
      score += 10;
      reasons.add('Professional match');
    }

    // Income compatibility (max 10 points)
    if (currentUser.monthlyIncome != null && targetUser.monthlyIncome != null) {
      final incomeDiff = (currentUser.monthlyIncome! - targetUser.monthlyIncome!).abs();
      final avgIncome = (currentUser.monthlyIncome! + targetUser.monthlyIncome!) / 2;
      if (avgIncome > 0) {
        final incomeRatio = incomeDiff / avgIncome;
        if (incomeRatio <= 0.3) {
          score += 10;
          reasons.add('Similar income level');
        } else if (incomeRatio <= 0.5) {
          score += 5;
        }
      }
    }

    // Lifestyle compatibility (max 15 points)
    if (currentUser.smokingHabit == targetUser.smokingHabit) {
      score += 8;
      reasons.add('Matching smoking habits');
    }
    if (currentUser.drinkingHabit == targetUser.drinkingHabit) {
      score += 7;
      reasons.add('Matching drinking habits');
    }

    // Marital status compatibility (max 10 points)
    if (currentUser.maritalStatus == targetUser.maritalStatus) {
      score += 10;
      reasons.add('Same marital status');
    }

    return MatchModel(
      id: '',
      userId: currentUser.id,
      matchedUserId: targetUser.id,
      compatibilityScore: score,
      matchReasons: reasons,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  // Get AI-powered match suggestions
  Future<List<Map<String, dynamic>>> getAISuggestions({
    required UserModel currentUser,
    required List<UserModel> potentialMatches,
    int limit = 10,
  }) async {
    final suggestions = <Map<String, dynamic>>[];

    for (final targetUser in potentialMatches) {
      final compatibility = await calculateCompatibility(
        currentUser: currentUser,
        targetUser: targetUser,
      );

      if (compatibility.compatibilityScore >= 70) {
        suggestions.add({
          'user': targetUser,
          'compatibility': compatibility,
        });
      }
    }

    // Sort by compatibility score
    suggestions.sort((a, b) {
      final aScore = (a['compatibility'] as MatchModel).compatibilityScore;
      final bScore = (b['compatibility'] as MatchModel).compatibilityScore;
      return bScore.compareTo(aScore);
    });

    return suggestions.take(limit).toList();
  }
}
