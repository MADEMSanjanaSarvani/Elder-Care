import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:setu_core/setu_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers.dart';
import '../../family_access/data/family_access_repository.dart';
import '../../medications/data/medications_repository.dart';
import '../data/health_profile_repository.dart';

/// The Medical ID card: everything a paramedic needs, on one screen, in the
/// order they ask for it.
///
/// This is the read half of the Stitch "Emergency Medical Profile" design.
/// The health profile screen is a form — fields, keyboards, a Save button —
/// which is right for the family filling it in on a Sunday afternoon and
/// completely wrong for the ninety seconds that matter. Nobody scrolls a form
/// while somebody is on the floor. So the same data gets a second, read-only
/// presentation: no inputs, no save, blood group at 56pt, allergies in red at
/// the top, and a call button on every contact.
///
/// ## Why the QR holds the record itself and not a link
///
/// The design labels it "SCAN FOR FULL RECORD", which normally means a URL to
/// a hosted page. That would need a public unauthenticated endpoint serving
/// medical records to anyone holding the token — and it would fail in exactly
/// the situation it was built for, because an ambulance on the Vizag bypass
/// may have no data signal.
///
/// So the QR carries the text itself. Any camera app shows it instantly, with
/// no network, no app, no login, and there is no server-side surface to leak:
/// the data is only ever where the phone already is. The trade is capacity —
/// hence [_maxQrChars] and the ordering below, which puts the fields a
/// paramedic acts on first so that truncation only ever costs the least
/// important line.
class MedicalIdScreen extends ConsumerStatefulWidget {
  const MedicalIdScreen({required this.elderId, super.key});

  final String elderId;

  @override
  ConsumerState<MedicalIdScreen> createState() => _MedicalIdScreenState();
}

/// Comfortably inside a version-40 QR at error-correction M (2,331 bytes),
/// with room for the multi-byte characters an Indian name or hospital address
/// can carry. Above this the code stops being scannable on a phone camera long
/// before it stops being encodable.
const int _maxQrChars = 1200;

class _MedicalIdScreenState extends ConsumerState<MedicalIdScreen> {
  bool _loaded = false;
  String _name = '';
  int? _age;
  String? _gender;
  String? _bloodType;
  List<String> _allergies = const [];
  List<String> _conditions = const [];
  String? _notes;
  String? _hospital;
  List<Map<String, dynamic>> _medications = const [];
  List<Map<String, dynamic>> _contacts = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final client = ref.read(supabaseClientProvider);
    final repo = HealthProfileRepository(client);
    final health = await repo.fetchHealthProfile(widget.elderId);
    final elder =
        await ref.read(elderProfileByIdProvider(widget.elderId).future);
    final meds =
        await MedicationsRepository(client).fetchMedications(widget.elderId);
    final family =
        await FamilyAccessRepository(client).fetchFamily(widget.elderId);
    if (!mounted) return;

    final dobRaw = elder?['dob'] as String?;
    final dob = dobRaw == null ? null : DateTime.tryParse(dobRaw);

    setState(() {
      _name = elder?['display_name'] as String? ?? '';
      _age = dob == null ? null : _yearsSince(dob);
      _gender = elder?['gender'] as String?;
      _bloodType = health?['blood_type'] as String?;
      _allergies = ((health?['allergies'] as List?)?.cast<String>() ?? [])
          .where((a) => a.trim().isNotEmpty)
          .toList();
      _conditions =
          ((health?['chronic_conditions'] as List?)?.cast<String>() ?? [])
              .where((c) => c.trim().isNotEmpty)
              .toList();
      _notes = health?['emergency_medical_notes'] as String?;
      _hospital = health?['preferred_hospital_note'] as String?;
      _medications = meds;
      _contacts = family.where((r) => r['status'] == 'active').toList();
      _loaded = true;
    });
  }

  static int _yearsSince(DateTime dob) {
    final now = DateTime.now();
    var years = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      years--;
    }
    return years;
  }

  /// The card as plain text, ordered the way a paramedic works: who, blood,
  /// what will kill them, what they have, what they are on, who to call.
  ///
  /// Deliberately not JSON. The reader is a human holding a phone camera, not
  /// a parser, and a wall of braces at the roadside is worse than useless.
  String _qrPayload() {
    final lines = <String>['SETU MEDICAL ID'];

    final who = [
      if (_name.trim().isNotEmpty) _name.trim(),
      if (_age != null) '$_age yrs',
      if (_gender != null && _gender!.isNotEmpty) _gender!,
    ].join(', ');
    if (who.isNotEmpty) lines.add(who);

    if (_bloodType != null && _bloodType!.trim().isNotEmpty) {
      lines.add('BLOOD: ${_bloodType!.trim()}');
    }
    lines.add(_allergies.isEmpty
        ? 'ALLERGIES: none recorded'
        : 'ALLERGIES: ${_allergies.join(', ')}');
    if (_conditions.isNotEmpty) {
      lines.add('CONDITIONS: ${_conditions.join(', ')}');
    }
    if (_medications.isNotEmpty) {
      final meds = _medications
          .take(6)
          .map((m) => '${m['name']} ${m['dosage'] ?? ''}'.trim())
          .join('; ');
      lines.add('MEDS: $meds');
    }
    for (final c in _contacts.take(3)) {
      final phone = c['phone'] as String?;
      if (phone == null || phone.trim().isEmpty) continue;
      final name = c['display_name'] as String? ?? 'Family';
      final rel = c['relationship'] as String?;
      lines.add('CONTACT: $name${rel == null ? '' : ' ($rel)'} $phone');
    }
    if (_hospital != null && _hospital!.trim().isNotEmpty) {
      lines.add('HOSPITAL: ${_hospital!.trim()}');
    }
    if (_notes != null && _notes!.trim().isNotEmpty) {
      lines.add('NOTES: ${_notes!.trim()}');
    }

    final text = lines.join('\n');
    return text.length <= _maxQrChars
        ? text
        : '${text.substring(0, _maxQrChars - 1)}…';
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('Medical ID')),
        body: const SetuLoading(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical ID'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit health profile',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(SetuSpacing.lg),
        children: [
          _Identity(name: _name, age: _age, gender: _gender),
          const SizedBox(height: SetuSpacing.lg),

          // Blood group and the QR, side by side, as in the design.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _BloodGroupCard(bloodType: _bloodType)),
                const SizedBox(width: SetuSpacing.md),
                Expanded(child: _QrCard(payload: _qrPayload())),
              ],
            ),
          ),
          const SizedBox(height: SetuSpacing.lg),

          // Allergies are the loudest thing on the screen, or the screen says
          // out loud that none are recorded. A blank space where the allergy
          // section should be reads as "no allergies" to someone about to give
          // an antibiotic, and that inference is the dangerous one.
          _AllergyCard(allergies: _allergies),
          const SizedBox(height: SetuSpacing.lg),

          _SectionBox(
            title: 'Chronic conditions',
            icon: Icons.assignment_outlined,
            accent: SetuColors.lavenderLight,
            child: _conditions.isEmpty
                ? const _EmptyLine('None recorded.')
                : Column(
                    children: [
                      for (final c in _conditions) _BulletItem(text: c),
                    ],
                  ),
          ),
          const SizedBox(height: SetuSpacing.md),

          _SectionBox(
            title: 'Active medications',
            icon: Icons.medication_outlined,
            accent: SetuColors.peachLight,
            child: _medications.isEmpty
                ? const _EmptyLine('None recorded.')
                : Column(
                    children: [
                      for (final m in _medications)
                        _MedicationItem(
                          name: m['name'] as String? ?? '',
                          dose: _doseLine(m),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: SetuSpacing.xl),

          const Text('Emergency contacts',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: SetuSpacing.md),
          if (_contacts.isEmpty)
            const _EmptyLine('No family linked yet.')
          else
            for (final c in _contacts)
              Padding(
                padding: const EdgeInsets.only(bottom: SetuSpacing.sm),
                child: _ContactTile(row: c),
              ),

          if (_hospital != null && _hospital!.trim().isNotEmpty) ...[
            const SizedBox(height: SetuSpacing.lg),
            _SectionBox(
              title: 'Preferred hospital',
              icon: Icons.local_hospital_outlined,
              accent: SetuColors.accentLight,
              child: Text(_hospital!.trim(),
                  style: const TextStyle(fontSize: 17, height: 1.4)),
            ),
          ],

          if (_notes != null && _notes!.trim().isNotEmpty) ...[
            const SizedBox(height: SetuSpacing.md),
            _SectionBox(
              title: 'Notes for responders',
              icon: Icons.sticky_note_2_outlined,
              accent: SetuColors.mutedLight,
              child: Text(_notes!.trim(),
                  style: const TextStyle(fontSize: 17, height: 1.4)),
            ),
          ],
          const SizedBox(height: SetuSpacing.xl),
        ],
      ),
    );
  }

  /// "5mg • 08:00, 20:00" — dosage plus the schedule the family entered, with
  /// whichever half exists. A medication row with a blank right-hand side is
  /// still worth showing: the name alone tells a doctor more than nothing.
  static String _doseLine(Map<String, dynamic> m) {
    final dosage = (m['dosage'] as String?)?.trim() ?? '';
    final schedule = m['schedule'];
    final times = schedule is Map ? (schedule['times'] as List?) : null;
    final timeText =
        times == null || times.isEmpty ? '' : times.cast<String>().join(', ');
    if (dosage.isEmpty) return timeText;
    if (timeText.isEmpty) return dosage;
    return '$dosage • $timeText';
  }
}

class _Identity extends StatelessWidget {
  const _Identity({required this.name, this.age, this.gender});

  final String name;
  final int? age;
  final String? gender;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (age != null) '$age years',
      if (gender != null && gender!.isNotEmpty) gender!,
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name.isEmpty ? 'Medical ID' : name,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
        if (subtitle.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(subtitle,
                style: const TextStyle(
                    fontSize: 16, color: SetuColors.mutedLight)),
          ),
      ],
    );
  }
}

class _BloodGroupCard extends StatelessWidget {
  const _BloodGroupCard({this.bloodType});

  final String? bloodType;

  @override
  Widget build(BuildContext context) {
    final value = bloodType?.trim() ?? '';
    final known = value.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(SetuSpacing.lg),
      decoration: BoxDecoration(
        color: SetuColors.accentLight,
        borderRadius: BorderRadius.circular(20),
        boxShadow: SetuSurfaces.of(context).cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('BLOOD GROUP',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              )),
          const SizedBox(height: SetuSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    known ? value : '—',
                    style: TextStyle(
                      color: known ? Colors.white : Colors.white70,
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
              ),
              const Icon(Icons.water_drop, color: Colors.white70, size: 26),
            ],
          ),
          if (!known)
            const Padding(
              padding: EdgeInsets.only(top: SetuSpacing.xs),
              child: Text('Not recorded',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

class _QrCard extends StatelessWidget {
  const _QrCard({required this.payload});

  final String payload;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => _QrDialog(payload: payload),
      ),
      child: Container(
        padding: const EdgeInsets.all(SetuSpacing.md),
        decoration: BoxDecoration(
          color: SetuColors.paperRaisedLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: SetuColors.borderLight),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: _Qr(payload: payload, size: 84),
            ),
            const SizedBox(height: SetuSpacing.sm),
            const Text('TAP TO ENLARGE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                  color: SetuColors.mutedLight,
                )),
          ],
        ),
      ),
    );
  }
}

/// Full-screen scan target. A phone camera needs both size and contrast to
/// lock on, and the small card version exists to be recognised, not read.
class _QrDialog extends StatelessWidget {
  const _QrDialog({required this.payload});

  final String payload;

  @override
  Widget build(BuildContext context) {
    // clamp() is declared on num, so it needs converting back before it can
    // be a width.
    final side = (MediaQuery.of(context).size.width - 96).clamp(200, 320).toDouble();
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(SetuSpacing.lg),
      child: Padding(
        padding: const EdgeInsets.all(SetuSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Qr(payload: payload, size: side),
            const SizedBox(height: SetuSpacing.md),
            const Text(
              'Scan with any camera. The details are inside the code itself, '
              'so it works with no internet.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: SetuColors.mutedLight),
            ),
            const SizedBox(height: SetuSpacing.sm),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Qr extends StatelessWidget {
  const _Qr({required this.payload, required this.size});

  final String payload;
  final double size;

  @override
  Widget build(BuildContext context) {
    return QrImageView(
      data: payload,
      version: QrVersions.auto,
      size: size,
      backgroundColor: Colors.white,
      // M survives a scuffed printout and a fingerprint on the glass; L does
      // not, and this is the one image in the app that has to scan first time.
      errorCorrectionLevel: QrErrorCorrectLevel.M,
      padding: EdgeInsets.zero,
      errorStateBuilder: (context, _) => SizedBox(
        width: size,
        height: size,
        child: const Center(
          child: Text('Too much to encode',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: SetuColors.mutedLight)),
        ),
      ),
    );
  }
}

class _AllergyCard extends StatelessWidget {
  const _AllergyCard({required this.allergies});

  final List<String> allergies;

  @override
  Widget build(BuildContext context) {
    final none = allergies.isEmpty;
    final colour = none ? SetuColors.mutedLight : SetuColors.sosLight;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SetuSpacing.lg),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: none ? 0.06 : 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colour.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
            child: Icon(none ? Icons.check : Icons.warning_amber_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: SetuSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(none ? 'No allergies recorded' : 'Allergies',
                    style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: colour)),
                const SizedBox(height: 4),
                Text(
                  none
                      // Said out loud, because "we were never told" and "there
                      // are none" are different facts and only one of them is
                      // safe to act on.
                      ? 'Nothing has been entered. That is not the same as none — '
                          'ask, if you can.'
                      : allergies.join(', '),
                  style: TextStyle(
                    fontSize: none ? 14 : 20,
                    height: 1.35,
                    fontWeight: none ? FontWeight.w400 : FontWeight.w800,
                    color: none
                        ? SetuColors.mutedLight
                        : SetuColors.sosLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionBox extends StatelessWidget {
  const _SectionBox({
    required this.title,
    required this.icon,
    required this.accent,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SetuSpacing.lg),
      decoration: BoxDecoration(
        color: SetuColors.paperRaisedLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SetuColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 22),
              const SizedBox(width: SetuSpacing.sm),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 16)),
            ],
          ),
          const SizedBox(height: SetuSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _BulletItem extends StatelessWidget {
  const _BulletItem({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SetuSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 7),
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
                color: SetuColors.lavenderLight, shape: BoxShape.circle),
          ),
          const SizedBox(width: SetuSpacing.sm),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 17)),
          ),
        ],
      ),
    );
  }
}

class _MedicationItem extends StatelessWidget {
  const _MedicationItem({required this.name, required this.dose});

  final String name;
  final String dose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SetuSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name,
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          if (dose.isNotEmpty)
            Text(dose,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: SetuColors.mutedLight,
                )),
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final name = row['display_name'] as String? ?? 'Family member';
    final phone = row['phone'] as String?;
    final relationship = row['relationship'] as String?;
    final coordinator = row['coordinator'] == true;
    final role = [
      if (relationship != null && relationship.isNotEmpty) relationship,
      if (coordinator) 'Primary',
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(SetuSpacing.md),
      decoration: BoxDecoration(
        color: SetuColors.paperRaisedLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SetuColors.borderLight),
        boxShadow: SetuSurfaces.of(context).cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: SetuColors.lavenderLight.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Text(
              name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(),
              style: const TextStyle(
                  color: SetuColors.lavenderLight,
                  fontWeight: FontWeight.w900,
                  fontSize: 20),
            ),
          ),
          const SizedBox(width: SetuSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 17)),
                if (role.isNotEmpty)
                  Text(role,
                      style: const TextStyle(
                          color: SetuColors.mutedLight, fontSize: 14)),
              ],
            ),
          ),
          if (phone != null && phone.trim().isNotEmpty)
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                  color: SetuColors.verifiedLight, shape: BoxShape.circle),
              child: IconButton(
                tooltip: 'Call $name',
                icon: const Icon(Icons.call, color: Colors.white),
                onPressed: () => launchUrl(Uri.parse('tel:${phone.trim()}')),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            color: SetuColors.mutedLight, fontStyle: FontStyle.italic));
  }
}
