class EventStats {
  final int totalParticipants;
  final int totalCheckedIn;
  final int mealsServed;

  EventStats({
    required this.totalParticipants,
    required this.totalCheckedIn,
    required this.mealsServed,
  });

  factory EventStats.zero() {
    return EventStats(totalParticipants: 0, totalCheckedIn: 0, mealsServed: 0);
  }
}
