import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../models/report_model.dart';
import '../../models/user_model.dart';
import '../../services/match/match_service.dart';
import '../../services/profile/profile_service.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;
  final double? compatibilityScore;
  final List<String>? matchReasons;

  const ProfileScreen({
    super.key,
    required this.userId,
    this.compatibilityScore,
    this.matchReasons,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService _profileService = ProfileService();
  final MatchService _matchService = MatchService();

  UserModel? _user;
  double? _compatibilityScore;
  List<String>? _matchReasons;
  bool _isLoading = true;
  bool _isMutualMatch = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = await _profileService.getUserProfile(widget.userId);
      setState(() {
        _user = user;
      });

      // Calculate compatibility if not provided
      if (widget.compatibilityScore == null) {
        final currentUserId = Supabase.instance.client.auth.currentUser?.id;
        if (currentUserId != null) {
          final currentUserProfile =
              await _profileService.getUserProfile(currentUserId);
          if (currentUserProfile != null && user != null) {
            final compatibility = await _matchService.calculateCompatibility(
              currentUser: currentUserProfile,
              targetUser: user!,
            );
            setState(() {
              _compatibilityScore = compatibility.compatibilityScore;
              _matchReasons = compatibility.matchReasons;
            });
          }
        }
      } else {
        setState(() {
          _compatibilityScore = widget.compatibilityScore;
          _matchReasons = widget.matchReasons;
        });
      }

      // Check mutual match
      await _checkMutualMatch();
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _checkMutualMatch() async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;

    try {
      final mutualMatches = await _matchService.getMutualMatches(currentUserId);
      final isMutual = mutualMatches.any((match) => match.id == widget.userId);
      if (mounted) {
        setState(() => _isMutualMatch = isMutual);
      }
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _handleLike() async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;

    try {
      await _matchService.likeProfile(currentUserId, widget.userId);
      await _checkMutualMatch();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile liked!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
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

  Future<void> _handleSkip() async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;

    try {
      await _matchService.skipProfile(currentUserId, widget.userId);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
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

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => _ReportDialog(reportedUserId: widget.userId),
    );
  }

  String _formatEnum(String? value) {
    if (value == null) return 'N/A';
    final raw = value.split('.').last;
    return raw[0].toUpperCase() +
        raw.substring(1).replaceAllMapped(
              RegExp(r'([A-Z])'),
              (match) => ' ${match.group(1)}',
            );
  }

  String _formatHeight(double? heightCm) {
    if (heightCm == null) return 'N/A';
    final feet = (heightCm / 30.48).floor();
    final inches = ((heightCm / 2.54) % 12).round();
    return '${feet}\'${inches}" ($heightCm cm)';
  }

  String _formatWeight(double? weight) {
    if (weight == null) return 'N/A';
    return '${weight.toStringAsFixed(1)} kg';
  }

  String _formatIncome(double? income) {
    if (income == null) return 'N/A';
    return '${income.toStringAsFixed(0)} / month';
  }

  Color _getPrimaryColor() {
    return _user?.gender == Gender.female
        ? AppColors.femalePrimary
        : AppColors.malePrimary;
  }

  Color _getAccentColor() {
    return _user?.gender == Gender.female
        ? AppColors.femaleAccent
        : AppColors.maleAccent;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _user == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: AppColors.grey.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                _error ?? 'User not found',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.darkGrey,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadUserProfile,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final primaryColor = _getPrimaryColor();
    final accentColor = _getAccentColor();

    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.darkGrey),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.report_outlined, color: AppColors.darkGrey),
            onPressed: _showReportDialog,
            tooltip: 'Report',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Header Card
                  _buildProfileHeader(primaryColor, accentColor, theme),
                  const SizedBox(height: 12),

                  // Compatibility Score Card
                  if (_compatibilityScore != null)
                    _buildCompatibilityCard(theme),
                  if (_compatibilityScore != null) const SizedBox(height: 12),

                  // Match Reasons Card
                  if (_matchReasons != null && _matchReasons!.isNotEmpty)
                    _buildMatchReasonsCard(theme),
                  if (_matchReasons != null && _matchReasons!.isNotEmpty)
                    const SizedBox(height: 12),

                  // Basic Info Card
                  _buildBasicInfoCard(theme),
                  const SizedBox(height: 12),

                  // Personal Details Card
                  _buildPersonalDetailsCard(theme),
                  const SizedBox(height: 12),

                  // Education & Career Card
                  _buildEducationCareerCard(theme),
                  const SizedBox(height: 12),

                  // Lifestyle Card
                  _buildLifestyleCard(theme),
                  const SizedBox(height: 12),

                  // Interests & Hobbies Card
                  if (_user!.hobbies != null && _user!.hobbies!.isNotEmpty)
                    _buildHobbiesCard(theme),
                  if (_user!.hobbies != null && _user!.hobbies!.isNotEmpty)
                    const SizedBox(height: 12),

                  // Personality Traits Card
                  if (_user!.personalityTraits != null &&
                      _user!.personalityTraits!.isNotEmpty)
                    _buildPersonalityTraitsCard(theme),
                  if (_user!.personalityTraits != null &&
                      _user!.personalityTraits!.isNotEmpty)
                    const SizedBox(height: 12),

                  // Family Background Card
                  if (_user!.familyBackground != null &&
                      _user!.familyBackground!.isNotEmpty)
                    _buildFamilyBackgroundCard(theme),
                  if (_user!.familyBackground != null &&
                      _user!.familyBackground!.isNotEmpty)
                    const SizedBox(height: 12),

                  // Contact & Address Card
                  _buildContactAddressCard(theme),
                  const SizedBox(height: 12),

                  // Preferred Partner Criteria Card
                  if (_user!.preferredPartnerCriteria != null &&
                      _user!.preferredPartnerCriteria!.isNotEmpty)
                    _buildPreferredPartnerCard(theme),
                  const SizedBox(height: 12),

                  // Mutual Match Message Card
                  if (_isMutualMatch) _buildMutualMatchCard(theme),
                  if (_isMutualMatch) const SizedBox(height: 12),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),

          // Action Buttons
          _buildActionButtons(primaryColor, accentColor, theme),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(
      Color primaryColor, Color accentColor, ThemeData theme) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Profile Picture
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: primaryColor,
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 70,
                  backgroundColor: AppColors.lightGrey,
                  backgroundImage: _user!.profilePictureUrl != null
                      ? CachedNetworkImageProvider(_user!.profilePictureUrl!)
                      : null,
                  child: _user!.profilePictureUrl == null
                      ? Icon(
                          Icons.person,
                          size: 60,
                          color: AppColors.grey.withOpacity(0.5),
                        )
                      : null,
                ),
              ),
              if (_user!.isVerified)
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.verified,
                      color: AppColors.white,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Name & Age
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                _user!.fullName ?? 'Anonymous',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkGrey,
                ),
              ),
              if (_user!.age != null) ...[
                const SizedBox(width: 8),
                Text(
                  ', ${_user!.age}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: AppColors.grey,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),

          // Location
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_on, size: 18, color: AppColors.grey),
              const SizedBox(width: 4),
              Text(
                _buildLocationString(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Subscription Badge
          if (_user!.subscriptionTier != SubscriptionTier.free)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                gradient: _user!.subscriptionTier == SubscriptionTier.gold
                    ? const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFFA500)])
                    : const LinearGradient(
                        colors: [Color(0xFFB0BEC5), Color(0xFF90A4AE)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _user!.subscriptionTier.toString().split('.').last.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildCompatibilityCard(ThemeData theme) {
    final score = _compatibilityScore! / 100;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircularPercentIndicator(
            radius: 50,
            lineWidth: 8,
            percent: score,
            center: Text(
              '${_compatibilityScore!.toInt()}%',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _getAccentColor(),
              ),
            ),
            progressColor: _getAccentColor(),
            backgroundColor: _getAccentColor().withOpacity(0.2),
            circularStrokeCap: CircularStrokeCap.round,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Compatibility Score',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkGrey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getCompatibilityLabel(score),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchReasonsCard(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getAccentColor().withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: _getAccentColor(), size: 20),
              const SizedBox(width: 8),
              Text(
                'AI Match Reasons',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkGrey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _matchReasons!
                .map((reason) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getAccentColor().withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        reason,
                        style: TextStyle(
                          color: _getAccentColor(),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoCard(ThemeData theme) {
    return _buildSectionCard(
      theme,
      'Basic Information',
      Icons.person_outline,
      [
        _buildInfoRow(Icons.badge_outlined, 'Full Name', _user!.fullName),
        _buildInfoRow(Icons.man, 'Father\'s Name', _user!.fatherName),
        _buildInfoRow(Icons.woman, 'Mother\'s Name', _user!.motherName),
        _buildInfoRow(Icons.cake_outlined, 'Age',
            _user!.age != null ? '${_user!.age} years' : null),
      ],
    );
  }

  Widget _buildPersonalDetailsCard(ThemeData theme) {
    return _buildSectionCard(
      theme,
      'Personal Details',
      Icons.info_outline,
      [
        _buildInfoRow(Icons.groups, 'Caste', _user!.caste),
        _buildInfoRow(Icons.temple_buddhist_outlined, 'Religion', _user!.religion),
        _buildInfoRow(Icons.favorite_border, 'Marital Status',
            _formatEnum(_user!.maritalStatus?.toString())),
        _buildInfoRow(Icons.height, 'Height', _formatHeight(_user!.height)),
        _buildInfoRow(Icons.monitor_weight_outlined, 'Weight',
            _formatWeight(_user!.weight)),
      ],
    );
  }

  Widget _buildEducationCareerCard(ThemeData theme) {
    return _buildSectionCard(
      theme,
      'Education & Career',
      Icons.work_outline,
      [
        _buildInfoRow(Icons.school_outlined, 'Qualification', _user!.qualification),
        _buildInfoRow(Icons.business_center_outlined, 'Profession', _user!.profession),
        _buildInfoRow(Icons.apartment, 'Company', _user!.companyName),
        _buildInfoRow(Icons.attach_money, 'Monthly Income',
            _formatIncome(_user!.monthlyIncome)),
      ],
    );
  }

  Widget _buildLifestyleCard(ThemeData theme) {
    return _buildSectionCard(
      theme,
      'Lifestyle',
      Icons.local_dining_outlined,
      [
        _buildInfoRow(
          Icons.smoke_free_outlined,
          'Smoking',
          _formatEnum(_user!.smokingHabit?.toString()),
          valueColor: _getHabitColor(_user!.smokingHabit),
        ),
        _buildInfoRow(
          Icons.local_bar_outlined,
          'Drinking',
          _formatEnum(_user!.drinkingHabit?.toString()),
          valueColor: _getHabitColor(_user!.drinkingHabit),
        ),
      ],
    );
  }

  Widget _buildHobbiesCard(ThemeData theme) {
    return _buildChipSectionCard(
      theme,
      'Interests & Hobbies',
      Icons.emoji_events_outlined,
      _user!.hobbies!,
      _getAccentColor(),
    );
  }

  Widget _buildPersonalityTraitsCard(ThemeData theme) {
    return _buildChipSectionCard(
      theme,
      'Personality Traits',
      Icons.psychology_outlined,
      _user!.personalityTraits!,
      _getPrimaryColor(),
    );
  }

  Widget _buildFamilyBackgroundCard(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.family_restroom, color: _getPrimaryColor()),
              const SizedBox(width: 12),
              Text(
                'Family Background',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkGrey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _user!.familyBackground!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.darkGrey,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactAddressCard(ThemeData theme) {
    return _buildSectionCard(
      theme,
      'Contact & Address',
      Icons.contact_mail_outlined,
      [
        _buildInfoRow(Icons.phone_outlined, 'Phone', _user!.phone),
        _buildInfoRow(Icons.location_city_outlined, 'City', _user!.city),
        if (_user!.area != null)
          _buildInfoRow(Icons.place_outlined, 'Area', _user!.area),
        _buildInfoRow(Icons.public, 'Country', _user!.country),
        if (_user!.address != null)
          _buildInfoRow(Icons.home_outlined, 'Address', _user!.address),
      ],
    );
  }

  Widget _buildPreferredPartnerCard(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite_border, color: _getAccentColor()),
              const SizedBox(width: 12),
              Text(
                'Preferred Partner Criteria',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkGrey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _user!.preferredPartnerCriteria!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.darkGrey,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMutualMatchCard(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getAccentColor(),
            _getPrimaryColor(),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _getAccentColor().withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.favorite,
            color: AppColors.white,
            size: 40,
          ),
          const SizedBox(height: 8),
          Text(
            'It\'s a Match!',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'You both liked each other',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                // Navigate to chat
                Navigator.pop(context);
                // TODO: Navigate to chat screen with this user
              },
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Send Message'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.white,
                foregroundColor: _getAccentColor(),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
    ThemeData theme,
    String title,
    IconData icon,
    List<Widget> children,
  ) {
    final validChildren = children.where((c) => c != const SizedBox.shrink()).toList();
    if (validChildren.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _getPrimaryColor()),
              const SizedBox(width: 12),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkGrey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...validChildren,
        ],
      ),
    );
  }

  Widget _buildChipSectionCard(
    ThemeData theme,
    String title,
    IconData icon,
    List<String> items,
    Color chipColor,
  ) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: chipColor),
              const SizedBox(width: 12),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkGrey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items
                .map((item) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: chipColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: chipColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        item,
                        style: TextStyle(
                          color: chipColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String? value, {
    Color? valueColor,
  }) {
    if (value == null || value.isEmpty || value == 'N/A') {
      return const SizedBox.shrink();
    }

    final displayColor = valueColor ?? AppColors.darkGrey;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    color: displayColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
      Color primaryColor, Color accentColor, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Skip Button
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _handleSkip,
                icon: const Icon(Icons.close),
                label: const Text('Skip'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.darkGrey,
                  side: const BorderSide(color: AppColors.grey),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Like Button
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _handleLike,
                icon: const Icon(Icons.favorite),
                label: Text(_isMutualMatch ? 'Matched!' : 'Like'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Report Button
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _showReportDialog,
                icon: const Icon(Icons.flag_outlined),
                label: const Text('Report'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(color: AppColors.error.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildLocationString() {
    final parts = <String>[];
    if (_user!.city != null) parts.add(_user!.city!);
    if (_user!.country != null) parts.add(_user!.country!);
    return parts.isEmpty ? 'Location not specified' : parts.join(', ');
  }

  String _getCompatibilityLabel(double score) {
    if (score >= 0.8) return 'Excellent Match';
    if (score >= 0.6) return 'Good Match';
    if (score >= 0.4) return 'Moderate Match';
    return 'Low Match';
  }

  Color _getHabitColor(dynamic habit) {
    if (habit == null) return AppColors.darkGrey;
    final habitStr = habit.toString().toLowerCase();
    if (habitStr.contains('non')) return AppColors.success;
    if (habitStr.contains('occasional') || habitStr.contains('socially')) {
      return AppColors.warning;
    }
    return AppColors.error;
  }
}

class _ReportDialog extends StatefulWidget {
  final String reportedUserId;

  const _ReportDialog({required this.reportedUserId});

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  ReportReason? _selectedReason;
  final TextEditingController _descriptionController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submitReport() async {
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a reason'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('User not logged in');

      await Supabase.instance.client.from('reports').insert({
        'reporter_id': currentUserId,
        'reported_user_id': widget.reportedUserId,
        'reason': _selectedReason.toString().split('.').last,
        'description':
            _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Report submitted successfully'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit report: ${e.toString()}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag_outlined, color: AppColors.error, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Report User',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkGrey,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Text(
              'Select a reason for reporting this profile:',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.darkGrey,
              ),
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ReportReason.values.map((reason) {
                final isSelected = _selectedReason == reason;
                final label = _formatEnum(reason.toString());
                return ChoiceChip(
                  label: Text(label),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedReason = selected ? reason : null;
                    });
                  },
                  selectedColor: AppColors.error.withOpacity(0.2),
                  checkmarkColor: AppColors.error,
                  labelStyle: TextStyle(
                    color: isSelected ? AppColors.error : AppColors.darkGrey,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Additional Details (Optional)',
                hintText: 'Provide more information about your report...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.error, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : const Text('Submit Report'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatEnum(String value) {
    final raw = value.split('.').last;
    return raw[0].toUpperCase() +
        raw.substring(1).replaceAllMapped(
              RegExp(r'([A-Z])'),
              (match) => ' ${match.group(1)}',
            );
  }
}
