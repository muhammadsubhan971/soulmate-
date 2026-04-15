class ReportModel {
  final String id;
  final String reporterId;
  final String reportedUserId;
  final ReportReason reason;
  final String? description;
  final ReportStatus status;
  final String? adminNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ReportModel({
    required this.id,
    required this.reporterId,
    required this.reportedUserId,
    required this.reason,
    this.description,
    this.status = ReportStatus.pending,
    this.adminNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      id: json['id'],
      reporterId: json['reporter_id'],
      reportedUserId: json['reported_user_id'],
      reason: ReportReason.values.firstWhere(
        (e) => e.toString() == 'ReportReason.${json['reason']}',
        orElse: () => ReportReason.inappropriate,
      ),
      description: json['description'],
      status: ReportStatus.values.firstWhere(
        (e) => e.toString() == 'ReportStatus.${json['status']}',
        orElse: () => ReportStatus.pending,
      ),
      adminNotes: json['admin_notes'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reporter_id': reporterId,
      'reported_user_id': reportedUserId,
      'reason': reason.toString().split('.').last,
      'description': description,
      'status': status.toString().split('.').last,
      'admin_notes': adminNotes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

enum ReportReason {
  fake,
  inappropriate,
  spam,
  harassment,
  other,
}

enum ReportStatus {
  pending,
  underReview,
  resolved,
  dismissed,
}
