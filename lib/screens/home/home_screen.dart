import 'package:flutter/material.dart';
import 'package:card_swiper/card_swiper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/routes/app_routes.dart';
import '../../core/constants/app_constants.dart';
import '../../models/user_model.dart';
import '../../services/profile/profile_service.dart';
import '../../services/match/match_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final ProfileService _profileService = ProfileService();
  final MatchService _matchService = MatchService();
  final SwiperController _swiperController = SwiperController();

  List<UserModel> _profiles = [];
  UserModel? _currentUser;
  bool _isLoading = true;
  int _currentIndex = 0;
  int _selectedNavIndex = 0;

  // Filters
  int? _filterMinAge;
  int? _filterMaxAge;
  String? _filterCity;
  String? _filterCaste;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  @override
  void dispose() {
    _swiperController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final response = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      _currentUser = UserModel.fromJson(response);
    } catch (e) {
      // User profile not found, continue without it
    }
  }

  Future<void> _loadProfiles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch current user's profile first to determine gender
      await _loadCurrentUser();

      if (_currentUser == null || _currentUser!.gender == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Fetch matching profiles based on current user's gender
      final matchingProfiles = await _profileService.getMatchingProfiles(
        userGender: _currentUser!.gender!,
        limit: 20,
        city: _filterCity,
        caste: _filterCaste,
        minAge: _filterMinAge,
        maxAge: _filterMaxAge,
      );

      setState(() {
        _profiles = matchingProfiles;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load profiles: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _refreshProfiles() async {
    await _loadProfiles();
  }

  Future<void> _onLike() async {
    if (_profiles.isEmpty || _currentIndex >= _profiles.length) return;

    final profile = _profiles[_currentIndex];
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _matchService.likeProfile(userId, profile.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Liked!'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 1),
          ),
        );
      }

      _swiperController.next();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to like: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _onSkip() async {
    if (_profiles.isEmpty || _currentIndex >= _profiles.length) return;

    final profile = _profiles[_currentIndex];
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _matchService.skipProfile(userId, profile.id);
      _swiperController.next();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to skip: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _onSuperLike() {
    // Super Like - could have special behavior
    _onLike();
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return _FilterDialog(
          minAge: _filterMinAge,
          maxAge: _filterMaxAge,
          city: _filterCity,
          caste: _filterCaste,
          onApply: (minAge, maxAge, city, caste) {
            setState(() {
              _filterMinAge = minAge;
              _filterMaxAge = maxAge;
              _filterCity = city;
              _filterCaste = caste;
            });
            _loadProfiles();
          },
        );
      },
    );
  }

  bool get _hasReachedDailyLimit {
    if (_currentUser == null) return false;
    return _currentUser!.hasReachedDailyLimit;
  }

  int get _dailyLimit {
    if (_currentUser == null) return AppConstants.dailyMatchLimit;
    return _currentUser!.dailyLimit;
  }

  int get _remainingViews {
    if (_currentUser == null) return AppConstants.dailyMatchLimit;
    return _currentUser!.dailyLimit - _currentUser!.dailyProfileViews;
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = _currentUser?.gender == Gender.female
        ? AppColors.femalePrimary
        : AppColors.malePrimary;

    return Scaffold(
      body: _isLoading
          ? _buildLoadingState()
          : RefreshIndicator(
              onRefresh: _refreshProfiles,
              child: Column(
                children: [
                  // App Bar
                  _buildAppBar(primaryColor),

                  // Daily Limit Indicator
                  _buildDailyLimitIndicator(primaryColor),

                  // Card Stack
                  Expanded(
                    child: _profiles.isEmpty
                        ? _buildEmptyState()
                        : _buildCardStack(),
                  ),

                  // Action Buttons
                  if (_profiles.isNotEmpty && !_hasReachedDailyLimit)
                    _buildActionButtons(primaryColor),

                  // Bottom Navigation
                  _buildBottomNavigation(primaryColor),
                ],
              ),
            ),
    );
  }

  Widget _buildAppBar(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(
                Icons.favorite,
                color: AppColors.white,
                size: 28,
              ),
              const SizedBox(width: 8),
              const Text(
                'Soul Mate',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.tune, color: AppColors.white),
            onPressed: _showFilterDialog,
            tooltip: 'Filters',
          ),
        ],
      ),
    );
  }

  Widget _buildDailyLimitIndicator(Color primaryColor) {
    final progress = _hasReachedDailyLimit
        ? 1.0
        : 1.0 - (_remainingViews / _dailyLimit);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.lightGrey,
      child: Row(
        children: [
          Icon(
            _hasReachedDailyLimit ? Icons.hourglass_empty : Icons.visibility,
            size: 18,
            color: _hasReachedDailyLimit ? AppColors.error : primaryColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _hasReachedDailyLimit
                      ? 'Daily limit reached'
                      : '$_remainingViews views remaining today',
                  style: TextStyle(
                    fontSize: 12,
                    color: _hasReachedDailyLimit
                        ? AppColors.error
                        : AppColors.darkGrey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.divider,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _hasReachedDailyLimit ? AppColors.error : primaryColor,
                  ),
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardStack() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Swiper(
        controller: _swiperController,
        itemCount: _profiles.length,
        itemBuilder: (context, index) {
          final profile = _profiles[index];
          return _buildProfileCard(profile);
        },
        onIndexChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        layout: SwiperLayout.STACK,
        itemWidth: double.infinity,
        itemHeight: double.infinity,
      ),
    );
  }

  Widget _buildProfileCard(UserModel profile) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRoutes.profile,
          arguments: profile.id,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowColor,
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Profile Image
              profile.profilePictureUrl != null
                  ? CachedNetworkImage(
                      imageUrl: profile.profilePictureUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: AppColors.lightGrey,
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: AppColors.lightGrey,
                        child: const Icon(
                          Icons.person,
                          size: 80,
                          color: AppColors.grey,
                        ),
                      ),
                    )
                  : Container(
                      color: AppColors.lightGrey,
                      child: const Icon(
                        Icons.person,
                        size: 80,
                        color: AppColors.grey,
                      ),
                    ),

              // Gradient overlay at bottom
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                      stops: const [0.3, 1.0],
                    ),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Name and Age
                      Row(
                        children: [
                          Text(
                            profile.fullName ?? 'Anonymous',
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (profile.age != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              '${profile.age}',
                              style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          if (profile.isVerified) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.success,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.verified,
                                    color: AppColors.white,
                                    size: 14,
                                  ),
                                  SizedBox(width: 2),
                                  Text(
                                    'Verified',
                                    style: TextStyle(
                                      color: AppColors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 4),

                      // Location
                      if (profile.city != null)
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: AppColors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              profile.city!,
                              style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),

                      const SizedBox(height: 4),

                      // Profession
                      if (profile.profession != null)
                        Text(
                          profile.profession!,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 14,
                          ),
                        ),

                      const SizedBox(height: 8),

                      // Short bio / personality traits
                      if (profile.personalityTraits != null &&
                          profile.personalityTraits!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            profile.personalityTraits!.take(3).join(', '),
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Skip Button
          _buildActionButton(
            icon: Icons.close,
            color: AppColors.error,
            onPressed: _onSkip,
            size: 56,
          ),

          // Super Like Button
          _buildActionButton(
            icon: Icons.star,
            color: AppColors.info,
            onPressed: _onSuperLike,
            size: 48,
          ),

          // Like Button
          _buildActionButton(
            icon: Icons.favorite,
            color: primaryColor,
            onPressed: _onLike,
            size: 56,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    double size = 56,
  }) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              icon,
              color: color,
              size: size * 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigation(Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Home',
                index: 0,
                primaryColor: primaryColor,
              ),
              _buildNavItem(
                icon: Icons.search,
                activeIcon: Icons.search,
                label: 'Search',
                index: 1,
                primaryColor: primaryColor,
              ),
              _buildNavItem(
                icon: Icons.favorite_border,
                activeIcon: Icons.favorite,
                label: 'Matches',
                index: 2,
                primaryColor: primaryColor,
              ),
              _buildNavItem(
                icon: Icons.chat_bubble_outline,
                activeIcon: Icons.chat_bubble,
                label: 'Chat',
                index: 3,
                primaryColor: primaryColor,
              ),
              _buildNavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Profile',
                index: 4,
                primaryColor: primaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    required Color primaryColor,
  }) {
    final isSelected = _selectedNavIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedNavIndex = index;
        });
        _onNavItemTap(index);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSelected ? activeIcon : icon,
            color: isSelected ? primaryColor : AppColors.grey,
            size: 24,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isSelected ? primaryColor : AppColors.grey,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  void _onNavItemTap(int index) {
    switch (index) {
      case 0:
        // Home - already here
        break;
      case 1:
        // Search - navigate to search
        break;
      case 2:
        // Matches - navigate to matches
        break;
      case 3:
        // Chat - navigate to chat
        Navigator.pushNamed(context, AppRoutes.chatList);
        break;
      case 4:
        // Profile - navigate to profile
        if (_currentUser != null) {
          Navigator.pushNamed(
            context,
            AppRoutes.profile,
            arguments: _currentUser!.id,
          );
        }
        break;
    }
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          const Text(
            'Finding your perfect match...',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.darkGrey,
            ),
          ),
        ],
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
              Icons.favorite_border,
              size: 80,
              color: AppColors.grey.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'No matches found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.darkGrey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try adjusting your filters or check back later for new profiles',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.grey,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshProfiles,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Filter Dialog Widget
class _FilterDialog extends StatefulWidget {
  final int? minAge;
  final int? maxAge;
  final String? city;
  final String? caste;
  final Function(int? minAge, int? maxAge, String? city, String? caste) onApply;

  const _FilterDialog({
    this.minAge,
    this.maxAge,
    this.city,
    this.caste,
    required this.onApply,
  });

  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  late int? _minAge;
  late int? _maxAge;
  late String? _city;
  late String? _caste;

  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _casteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _minAge = widget.minAge;
    _maxAge = widget.maxAge;
    _city = widget.city;
    _caste = widget.caste;
    _cityController.text = _city ?? '';
    _casteController.text = _caste ?? '';
  }

  @override
  void dispose() {
    _cityController.dispose();
    _casteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filters'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Age Range
            const Text(
              'Age Range',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Min Age',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: _minAge?.toString(),
                    onChanged: (value) {
                      _minAge = value.isNotEmpty ? int.tryParse(value) : null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Max Age',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: _maxAge?.toString(),
                    onChanged: (value) {
                      _maxAge = value.isNotEmpty ? int.tryParse(value) : null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // City
            const Text(
              'City',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _cityController,
              decoration: const InputDecoration(
                hintText: 'Enter city',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Caste
            const Text(
              'Caste',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _casteController,
              decoration: const InputDecoration(
                hintText: 'Enter caste (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            setState(() {
              _minAge = null;
              _maxAge = null;
              _city = null;
              _caste = null;
              _cityController.clear();
              _casteController.clear();
            });
          },
          child: const Text('Clear'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onApply(
              _minAge,
              _maxAge,
              _cityController.text.isEmpty ? null : _cityController.text,
              _casteController.text.isEmpty ? null : _casteController.text,
            );
            Navigator.of(context).pop();
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
