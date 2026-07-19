import 'package:supabase_flutter/supabase_flutter.dart';

class Doctor {
  const Doctor({
    required this.id,
    required this.displayName,
    required this.specialty,
    this.qualification,
    this.languages = const [],
    this.yearsExperience,
    this.consultFee = 0,
    this.photoUrl,
    this.bio,
    this.rating,
  });

  final String id;
  final String displayName;
  final String specialty;
  final String? qualification;
  final List<String> languages;
  final int? yearsExperience;
  final num consultFee;
  final String? photoUrl;
  final String? bio;
  final num? rating;

  factory Doctor.fromMap(Map<String, dynamic> m) => Doctor(
        id: m['id'] as String,
        displayName: m['display_name'] as String,
        specialty: m['specialty'] as String,
        qualification: m['qualification'] as String?,
        languages: ((m['languages'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        yearsExperience: (m['years_experience'] as num?)?.toInt(),
        consultFee: (m['consult_fee'] as num?) ?? 0,
        photoUrl: m['photo_url'] as String?,
        bio: m['bio'] as String?,
        rating: m['rating'] as num?,
      );
}

class Consultation {
  const Consultation({
    required this.id,
    required this.doctorId,
    required this.mode,
    required this.status,
    required this.scheduledAt,
    this.agoraChannel,
    this.fee = 0,
    this.paymentStatus,
    this.doctorName,
    this.doctorSpecialty,
    this.reason,
  });

  final String id;
  final String doctorId;
  final String mode;
  final String status;
  final DateTime scheduledAt;
  final String? agoraChannel;
  final num fee;
  final String? paymentStatus;
  final String? doctorName;
  final String? doctorSpecialty;
  final String? reason;

  bool get isVideo => mode == 'video';

  factory Consultation.fromMap(Map<String, dynamic> m) {
    final doc = m['doctors'] as Map<String, dynamic>?;
    return Consultation(
      id: m['id'] as String,
      doctorId: m['doctor_id'] as String,
      mode: m['mode'] as String,
      status: m['status'] as String,
      scheduledAt: DateTime.parse(m['scheduled_at'] as String).toLocal(),
      agoraChannel: m['agora_channel'] as String?,
      fee: (m['fee'] as num?) ?? 0,
      paymentStatus: m['payment_status'] as String?,
      reason: m['reason'] as String?,
      doctorName: doc?['display_name'] as String?,
      doctorSpecialty: doc?['specialty'] as String?,
    );
  }
}

class Prescription {
  const Prescription({
    required this.id,
    required this.medicines,
    this.advice,
    this.followUpDate,
    required this.issuedAt,
    this.doctorName,
  });

  final String id;
  final List<Map<String, dynamic>> medicines;
  final String? advice;
  final DateTime? followUpDate;
  final DateTime issuedAt;
  final String? doctorName;

  factory Prescription.fromMap(Map<String, dynamic> m) {
    final doc = m['doctors'] as Map<String, dynamic>?;
    return Prescription(
      id: m['id'] as String,
      medicines: ((m['medicines'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      advice: m['advice'] as String?,
      followUpDate: m['follow_up_date'] != null
          ? DateTime.tryParse(m['follow_up_date'] as String)
          : null,
      issuedAt: DateTime.parse(m['issued_at'] as String).toLocal(),
      doctorName: doc?['display_name'] as String?,
    );
  }
}

class DoctorsRepository {
  DoctorsRepository(this._client);
  final SupabaseClient _client;

  Future<List<Doctor>> list({String? specialty}) async {
    var query = _client.from('doctors').select().eq('active', true);
    if (specialty != null && specialty.isNotEmpty) {
      query = query.eq('specialty', specialty);
    }
    final rows = await query.order('rating', ascending: false);
    return (rows as List)
        .map((r) => Doctor.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<Consultation> book({
    required String elderId,
    required String doctorId,
    required String mode,
    required DateTime scheduledAt,
    String? reason,
  }) async {
    final res = await _client.functions.invoke('doctor-consultation-book', body: {
      'elder_id': elderId,
      'doctor_id': doctorId,
      'mode': mode,
      'scheduled_at': scheduledAt.toUtc().toIso8601String(),
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
    final data = res.data;
    if (data is Map && data['consultation'] is Map) {
      return Consultation.fromMap(
          Map<String, dynamic>.from(data['consultation'] as Map));
    }
    throw Exception(
        (data is Map ? data['error'] : null)?.toString() ?? 'Booking failed');
  }

  Future<List<Consultation>> myConsultations(String elderId) async {
    final rows = await _client
        .from('doctor_consultations')
        .select('*, doctors(display_name, specialty)')
        .eq('elder_id', elderId)
        .order('scheduled_at', ascending: false);
    return (rows as List)
        .map((r) => Consultation.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<List<Prescription>> prescriptions(String elderId) async {
    final rows = await _client
        .from('consultation_prescriptions')
        .select('*, doctors(display_name)')
        .eq('elder_id', elderId)
        .order('issued_at', ascending: false);
    return (rows as List)
        .map((r) => Prescription.fromMap(r as Map<String, dynamic>))
        .toList();
  }
}
