class Participant {
  final String participantId;
  final String eventId;
  final String name;
  final String email;
  final String mobileNumber;
  final String organization;
  final bool isRegistered;
  final String? registeredAt;
  final String? scannedAt;
  final String? scannedBy;
  final bool dinnerStatus;
  final String? dinnerScannedAt;

  Participant({
    required this.participantId,
    required this.eventId,
    required this.name,
    required this.email,
    required this.mobileNumber,
    required this.organization,
    required this.isRegistered,
    this.registeredAt,
    this.scannedAt,
    this.scannedBy,
    required this.dinnerStatus,
    this.dinnerScannedAt,
  });

  /// Backward compatibility getter
  String get id => participantId;
  String get mobile => mobileNumber;
  bool get isCheckedIn => scannedAt != null;

  factory Participant.fromJson(Map<String, dynamic> json) {
    return Participant(
      participantId: (json['participant_id'] ?? json['id'] ?? '').toString(),
      eventId: (json['event_id'] ?? '').toString(),
      name: (json['name'] ?? 'Unknown Guest').toString(),
      email: (json['email'] ?? '').toString(),
      mobileNumber: (json['mobile_number'] ?? json['mobile'] ?? '').toString(),
      organization: (json['organization'] ?? 'General').toString(),
      isRegistered: json['is_registered'] == true || json['is_registered'] == 1,
      registeredAt: json['registered_at']?.toString(),
      scannedAt: json['scanned_at']?.toString(),
      scannedBy: json['scanned_by']?.toString(),
      dinnerStatus: json['dinner_status'] == true || json['dinner_status'] == 1,
      dinnerScannedAt: json['dinner_scanned_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'participant_id': participantId,
      'event_id': eventId,
      'name': name,
      'email': email,
      'mobile_number': mobileNumber,
      'organization': organization,
      'is_registered': isRegistered ? 1 : 0,
      'registered_at': registeredAt,
      'scanned_at': scannedAt,
      'scanned_by': scannedBy,
      'dinner_status': dinnerStatus ? 1 : 0,
      'dinner_scanned_at': dinnerScannedAt,
    };
  }
}
