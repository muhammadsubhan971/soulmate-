import 'package:flutter/material.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/auth/forgot_password_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/profile/edit_profile_screen.dart';
import '../../screens/profile/create_profile_screen.dart';
import '../../screens/match/match_screen.dart';
import '../../screens/chat/chat_list_screen.dart';
import '../../screens/chat/chat_screen.dart';
import '../../screens/subscription/subscription_screen.dart';
import '../../screens/notifications/notification_screen.dart';
import '../../screens/admin/admin_dashboard_screen.dart';
import '../../screens/admin/user_management_screen.dart';
import '../widgets/splash_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String createProfile = '/create-profile';
  static const String home = '/home';
  static const String profile = '/profile';
  static const String editProfile = '/edit-profile';
  static const String match = '/match';
  static const String chatList = '/chats';
  static const String chat = '/chat';
  static const String subscription = '/subscription';
  static const String notifications = '/notifications';
  static const String adminDashboard = '/admin/dashboard';
  static const String adminUsers = '/admin/users';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());
      case forgotPassword:
        return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());
      case createProfile:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => CreateProfileScreen(
            initialGender: args?['gender'] as String?,
          ),
        );
      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case profile:
        return MaterialPageRoute(
          builder: (_) => ProfileScreen(userId: settings.arguments as String),
        );
      case editProfile:
        return MaterialPageRoute(builder: (_) => const EditProfileScreen());
      case match:
        return MaterialPageRoute(builder: (_) => const MatchScreen());
      case chatList:
        return MaterialPageRoute(builder: (_) => const ChatListScreen());
      case chat:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => ChatScreen(
            userId: args['userId'] as String,
            userName: args['userName'] as String,
            userAvatar: args['userAvatar'] as String?,
            isOnline: args['isOnline'] as bool? ?? false,
          ),
        );
      case subscription:
        return MaterialPageRoute(builder: (_) => const SubscriptionScreen());
      case notifications:
        return MaterialPageRoute(builder: (_) => const NotificationScreen());
      case adminDashboard:
        return MaterialPageRoute(builder: (_) => const AdminDashboardScreen());
      case adminUsers:
        return MaterialPageRoute(builder: (_) => const UserManagementScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}
