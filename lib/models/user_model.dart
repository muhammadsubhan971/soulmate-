enum UserRole {
  user,
  admin,
}

enum Gender {
  male,
  female,
}

enum MaritalStatus {
  single,
  divorced,
  widowed,
  separated,
}

enum SmokingHabit {
  nonSmoker,
  smoker,
  occasionally,
}

enum DrinkingHabit {
  nonDrinker,
  drinker,
  socially,
}

enum SubscriptionTier {
  free,
  silver,
  gold,
}

class UserModel {
  final String id;
  final String email;
  final String? phone;
  final UserRole role;
  final Gender? gender;
  final String? fullName;
  final String? fatherName;
  final String? motherName;
  final int? age;
  final String? profilePictureUrl;
  final String? caste;
  final String? religion;
  final MaritalStatus? maritalStatus;
  final double? height;
  final double? weight;
  final String? qualification;
  final String? profession;
  final String? companyName;
  final double? monthlyIncome;
  final String? address;
  final String? city;
  final String? area;
  final String? country;
  final List<String>? hobbies;
  final List<String>? personalityTraits;
  final String? preferredPartnerCriteria;
  final SmokingHabit? smokingHabit;
  final DrinkingHabit? drinkingHabit;
  final String? familyBackground;
  final SubscriptionTier subscriptionTier;
  final DateTime? subscriptionExpiry;
  final int dailyProfileViews;
  final int dailyLikes;
  final bool isVerified;
  final bool isActive;
  final bool isBlocked;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserModel({
    required this.id,
    required this.email,
    this.phone,
    this.role = UserRole.user,
    this.gender,
    this.fullName,
    this.fatherName,
    this.motherName,
    this.age,
    this.profilePictureUrl,
    this.caste,
    this.religion,
    this.maritalStatus,
    this.height,
    this.weight,
    this.qualification,
    this.profession,
    this.companyName,
    this.monthlyIncome,
    this.address,
    this.city,
    this.area,
    this.country,
    this.hobbies,
    this.personalityTraits,
    this.preferredPartnerCriteria,
    this.smokingHabit,
    this.drinkingHabit,
    this.familyBackground,
    this.subscriptionTier = SubscriptionTier.free,
    this.subscriptionExpiry,
    this.dailyProfileViews = 0,
    this.dailyLikes = 0,
    this.isVerified = false,
    this.isActive = true,
    this.isBlocked = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      email: json['email'],
      phone: json['phone'],
      role: UserRole.values.firstWhere(
        (e) => e.toString() == 'UserRole.${json['role']}',
        orElse: () => UserRole.user,
      ),
      gender: json['gender'] != null
          ? Gender.values.firstWhere(
              (e) => e.toString() == 'Gender.${json['gender']}',
              orElse: () => Gender.male,
            )
          : null,
      fullName: json['full_name'],
      fatherName: json['father_name'],
      motherName: json['mother_name'],
      age: json['age'],
      profilePictureUrl: json['profile_picture_url'],
      caste: json['caste'],
      religion: json['religion'],
      maritalStatus: json['marital_status'] != null
          ? MaritalStatus.values.firstWhere(
              (e) => e.toString() == 'MaritalStatus.${json['marital_status']}',
              orElse: () => MaritalStatus.single,
            )
          : null,
      height: json['height']?.toDouble(),
      weight: json['weight']?.toDouble(),
      qualification: json['qualification'],
      profession: json['profession'],
      companyName: json['company_name'],
      monthlyIncome: json['monthly_income']?.toDouble(),
      address: json['address'],
      city: json['city'],
      area: json['area'],
      country: json['country'],
      hobbies: json['hobbies'] != null ? List<String>.from(json['hobbies']) : null,
      personalityTraits: json['personality_traits'] != null
          ? List<String>.from(json['personality_traits'])
          : null,
      preferredPartnerCriteria: json['preferred_partner_criteria'],
      smokingHabit: json['smoking_habit'] != null
          ? SmokingHabit.values.firstWhere(
              (e) => e.toString() == 'SmokingHabit.${json['smoking_habit']}',
              orElse: () => SmokingHabit.nonSmoker,
            )
          : null,
      drinkingHabit: json['drinking_habit'] != null
          ? DrinkingHabit.values.firstWhere(
              (e) => e.toString() == 'DrinkingHabit.${json['drinking_habit']}',
              orElse: () => DrinkingHabit.nonDrinker,
            )
          : null,
      familyBackground: json['family_background'],
      subscriptionTier: SubscriptionTier.values.firstWhere(
        (e) => e.toString() == 'SubscriptionTier.${json['subscription_tier']}',
        orElse: () => SubscriptionTier.free,
      ),
      subscriptionExpiry: json['subscription_expiry'] != null
          ? DateTime.parse(json['subscription_expiry'])
          : null,
      dailyProfileViews: json['daily_profile_views'] ?? 0,
      dailyLikes: json['daily_likes'] ?? 0,
      isVerified: json['is_verified'] ?? false,
      isActive: json['is_active'] ?? true,
      isBlocked: json['is_blocked'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'phone': phone,
      'role': role.toString().split('.').last,
      'gender': gender?.toString().split('.').last,
      'full_name': fullName,
      'father_name': fatherName,
      'mother_name': motherName,
      'age': age,
      'profile_picture_url': profilePictureUrl,
      'caste': caste,
      'religion': religion,
      'marital_status': maritalStatus?.toString().split('.').last,
      'height': height,
      'weight': weight,
      'qualification': qualification,
      'profession': profession,
      'company_name': companyName,
      'monthly_income': monthlyIncome,
      'address': address,
      'city': city,
      'area': area,
      'country': country,
      'hobbies': hobbies,
      'personality_traits': personalityTraits,
      'preferred_partner_criteria': preferredPartnerCriteria,
      'smoking_habit': smokingHabit?.toString().split('.').last,
      'drinking_habit': drinkingHabit?.toString().split('.').last,
      'family_background': familyBackground,
      'subscription_tier': subscriptionTier.toString().split('.').last,
      'subscription_expiry': subscriptionExpiry?.toIso8601String(),
      'daily_profile_views': dailyProfileViews,
      'daily_likes': dailyLikes,
      'is_verified': isVerified,
      'is_active': isActive,
      'is_blocked': isBlocked,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? phone,
    UserRole? role,
    Gender? gender,
    String? fullName,
    String? fatherName,
    String? motherName,
    int? age,
    String? profilePictureUrl,
    String? caste,
    String? religion,
    MaritalStatus? maritalStatus,
    double? height,
    double? weight,
    String? qualification,
    String? profession,
    String? companyName,
    double? monthlyIncome,
    String? address,
    String? city,
    String? area,
    String? country,
    List<String>? hobbies,
    List<String>? personalityTraits,
    String? preferredPartnerCriteria,
    SmokingHabit? smokingHabit,
    DrinkingHabit? drinkingHabit,
    String? familyBackground,
    SubscriptionTier? subscriptionTier,
    DateTime? subscriptionExpiry,
    int? dailyProfileViews,
    int? dailyLikes,
    bool? isVerified,
    bool? isActive,
    bool? isBlocked,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      gender: gender ?? this.gender,
      fullName: fullName ?? this.fullName,
      fatherName: fatherName ?? this.fatherName,
      motherName: motherName ?? this.motherName,
      age: age ?? this.age,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      caste: caste ?? this.caste,
      religion: religion ?? this.religion,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      qualification: qualification ?? this.qualification,
      profession: profession ?? this.profession,
      companyName: companyName ?? this.companyName,
      monthlyIncome: monthlyIncome ?? this.monthlyIncome,
      address: address ?? this.address,
      city: city ?? this.city,
      area: area ?? this.area,
      country: country ?? this.country,
      hobbies: hobbies ?? this.hobbies,
      personalityTraits: personalityTraits ?? this.personalityTraits,
      preferredPartnerCriteria:
          preferredPartnerCriteria ?? this.preferredPartnerCriteria,
      smokingHabit: smokingHabit ?? this.smokingHabit,
      drinkingHabit: drinkingHabit ?? this.drinkingHabit,
      familyBackground: familyBackground ?? this.familyBackground,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      subscriptionExpiry: subscriptionExpiry ?? this.subscriptionExpiry,
      dailyProfileViews: dailyProfileViews ?? this.dailyProfileViews,
      dailyLikes: dailyLikes ?? this.dailyLikes,
      isVerified: isVerified ?? this.isVerified,
      isActive: isActive ?? this.isActive,
      isBlocked: isBlocked ?? this.isBlocked,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  int get dailyLimit {
    switch (subscriptionTier) {
      case SubscriptionTier.free:
        return 5;
      case SubscriptionTier.silver:
        return 20;
      case SubscriptionTier.gold:
        return 50;
    }
  }

  bool get hasReachedDailyLimit {
    return dailyProfileViews >= dailyLimit;
  }

  bool get isSubscriptionActive {
    return subscriptionTier != SubscriptionTier.free &&
        subscriptionExpiry != null &&
        subscriptionExpiry!.isAfter(DateTime.now());
  }
}
