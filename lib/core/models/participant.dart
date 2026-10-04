class Participant {
  final String id;
  final String name;
  final String email;
  final String mobile;
  final String organization;
  final String eventId;
  final String regStatus;
  final bool isCheckedIn;
  final String? checkedInAt;
  final String? checkedInBy;
  final int totalMealsTaken;

  Participant({
    required this.id,
    required this.name,
    required this.email,
    required this.mobile,
    required this.organization,
    required this.eventId,
    required this.regStatus,
    required this.isCheckedIn,
    this.checkedInAt,
    this.checkedInBy,
    required this.totalMealsTaken,
  });

  factory Participant.fromJson(Map<String, dynamic> json) {
    return Participant(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      mobile: json['mobile'] as String,
      organization: json['organization'] as String,
      eventId: json['event_id'] as String,
      regStatus: json['reg_status'] as String,
      isCheckedIn: (json['is_checked_in'] == 1 || json['is_checked_in'] == true),
      checkedInAt: json['checked_in_at'] as String?,
      checkedInBy: json['checked_in_by'] as String?,
      totalMealsTaken: json['total_meals_taken'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'mobile': mobile,
      'organization': organization,
      'event_id': eventId,
      'reg_status': regStatus,
      'is_checked_in': isCheckedIn ? 1 : 0,
      'checked_in_at': checkedInAt,
      'checked_in_by': checkedInBy,
      'total_meals_taken': totalMealsTaken,
    };
  }
}
