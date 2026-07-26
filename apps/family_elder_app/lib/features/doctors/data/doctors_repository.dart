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
    this.clinicName,
    this.address,
    this.phone,
    this.lat,
    this.lng,
    this.consultDays = const [],
    this.consultStart,
    this.consultEnd,
    this.escortAvailable = true,
    this.registrationNo,
    this.registrationVerifiedAt,
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

  /// Where this doctor actually sits, and when.
  final String? clinicName;
  final String? address;
  final String? phone;
  final double? lat;
  final double? lng;

  /// ISO weekdays (1 = Monday ... 7 = Sunday). Empty means the hours aren't
  /// known — shown as "call to confirm", never as closed.
  final List<int> consultDays;
  final String? consultStart;
  final String? consultEnd;

  /// Whether a SETU caregiver can accompany the elder to this clinic.
  final bool escortAvailable;

  final String? registrationNo;
  final DateTime? registrationVerifiedAt;

  /// True only once a human has checked the number against the NMC register.
  /// Keyed off the timestamp, never off the number being present — an
  /// unverified registration must not render as verified.
  bool get registrationVerified => registrationVerifiedAt != null;

  bool get hasHours =>
      consultDays.isNotEmpty && consultStart != null && consultEnd != null;

  /// Whether the doctor sits at this clinic today.
  bool get consultsToday =>
      hasHours && consultDays.contains(DateTime.now().weekday);

  /// "Mon, Wed, Fri · 10:00-13:00", or null when the hours aren't known.
  String? get hoursLabel {
    if (!hasHours) return null;
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final days = ([...consultDays]..sort())
        .where((d) => d >= 1 && d <= 7)
        .map((d) => names[d - 1])
        .join(', ');
    return '$days · ${_hhmm(consultStart!)}-${_hhmm(consultEnd!)}';
  }

  /// Postgres returns time as "10:00:00"; families don't need the seconds.
  static String _hhmm(String t) =>
      t.length >= 5 ? t.substring(0, 5) : t;

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
        clinicName: m['clinic_name'] as String?,
        address: m['address'] as String?,
        phone: m['phone'] as String?,
        lat: (m['lat'] as num?)?.toDouble(),
        lng: (m['lng'] as num?)?.toDouble(),
        consultDays: ((m['consult_days'] as List?) ?? const [])
            .map((e) => (e as num).toInt())
            .toList(),
        consultStart: m['consult_start'] as String?,
        consultEnd: m['consult_end'] as String?,
        escortAvailable: (m['escort_available'] as bool?) ?? true,
        registrationNo: m['registration_no'] as String?,
        registrationVerifiedAt: m['registration_verified_at'] == null
            ? null
            : DateTime.tryParse(m['registration_verified_at'] as String),
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

  /// The directory for one city.
  ///
  /// Two filters are not optional. `region_id` keeps a family in Vizag from
  /// being shown a clinic in Hyderabad they could never reach, and
  /// `consent_status` keeps out any practitioner who has not agreed to be
  /// listed — a doctor who never said yes must never appear, so it is
  /// enforced here rather than left to whoever writes the next screen.
  Future<List<Doctor>> list({String? specialty, String? regionId}) async {
    var query = _client
        .from('doctors')
        .select()
        .eq('active', true)
        .eq('consent_status', 'consented');
    if (regionId != null && regionId.isNotEmpty) {
      query = query.eq('region_id', regionId);
    }
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

  /// Fetches an Agora RTC token for a video consult's room. Returns the
  /// app id, channel, uid and a (possibly null, for testing-mode) token.
  Future<Map<String, dynamic>> videoToken(String consultationId) async {
    final res = await _client.functions.invoke('agora-rtc-token', body: {
      'consultation_id': consultationId,
    });
    final data = res.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw Exception('Could not get a video token');
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
