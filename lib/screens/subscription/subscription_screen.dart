import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../models/user_model.dart';
import '../../services/profile/profile_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final ProfileService _profileService = ProfileService();
  UserModel? _currentUser;
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
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

      if (mounted) {
        setState(() {
          _currentUser = UserModel.fromJson(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handlePlanSelection(SubscriptionTier tier) async {
    if (tier == SubscriptionTier.free) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are already on the Free plan'),
          backgroundColor: AppColors.info,
        ),
      );
      return;
    }

    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      // TODO: Integrate Stripe payment here
      // For now, simulate a successful payment
      await _showPaymentConfirmation(tier);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _showPaymentConfirmation(SubscriptionTier tier) async {
    final price = tier == SubscriptionTier.silver
        ? AppConstants.silverPrice
        : AppConstants.goldPrice;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Plan: ${tier.toString().split('.').last.toUpperCase()}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Amount: PKR ${price.toStringAsFixed(0)}'),
            const SizedBox(height: 8),
            const Text(
              'Payment will be processed via Stripe.',
              style: TextStyle(fontSize: 12, color: AppColors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _processSubscription(tier, price);
    }
  }

  Future<void> _processSubscription(SubscriptionTier tier, double price) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      final expiryDate = DateTime.now().add(const Duration(days: 30));

      // Insert subscription record
      await Supabase.instance.client.from('subscriptions').insert({
        'user_id': userId,
        'tier': tier.toString().split('.').last,
        'amount': price,
        'currency': 'PKR',
        'start_date': DateTime.now().toIso8601String(),
        'end_date': expiryDate.toIso8601String(),
        'status': 'active',
        'payment_method': 'stripe',
      });

      // Update user profile
      await _profileService.updateProfileFields({
        'subscription_tier': tier.toString().split('.').last,
        'subscription_expiry': expiryDate.toIso8601String(),
      });

      await _loadCurrentUser();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully upgraded to ${tier.toString().split('.').last.toUpperCase()}!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process subscription: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _restorePurchases() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      final response = await Supabase.instance.client
          .from('subscriptions')
          .select()
          .eq('user_id', userId)
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(1);

      if (response.isNotEmpty) {
        final subscription = response[0];
        final tier = SubscriptionTier.values.firstWhere(
          (e) => e.toString() == 'SubscriptionTier.${subscription['tier']}',
          orElse: () => SubscriptionTier.free,
        );

        await _profileService.updateProfileFields({
          'subscription_tier': tier.toString().split('.').last,
          'subscription_expiry': subscription['end_date'],
        });

        await _loadCurrentUser();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Purchases restored successfully'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No active subscriptions found'),
              backgroundColor: AppColors.info,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to restore purchases: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF667eea),
              Color(0xFF764ba2),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_currentUser != null) _buildCurrentPlanCard(),
                      const SizedBox(height: 24),
                      const Text(
                        'Choose Your Plan',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildFreePlanCard(),
                      const SizedBox(height: 16),
                      _buildSilverPlanCard(),
                      const SizedBox(height: 16),
                      _buildGoldPlanCard(),
                      const SizedBox(height: 24),
                      _buildRestorePurchasesButton(),
                      const SizedBox(height: 16),
                      _buildTermsAndConditions(),
                      const SizedBox(height: 16),
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

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          const Text(
            'Upgrade Plan',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentPlanCard() {
    final isPremium = _currentUser!.subscriptionTier != SubscriptionTier.free;
    final tierColor = _currentUser!.subscriptionTier == SubscriptionTier.gold
        ? AppColors.gold
        : AppColors.silver;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.white.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star, color: AppColors.white, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Current Plan',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isPremium ? tierColor : AppColors.free,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _currentUser!.subscriptionTier.toString().split('.').last.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildUsageIndicator(
            label: 'Daily Views',
            current: _currentUser!.dailyProfileViews,
            max: _currentUser!.dailyLimit,
            color: isPremium ? tierColor : AppColors.free,
          ),
          const SizedBox(height: 8),
          _buildUsageIndicator(
            label: 'Daily Likes',
            current: _currentUser!.dailyLikes,
            max: _currentUser!.dailyLimit,
            color: isPremium ? tierColor : AppColors.free,
          ),
          if (isPremium && _currentUser!.subscriptionExpiry != null && 
              _currentUser!.subscriptionExpiry!.isAfter(DateTime.now())) ...[
            const SizedBox(height: 8),
            Text(
              'Expires: ${_formatDate(_currentUser!.subscriptionExpiry!)}',
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUsageIndicator({
    required String label,
    required int current,
    required int max,
    required Color color,
  }) {
    final progress = max > 0 ? current / max : 0.0;

    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: CircularPercentIndicator(
            radius: 18,
            lineWidth: 4,
            percent: progress.clamp(0.0, 1.0),
            center: Text(
              '$current/$max',
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
            progressColor: color,
            backgroundColor: AppColors.white.withOpacity(0.2),
          ),
        ),
      ],
    );
  }

  Widget _buildFreePlanCard() {
    final isCurrentPlan = _currentUser?.subscriptionTier == SubscriptionTier.free;

    return _buildPricingCard(
      tier: SubscriptionTier.free,
      title: 'Free',
      price: null,
      dailyLimit: AppConstants.freeProfileLimit,
      features: const [
        '5 profiles per day',
        'Limited likes',
        'Basic matchmaking',
      ],
      color: AppColors.free,
      gradientColors: const [Color(0xFF757575), Color(0xFF9E9E9E)],
      isCurrentPlan: isCurrentPlan,
      isPopular: false,
      isBestValue: false,
      onSelect: () => _handlePlanSelection(SubscriptionTier.free),
    );
  }

  Widget _buildSilverPlanCard() {
    final isCurrentPlan = _currentUser?.subscriptionTier == SubscriptionTier.silver;

    return _buildPricingCard(
      tier: SubscriptionTier.silver,
      title: 'Silver',
      price: AppConstants.silverPrice,
      dailyLimit: AppConstants.silverProfileLimit,
      features: const [
        '20 profiles per day',
        'Unlimited likes',
        'Advanced matchmaking',
        'Profile boost',
      ],
      color: AppColors.silver,
      gradientColors: const [Color(0xFF90A4AE), Color(0xFFB0BEC5)],
      isCurrentPlan: isCurrentPlan,
      isPopular: true,
      isBestValue: false,
      onSelect: () => _handlePlanSelection(SubscriptionTier.silver),
    );
  }

  Widget _buildGoldPlanCard() {
    final isCurrentPlan = _currentUser?.subscriptionTier == SubscriptionTier.gold;

    return _buildPricingCard(
      tier: SubscriptionTier.gold,
      title: 'Gold',
      price: AppConstants.goldPrice,
      dailyLimit: AppConstants.goldProfileLimit,
      features: const [
        '50 profiles per day',
        'Unlimited likes',
        'Priority matchmaking',
        'Priority visibility',
        'Premium profile boost',
        'Read receipts',
      ],
      color: AppColors.gold,
      gradientColors: const [Color(0xFFFFC107), Color(0xFFFFD700)],
      isCurrentPlan: isCurrentPlan,
      isPopular: false,
      isBestValue: true,
      onSelect: () => _handlePlanSelection(SubscriptionTier.gold),
    );
  }

  Widget _buildPricingCard({
    required SubscriptionTier tier,
    required String title,
    required double? price,
    required int dailyLimit,
    required List<String> features,
    required Color color,
    required List<Color> gradientColors,
    required bool isCurrentPlan,
    required bool isPopular,
    required bool isBestValue,
    required VoidCallback onSelect,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (isPopular)
            Positioned(
              top: -12,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.femalePrimary,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.femalePrimary.withOpacity(0.5),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.whatshot, color: AppColors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'POPULAR',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (isBestValue)
            Positioned(
              top: -12,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withOpacity(0.5),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.workspace_premium, color: AppColors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'BEST VALUE',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      tier == SubscriptionTier.free
                          ? Icons.free_breakfast
                          : tier == SubscriptionTier.silver
                              ? Icons.star
                              : Icons.workspace_premium,
                      color: AppColors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (isCurrentPlan)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'CURRENT',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (price != null) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'PKR ${price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Text(
                          '/month',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const Text(
                    'No cost',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people, color: AppColors.white, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        '$dailyLimit profiles/day',
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ...features.map((feature) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.white.withOpacity(0.3),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: AppColors.white,
                              size: 14,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              feature,
                              style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isProcessing || isCurrentPlan ? null : onSelect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCurrentPlan
                          ? AppColors.white.withOpacity(0.3)
                          : AppColors.white,
                      foregroundColor: isCurrentPlan
                          ? AppColors.white
                          : color,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      disabledBackgroundColor: AppColors.white.withOpacity(0.3),
                      disabledForegroundColor: AppColors.white,
                    ),
                    child: _isProcessing && !isCurrentPlan
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(AppColors.white),
                            ),
                          )
                        : Text(
                            isCurrentPlan ? 'Current Plan' : 'Select Plan',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestorePurchasesButton() {
    return Center(
      child: TextButton.icon(
        onPressed: _restorePurchases,
        icon: const Icon(Icons.restore, color: AppColors.white, size: 18),
        label: const Text(
          'Restore Purchases',
          style: TextStyle(
            color: AppColors.white,
            fontSize: 14,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }

  Widget _buildTermsAndConditions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.white, size: 18),
              SizedBox(width: 8),
              Text(
                'Terms & Conditions',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Subscriptions are billed monthly and auto-renew unless canceled at least 24 hours before the end of the current period. '
            'You can manage your subscription in account settings. '
            'No refunds for unused portions of the subscription. '
            'Prices are in Pakistani Rupees (PKR).',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
