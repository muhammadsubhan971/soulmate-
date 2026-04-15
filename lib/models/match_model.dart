class MatchModel {
  final String id;
  final String userId;
  final String matchedUserId;
  final double compatibilityScore;
  final List<String> matchReasons;
  final bool isLiked;
  final bool isSkipped;
  final bool isMutualMatch;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MatchModel({
    required this.id,
    required this.userId,
    required this.matchedUserId,
    required this.compatibilityScore,
    required this.matchReasons,
    this.isLiked = false,
    this.isSkipped = false,
    this.isMutualMatch = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MatchModel.fromJson(Map<String, dynamic> json) {
    return MatchModel(
      id: json['id'],
      userId: json['user_id'],
      matchedUserId: json['matched_user_id'],
      compatibilityScore: json['compatibility_score']?.toDouble() ?? 0.0,
      matchReasons: json['match_reasons'] != null
          ? List<String>.from(json['match_reasons'])
          : [],
      isLiked: json['is_liked'] ?? false,
      isSkipped: json['is_skipped'] ?? false,
      isMutualMatch: json['is_mutual_match'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'matched_user_id': matchedUserId,
      'compatibility_score': compatibilityScore,
      'match_reasons': matchReasons,
      'is_liked': isLiked,
      'is_skipped': isSkipped,
      'is_mutual_match': isMutualMatch,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  MatchModel copyWith({
    String? id,
    String? userId,
    String? matchedUserId,
    double? compatibilityScore,
    List<String>? matchReasons,
    bool? isLiked,
    bool? isSkipped,
    bool? isMutualMatch,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MatchModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      matchedUserId: matchedUserId ?? this.matchedUserId,
      compatibilityScore: compatibilityScore ?? this.compatibilityScore,
      matchReasons: matchReasons ?? this.matchReasons,
      isLiked: isLiked ?? this.isLiked,
      isSkipped: isSkipped ?? this.isSkipped,
      isMutualMatch: isMutualMatch ?? this.isMutualMatch,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
