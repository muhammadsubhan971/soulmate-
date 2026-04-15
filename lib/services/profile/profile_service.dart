import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user_model.dart';
import '../../core/constants/app_constants.dart';

class ProfileService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Create or update profile with ALL fields
  Future<void> updateProfile(UserModel profile) async {
    try {
      final jsonData = profile.toJson();
      
      // DEBUG: Print what we're sending
      print('===== PROFILE UPDATE DEBUG =====');
      print('User ID: ${jsonData['id']}');
      print('Full Name: ${jsonData['full_name']}');
      print('Father Name: ${jsonData['father_name']}');
      print('Age: ${jsonData['age']}');
      print('City: ${jsonData['city']}');
      print('Profession: ${jsonData['profession']}');
      print('Total fields in JSON: ${jsonData.length}');
      print('All JSON data:');
      jsonData.forEach((key, value) {
        print('  $key: $value');
      });
      print('================================');
      
      // Remove fields that should NOT be updated
      jsonData.remove('email'); // Managed by auth
      jsonData.remove('created_at'); // Auto-set by database
      jsonData.remove('updated_at'); // Auto-set by trigger
      
      // CRITICAL: Ensure id is present for upsert
      if (!jsonData.containsKey('id') || jsonData['id'] == null) {
        throw Exception('Profile ID is required for update');
      }

      // Use upsert with onConflict to update existing profile
      final response = await _supabase
          .from('profiles')
          .upsert(jsonData, onConflict: 'id')
          .select();
      
      print('✅ Profile update successful! Response: $response');
    } catch (e, stackTrace) {
      print('❌ Profile update FAILED: $e');
      print('Stack trace: $stackTrace');
      throw Exception('Failed to update profile: $e');
    }
  }

  // Insert new profile (for initial creation)
  Future<void> createProfile(UserModel profile) async {
    try {
      final jsonData = profile.toJson();
      // Remove fields that are auto-managed
      jsonData.remove('email'); // Email is managed by auth
      jsonData.remove('created_at');
      jsonData.remove('updated_at');

      // Ensure id is included
      if (!jsonData.containsKey('id') || jsonData['id'] == null) {
        throw Exception('Profile ID is required for creation');
      }

      // Use upsert to handle both insert and update cases
      await _supabase
          .from('profiles')
          .upsert(jsonData, onConflict: 'id');
    } catch (e) {
      throw Exception('Failed to create profile: $e');
    }
  }

  // Update specific fields
  Future<void> updateProfileFields(Map<String, dynamic> fields) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      await _supabase.from('profiles').upsert({...fields, 'id': userId});
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  // Get user profile by ID
  Future<UserModel?> getUserProfile(String userId) async {
    try {
      final response = await _supabase.from('profiles').select().eq('id', userId).single();
      return UserModel.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  // Get all profiles for matching (opposite gender)
  Future<List<UserModel>> getMatchingProfiles({
    required Gender userGender,
    int limit = 20,
    int offset = 0,
    String? city,
    String? caste,
    int? minAge,
    int? maxAge,
  }) async {
    try {
      final targetGender = userGender == Gender.male ? 'female' : 'male';

      var query = _supabase
          .from('profiles')
          .select()
          .eq('gender', targetGender)
          .eq('is_active', true)
          .eq('is_blocked', false);

      if (minAge != null) query = query.gte('age', minAge);
      if (maxAge != null) query = query.lte('age', maxAge);

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      List<UserModel> profiles = (response as List).map((json) => UserModel.fromJson(json)).toList();

      // Filter by city/caste in Dart
      if (city != null || caste != null) {
        profiles = profiles.where((p) {
          bool cityMatch = city == null || (p.city?.toLowerCase().contains(city.toLowerCase()) ?? false);
          bool casteMatch = caste == null || (p.caste?.toLowerCase().contains(caste.toLowerCase()) ?? false);
          return cityMatch && casteMatch;
        }).toList();
      }

      return profiles;
    } catch (e) {
      throw Exception('Failed to fetch matching profiles: $e');
    }
  }

  // Search profiles with filters
  Future<List<UserModel>> searchProfiles({
    String? query,
    Gender? gender,
    int? minAge,
    int? maxAge,
    String? city,
    String? caste,
    String? profession,
    double? minIncome,
    double? maxIncome,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      var sqlQuery = _supabase
          .from('profiles')
          .select()
          .eq('is_active', true)
          .eq('is_blocked', false);

      if (gender != null) sqlQuery = sqlQuery.eq('gender', gender.toString().split('.').last);
      if (minAge != null) sqlQuery = sqlQuery.gte('age', minAge);
      if (maxAge != null) sqlQuery = sqlQuery.lte('age', maxAge);
      if (minIncome != null) sqlQuery = sqlQuery.gte('monthly_income', minIncome);
      if (maxIncome != null) sqlQuery = sqlQuery.lte('monthly_income', maxIncome);

      final response = await sqlQuery
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      List<UserModel> profiles = (response as List).map((json) => UserModel.fromJson(json)).toList();

      // Filter in Dart
      if (query != null || city != null || caste != null || profession != null) {
        profiles = profiles.where((p) {
          bool qMatch = query == null ||
              (p.fullName?.toLowerCase().contains(query.toLowerCase()) ?? false) ||
              (p.city?.toLowerCase().contains(query.toLowerCase()) ?? false);
          bool cityMatch = city == null || (p.city?.toLowerCase().contains(city.toLowerCase()) ?? false);
          bool casteMatch = caste == null || (p.caste?.toLowerCase().contains(caste.toLowerCase()) ?? false);
          bool professionMatch = profession == null || (p.profession?.toLowerCase().contains(profession.toLowerCase()) ?? false);
          return qMatch && cityMatch && casteMatch && professionMatch;
        }).toList();
      }

      return profiles;
    } catch (e) {
      throw Exception('Failed to search profiles: $e');
    }
  }

  // Upload profile picture from file bytes (works on all platforms - Web & Mobile)
  Future<String> uploadProfilePictureBytes(Uint8List imageBytes, String fileName, String userId) async {
    try {
      print('===== PROFILE PICTURE UPLOAD DEBUG =====');
      print('User ID: $userId');
      print('File Name: $fileName');
      print('Image Size: ${imageBytes.length} bytes');
      
      // Validate input
      if (imageBytes.isEmpty) {
        throw Exception('Image bytes cannot be empty');
      }
      if (imageBytes.length > 5 * 1024 * 1024) { // 5MB limit
        throw Exception('Image size must be less than 5MB');
      }

      final fileExtension = fileName.split('.').last.toLowerCase();
      final validExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
      if (!validExtensions.contains(fileExtension)) {
        throw Exception('Invalid image format. Supported formats: ${validExtensions.join(', ')}');
      }

      final storageFileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      final filePath = 'profile-pictures/$storageFileName';
      print('Storage Path: $filePath');

      // Upload to storage using binary data (works on web & mobile)
      print('Uploading to storage...');
      await _supabase.storage
          .from(AppConstants.profileImagesBucket)
          .uploadBinary(
            filePath,
            imageBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
      print('Storage upload successful!');

      // Get public URL
      final imageUrl = _supabase.storage
          .from(AppConstants.profileImagesBucket)
          .getPublicUrl(filePath);
      
      print('Image URL: $imageUrl');

      // CRITICAL: Update profile with new image URL
      print('Updating profile with image URL...');
      print('About to execute: profiles.update WHERE id = $userId');
      
      final updateResponse = await _supabase
          .from('profiles')
          .update({
            'profile_picture_url': imageUrl,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);
      
      print('Profile update response: $updateResponse');
      print('========================================');

      return imageUrl;
    } catch (e, stackTrace) {
      print('❌ Profile picture upload FAILED: $e');
      print('Stack trace: $stackTrace');
      print('Error type: ${e.runtimeType}');
      if (e.toString().contains('permission denied')) {
        print('⚠️ PERMISSION ERROR - Check RLS policies in Supabase!');
        print('⚠️ Run: database/NUCLEAR_FIX_PERMISSION_DENIED.sql');
      }
      throw Exception('Failed to upload profile picture: ${e.toString()}');
    }
  }

  // Increment daily profile views
  Future<void> incrementDailyProfileViews() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      final profile = await _supabase.from('profiles').select('daily_profile_views').eq('id', userId).single();
      final currentViews = profile['daily_profile_views'] ?? 0;

      await _supabase.from('profiles').update({'daily_profile_views': currentViews + 1}).eq('id', userId);
    } catch (e) {
      throw Exception('Failed to increment daily views');
    }
  }

  // Get profile statistics
  Future<Map<String, dynamic>> getProfileStats(String userId) async {
    try {
      final matchesCount = await _supabase.from('matches').select('id').eq('user_id', userId).count();
      final likesReceived = await _supabase.from('matches').select('id').eq('matched_user_id', userId).eq('is_liked', true).count();
      final profileViews = await _supabase.from('notifications').select('id').eq('user_id', userId).eq('type', 'profileView').count();

      return {
        'matches': matchesCount.count ?? 0,
        'likesReceived': likesReceived.count ?? 0,
        'profileViews': profileViews.count ?? 0,
      };
    } catch (e) {
      return {'matches': 0, 'likesReceived': 0, 'profileViews': 0};
    }
  }

  // Block user
  Future<void> blockUser(String userId) async {
    try {
      await _supabase.from('profiles').update({'is_blocked': true}).eq('id', userId);
    } catch (e) {
      throw Exception('Failed to block user');
    }
  }

  // Unblock user
  Future<void> unblockUser(String userId) async {
    try {
      await _supabase.from('profiles').update({'is_blocked': false}).eq('id', userId);
    } catch (e) {
      throw Exception('Failed to unblock user');
    }
  }

  // Delete profile
  Future<void> deleteProfile(String userId) async {
    try {
      await _supabase.from('profiles').delete().eq('id', userId);
    } catch (e) {
      throw Exception('Failed to delete profile');
    }
  }

  // Get all users (admin only)
  Future<List<UserModel>> getAllUsers({
    int limit = 50,
    int offset = 0,
    bool? isActive,
    bool? isBlocked,
    SubscriptionTier? subscriptionTier,
  }) async {
    try {
      var query = _supabase.from('profiles').select();

      if (isActive != null) query = query.eq('is_active', isActive);
      if (isBlocked != null) query = query.eq('is_blocked', isBlocked);
      if (subscriptionTier != null) query = query.eq('subscription_tier', subscriptionTier.toString().split('.').last);

      final response = await query.order('created_at', ascending: false).range(offset, offset + limit - 1);
      return (response as List).map((json) => UserModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch users: $e');
    }
  }
}
