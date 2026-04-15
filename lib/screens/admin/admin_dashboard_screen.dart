import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/profile/profile_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final ProfileService _profileService = ProfileService();
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = true;
  UserModel? _currentUser;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _recentActivity = [];

  @override
  void initState() {
    super.initState();
    _checkAdminAndLoad();
  }

  Future<void> _checkAdminAndLoad() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        _navigateToLogin();
        return;
      }

      _currentUser = await _profileService.getUserProfile(userId);

      if (_currentUser?.role != UserRole.admin) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Access denied. Admin only.'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context);
        }
        return;
      }

      await _loadStats();
      await _loadRecentActivity();
    } catch (e) {
      // Silently fail
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToLogin() {
    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  Future<void> _loadStats() async {
    try {
      // Total users
      final totalUsersResponse = await _supabase
          .from('profiles')
          .select('id')
          .count();
      final totalUsers = totalUsersResponse.count;

      // Active users today
      final activeUsersResponse = await _supabase
          .from('profiles')
          .select('id')
          .eq('is_active', true)
          .count();
      final activeUsers = activeUsersResponse.count;

      // Total matches
      final totalMatchesResponse = await _supabase
          .from('matches')
          .select('id')
          .count();
      final totalMatches = totalMatchesResponse.count;

      // Pending reports
      final pendingReportsResponse = await _supabase
          .from('reports')
          .select('id')
          .eq('status', 'pending')
          .count();
      final pendingReports = pendingReportsResponse.count;

      // Revenue this month
      final startOfMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
      final revenueResponse = await _supabase
          .from('subscriptions')
          .select('amount')
          .gte('created_at', startOfMonth.toIso8601String());
      double revenue = 0;
      for (final sub in revenueResponse) {
        revenue += (sub['amount'] as num?)?.toDouble() ?? 0;
      }

      setState(() {
        _stats = {
          'totalUsers': totalUsers,
          'activeUsers': activeUsers,
          'totalMatches': totalMatches,
          'pendingReports': pendingReports,
          'revenue': revenue,
        };
      });
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _loadRecentActivity() async {
    try {
      // Recent user registrations
      final recentUsers = await _supabase
          .from('profiles')
          .select('id, full_name, created_at')
          .order('created_at', ascending: false)
          .limit(5);

      if (recentUsers.isNotEmpty) {
        setState(() {
          _recentActivity = recentUsers.map((user) {
            return {
              'type': 'new_user',
              'title': user['full_name'] ?? 'New User',
              'message': 'Registered',
              'createdAt': DateTime.parse(user['created_at']),
            };
          }).toList();
        });
      }
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _refresh() async {
    await Future.wait([
      _loadStats(),
      _loadRecentActivity(),
    ]);
  }

  Color _getPrimaryColor() {
    return _currentUser?.gender == Gender.female
        ? AppColors.femalePrimary
        : AppColors.malePrimary;
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(symbol: 'PKR ', decimalDigits: 0).format(amount);
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = _getPrimaryColor();

    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.darkGrey),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(
            color: AppColors.darkGrey,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.darkGrey),
            onPressed: _refresh,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              color: primaryColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatsGrid(primaryColor),
                    const SizedBox(height: 24),
                    _buildQuickActions(primaryColor),
                    const SizedBox(height: 24),
                    _buildRecentActivity(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatsGrid(Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Overview',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.darkGrey,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildStatCard(
              icon: Icons.people,
              title: 'Total Users',
              value: '${_stats['totalUsers'] ?? 0}',
              color: primaryColor,
            ),
            _buildStatCard(
              icon: Icons.person_add,
              title: 'Active Today',
              value: '${_stats['activeUsers'] ?? 0}',
              color: AppColors.success,
            ),
            _buildStatCard(
              icon: Icons.favorite,
              title: 'Total Matches',
              value: '${_stats['totalMatches'] ?? 0}',
              color: AppColors.femaleAccent,
            ),
            _buildStatCard(
              icon: Icons.report_problem,
              title: 'Pending Reports',
              value: '${_stats['pendingReports'] ?? 0}',
              color: AppColors.warning,
            ),
            _buildStatCard(
              icon: Icons.attach_money,
              title: 'Revenue (Month)',
              value: _formatCurrency(_stats['revenue'] ?? 0),
              color: AppColors.gold,
              isFullWidth: true,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    bool isFullWidth = false,
  }) {
    final width = isFullWidth ? double.infinity : (MediaQuery.of(context).size.width - 44) / 2;

    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.darkGrey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.darkGrey,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowColor,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildQuickActionButton(
                      icon: Icons.people_alt,
                      label: 'Manage Users',
                      color: primaryColor,
                      onTap: () {
                        Navigator.pushNamed(context, AppRoutes.adminUsers);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildQuickActionButton(
                      icon: Icons.report_outlined,
                      label: 'View Reports',
                      color: AppColors.warning,
                      onTap: () {
                        // TODO: Navigate to reports screen
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildQuickActionButton(
                      icon: Icons.verified_user,
                      label: 'Verify Profiles',
                      color: AppColors.success,
                      onTap: () {
                        // TODO: Navigate to verify profiles screen
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildQuickActionButton(
                      icon: Icons.analytics,
                      label: 'Analytics',
                      color: AppColors.info,
                      onTap: () {
                        // TODO: Navigate to analytics screen
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(color: color.withOpacity(0.3), width: 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Activity',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.darkGrey,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowColor,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: _recentActivity.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No recent activity',
                      style: TextStyle(
                        color: AppColors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _recentActivity.length,
                  separatorBuilder: (context, index) => const Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                  ),
                  itemBuilder: (context, index) {
                    final activity = _recentActivity[index];
                    return ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.person_add,
                          color: AppColors.success,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        activity['title'] ?? '',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkGrey,
                        ),
                      ),
                      subtitle: Text(
                        activity['message'] ?? '',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.grey,
                        ),
                      ),
                      trailing: Text(
                        _formatTimeAgo(activity['createdAt']),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.grey,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
