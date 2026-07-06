enum BookingStatus {
  requested('requested'),
  matched('matched'),
  confirmed('confirmed'),
  inProgress('in_progress'),
  completed('completed'),
  cancelled('cancelled'),
  disputed('disputed');

  const BookingStatus(this.wireValue);

  final String wireValue;

  static BookingStatus fromWire(String value) {
    return BookingStatus.values.firstWhere((s) => s.wireValue == value);
  }
}

class Booking {
  const Booking({
    required this.id,
    required this.elderId,
    required this.serviceId,
    required this.status,
    required this.scheduledAt,
    this.caregiverId,
  });

  final String id;
  final String elderId;
  final String serviceId;
  final String? caregiverId;
  final BookingStatus status;
  final DateTime scheduledAt;

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'] as String,
      elderId: json['elder_id'] as String,
      serviceId: json['service_id'] as String,
      caregiverId: json['caregiver_id'] as String?,
      status: BookingStatus.fromWire(json['status'] as String),
      scheduledAt: DateTime.parse(json['scheduled_at'] as String),
    );
  }
}
