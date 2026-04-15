class AppConstants {
  // Supabase Configuration
  static const String supabaseUrl = 'https://nquhiryqtbrtpauuxmsc.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5xdWhpcnlxdGJydHBhdXV4bXNjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYwODM3MTAsImV4cCI6MjA5MTY1OTcxMH0.3l3JbRQWiSRUdStdR500oIOskZ1InrSW5brAWW5XxQY';

  // App Info
  static const String appName = 'Soul Mate';
  static const String appVersion = '1.0.0';

  // Subscription Plans
  static const int freeProfileLimit = 5;
  static const int silverProfileLimit = 20;
  static const int goldProfileLimit = 50;
  static const double silverPrice = 2000; // PKR
  static const double goldPrice = 5000; // PKR

  // AI Matchmaking
  static const double defaultCompatibilityThreshold = 70.0;

  // Storage Keys
  static const String userTokenKey = 'user_token';
  static const String userIdKey = 'user_id';
  static const String userRoleKey = 'user_role';
  static const String userGenderKey = 'user_gender';

  // Image Upload
  static const String profileImagesBucket = 'profile-images';
  static const String verificationImagesBucket = 'verification-images';

  // Pagination
  static const int defaultPageSize = 20;
  static const int dailyMatchLimit = 5;

  // API Endpoints (if needed)
  static const String apiBaseUrl = 'https://api.example.com';

  // Payment
  static const String stripePublishableKey = 'YOUR_STRIPE_PUBLISHABLE_KEY';
}
