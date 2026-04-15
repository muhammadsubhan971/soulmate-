import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/profile/profile_service.dart';

enum UserFilter { all, active, blocked, free, silver, gold }

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final ProfileService _profileService = ProfileService();
  final SupabaseClient _supabase = Supabase.instance.client;

  List<UserModel> _users = [];
  List<UserModel> _filteredUsers = [];
  bool _isLoading = true;
  UserModel? _currentUser;
  UserFilter _selectedFilter = UserFilter.all;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkAdminAndLoad();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

      await _loadUsers();
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

  Future<void> _loadUsers() async {
    try {
      final users = await _profileService.getAllUsers(limit: 100);
      setState(() {
        _users = users;
        _applyFilters();
      });
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _refresh() async {
    try {
      await _loadUsers();
    } catch (e) {
      // Silently fail
    }
  }

  void _applyFilters() {
    var filtered = List<UserModel>.from(_users);

    // Apply status/tier filter
    switch (_selectedFilter) {
      case UserFilter.all:
        break;
      case UserFilter.active:
        filtered = filtered.where((u) => u.isActive && !u.isBlocked).toList();
        break;
      case UserFilter.blocked:
        filtered = filtered.where((u) => u.isBlocked).toList();
        break;
      case UserFilter.free:
        filtered = filtered.where((u) => u.subscriptionTier == SubscriptionTier.free).toList();
        break;
      case UserFilter.silver:
        filtered = filtered.where((u) => u.subscriptionTier == SubscriptionTier.silver).toList();
        break;
      case UserFilter.gold:
        filtered = filtered.where((u) => u.subscriptionTier == SubscriptionTier.gold).toList();
        break;
    }

    // Apply search filter
    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((user) {
        final name = (user.fullName ?? '').toLowerCase();
        final email = user.email.toLowerCase();
        return name.contains(query) || email.contains(query);
      }).toList();
    }

    setState(() => _filteredUsers = filtered);
  }

  void _onSearchChanged(String query) {
    _applyFilters();
  }

  Color _getPrimaryColor() {
    return _currentUser?.gender == Gender.female
        ? AppColors.femalePrimary
        : AppColors.malePrimary;
  }

  Color _getSubscriptionColor(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.free:
        return AppColors.free;
      case SubscriptionTier.silver:
        return AppColors.silver;
      case SubscriptionTier.gold:
        return AppColors.gold;
    }
  }

  String _formatSubscriptionTier(SubscriptionTier tier) {
    return tier.toString().split('.').last.toUpperCase();
  }

  Future<void> _showUserActions(UserModel user) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // User header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.lightGrey,
                        backgroundImage: user.profilePictureUrl != null
                            ? CachedNetworkImageProvider(user.profilePictureUrl!)
                            : null,
                        child: user.profilePictureUrl == null
                            ? const Icon(Icons.person, size: 24, color: AppColors.grey)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.fullName ?? 'Anonymous',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.darkGrey,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              user.email,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.grey,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),

                // Actions
                ListTile(
                  leading: Icon(Icons.visibility, color: _getPrimaryColor()),
                  title: const Text('View Profile'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(
                      context,
                      AppRoutes.profile,
                      arguments: user.id,
                    );
                  },
                ),
                if (!user.isBlocked)
                  ListTile(
                    leading: const Icon(Icons.block, color: AppColors.error),
                    title: const Text('Block User'),
                    onTap: () {
                      Navigator.pop(context);
                      _confirmBlockUser(user);
                    },
                  ),
                if (user.isBlocked)
                  ListTile(
                    leading: const Icon(Icons.remove_circle_outline, color: AppColors.success),
                    title: const Text('Unblock User'),
                    onTap: () {
                      Navigator.pop(context);
                      _unblockUser(user);
                    },
                  ),
                if (!user.isVerified)
                  ListTile(
                    leading: const Icon(Icons.verified, color: AppColors.success),
                    title: const Text('Verify Profile'),
                    onTap: () {
                      Navigator.pop(context);
                      _verifyUser(user);
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: AppColors.error),
                  title: const Text('Delete User'),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDeleteUser(user);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmBlockUser(UserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block User'),
        content: Text('Are you sure you want to block ${user.fullName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Block'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _blockUser(user);
    }
  }

  Future<void> _blockUser(UserModel user) async {
    try {
      await _profileService.blockUser(user.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.fullName} blocked'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        await _refresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to block user: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _unblockUser(UserModel user) async {
    try {
      await _profileService.unblockUser(user.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.fullName} unblocked'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        await _refresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to unblock user: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _verifyUser(UserModel user) async {
    try {
      await _supabase
          .from('profiles')
          .update({'is_verified': true})
          .eq('id', user.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.fullName} verified'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        await _refresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to verify user: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteUser(UserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text(
          'Are you sure you want to delete ${user.fullName}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteUser(user);
    }
  }

  Future<void> _deleteUser(UserModel user) async {
    try {
      await _profileService.deleteProfile(user.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.fullName} deleted'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        await _refresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete user: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
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
          'User Management',
          style: TextStyle(
            color: AppColors.darkGrey,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search by name or email...',
                      prefixIcon: const Icon(Icons.search, color: AppColors.grey),
                      filled: true,
                      fillColor: AppColors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ),

                // Filter buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip(
                          label: 'All',
                          filter: UserFilter.all,
                          primaryColor: primaryColor,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: 'Active',
                          filter: UserFilter.active,
                          primaryColor: primaryColor,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: 'Blocked',
                          filter: UserFilter.blocked,
                          primaryColor: primaryColor,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: 'Free',
                          filter: UserFilter.free,
                          primaryColor: primaryColor,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: 'Silver',
                          filter: UserFilter.silver,
                          primaryColor: primaryColor,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: 'Gold',
                          filter: UserFilter.gold,
                          primaryColor: primaryColor,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // User count
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_filteredUsers.length} users',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 20),
                        onPressed: _refresh,
                        tooltip: 'Refresh',
                      ),
                    ],
                  ),
                ),

                // User list
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    color: primaryColor,
                    child: _filteredUsers.isEmpty
                        ? _buildEmptyState()
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _filteredUsers.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final user = _filteredUsers[index];
                              return _buildUserTile(user);
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required UserFilter filter,
    required Color primaryColor,
  }) {
    final isSelected = _selectedFilter == filter;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _selectedFilter = filter);
        _applyFilters();
      },
      selectedColor: primaryColor.withOpacity(0.15),
      checkmarkColor: primaryColor,
      labelStyle: TextStyle(
        color: isSelected ? primaryColor : AppColors.darkGrey,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        fontSize: 13,
      ),
      side: BorderSide(
        color: isSelected ? primaryColor : AppColors.divider,
        width: isSelected ? 1.5 : 1,
      ),
    );
  }

  Widget _buildUserTile(UserModel user) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 0.5,
      child: InkWell(
        onTap: () => _showUserActions(user),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Profile picture
              Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.lightGrey,
                    backgroundImage: user.profilePictureUrl != null
                        ? CachedNetworkImageProvider(user.profilePictureUrl!)
                        : null,
                    child: user.profilePictureUrl == null
                        ? const Icon(Icons.person, size: 28, color: AppColors.grey)
                        : null,
                  ),
                  if (user.isVerified)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.white, width: 1.5),
                        ),
                        child: const Icon(
                          Icons.verified,
                          color: AppColors.white,
                          size: 12,
                        ),
                      ),
                    ),
                  if (user.isBlocked)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.white, width: 1.5),
                        ),
                        child: const Icon(
                          Icons.block,
                          color: AppColors.white,
                          size: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),

              // User info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user.fullName ?? 'Anonymous',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.darkGrey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Subscription badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getSubscriptionColor(user.subscriptionTier)
                                .withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _formatSubscriptionTier(user.subscriptionTier),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _getSubscriptionColor(user.subscriptionTier),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.grey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: user.isActive ? AppColors.success : AppColors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          user.isBlocked ? 'Blocked' : (user.isActive ? 'Active' : 'Inactive'),
                          style: TextStyle(
                            fontSize: 11,
                            color: user.isBlocked ? AppColors.error : AppColors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Arrow
              const Icon(
                Icons.chevron_right,
                color: AppColors.grey,
                size: 20,
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
              Icons.people_outline,
              size: 80,
              color: AppColors.grey.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            const Text(
              'No users found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.darkGrey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try adjusting your search or filters',
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
