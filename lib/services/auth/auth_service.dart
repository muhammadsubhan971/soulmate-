import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user_model.dart';
import '../../core/constants/app_constants.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Get current session
  Session? get currentSession => _supabase.auth.currentSession;

  // Get current user ID
  String? get currentUserId => _supabase.auth.currentUser?.id;

  // Check if user is logged in
  bool get isLoggedIn => currentSession != null;

  // Sign up with email and password
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? phone,
    String? gender,
  }) async {
    try {
      // Prepare metadata
      final Map<String, dynamic> metadata = {};
      if (phone != null && phone.isNotEmpty) {
        metadata['phone'] = phone;
      }
      if (gender != null && gender.isNotEmpty) {
        metadata['gender'] = gender;
      }

      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        // Pass phone and gender in user metadata so trigger can save them
        data: metadata.isNotEmpty ? metadata : null,
        // Set emailRedirectTo to your app URL for production
        emailRedirectTo: 'http://localhost:3000/',
      );
      return response;
    } on AuthException catch (e) {
      // Handle specific rate limit error
      if (e.message.contains('rate limit') || e.message.contains('For security purposes')) {
        throw Exception('Too many registration attempts. Please wait a few minutes and try again.');
      }
      throw Exception(e.message);
    } catch (e) {
      throw Exception('An unexpected error occurred during sign up');
    }
  }

  // Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('An unexpected error occurred during sign in');
    }
  }

  // Sign in with OTP
  Future<void> signInWithOTP({
    required String email,
  }) async {
    try {
      await _supabase.auth.signInWithOtp(
        email: email,
      );
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Failed to send OTP');
    }
  }

  // Verify OTP
  Future<AuthResponse> verifyOTP({
    required String email,
    required String token,
  }) async {
    try {
      final response = await _supabase.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.email,
      );
      return response;
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Invalid OTP');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      throw Exception('Failed to sign out');
    }
  }

  // Reset password
  Future<void> resetPassword({
    required String email,
  }) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Failed to send password reset email');
    }
  }

  // Update password
  Future<void> updatePassword({
    required String newPassword,
  }) async {
    try {
      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Failed to update password');
    }
  }

  // Get current user profile
  Future<UserModel?> getCurrentUserProfile() async {
    try {
      final userId = currentUserId;
      if (userId == null) return null;

      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      return UserModel.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  // Get user profile by ID
  Future<UserModel?> getUserProfile(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      return UserModel.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  // Check if user is admin
  Future<bool> isAdmin() async {
    try {
      final profile = await getCurrentUserProfile();
      return profile?.role == UserRole.admin;
    } catch (e) {
      return false;
    }
  }

  // Update user role to admin (for initial setup)
  Future<void> makeUserAdmin(String userId) async {
    try {
      await _supabase
          .from('profiles')
          .update({'role': 'admin'})
          .eq('id', userId);
    } catch (e) {
      throw Exception('Failed to update user role');
    }
  }

  // Listen to auth state changes
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;
}
