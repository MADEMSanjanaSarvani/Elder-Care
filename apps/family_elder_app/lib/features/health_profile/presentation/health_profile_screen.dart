import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:setu_core/setu_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers.dart';
import '../../../core/region_picker.dart';
import '../../family_access/data/family_access_repository.dart';
import '../../medications/data/medications_repository.dart';
import '../data/health_profile_repository.dart';
import 'elder_avatar.dart';

/// Health Records Management (PRD Part 6, Batch 3, Module 12), matching the
/// Stitch "emergency_medical_profile" design (both frames): a Medical ID
/// banner, bento-style blood group / allergy tiles, live condition pills,
/// and two real-data preview sections (current medications, care-circle
/// contacts) that deep-link to their full screens. The underlying
/// two-table split (emergency-relevant vs. administrative) and its
/// save/load logic are unchanged — a viewer who can't read the
/// administrative half (e.g. a caregiver mid-visit) simply gets nothing
/// back from that table; RLS decides, the UI just renders what came back.
///
/// Preferred hospital is now a real field (migration 0037) — it was omitted
/// while SETU had nowhere to put one, since inventing a hospital on an
/// emergency screen is worse than leaving it blank. The map from the mock is
/// still omitted: SETU geocodes clinics but has no map widget, and a picture
/// of a map that cannot be navigated helps nobody in an emergency. Emergency
/// contacts use the real family_links data (name, relationship, and a
/// working call button when a phone number is on file) instead of the
/// mock's fabricated names/numbers.
class HealthProfileScreen extends ConsumerStatefulWidget {
  const HealthProfileScreen({required this.elderId, super.key});

  final String elderId;

  @override
  ConsumerState<HealthProfileScreen> createState() => _HealthProfileScreenState();
}

class _HealthProfileScreenState extends ConsumerState<HealthProfileScreen> {
  final _bloodTypeController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _conditionsController = TextEditingController();
  final _emergencyNotesController = TextEditingController();
  final _hospitalController = TextEditingController();
  final _physicianNameController = TextEditingController();
  final _physicianContactController = TextEditingController();
  final _insuranceProviderController = TextEditingController();
  final _insurancePolicyController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  bool _loaded = false;
  bool _adminVisible = false;
  bool _saving = false;
  String? _gender;
  DateTime? _dob;
  String _displayName = '';

  HealthProfileRepository get _repo =>
      HealthProfileRepository(ref.read(supabaseClientProvider));

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final health = await _repo.fetchHealthProfile(widget.elderId);
    final admin = await _repo.fetchAdministrativeProfile(widget.elderId);
    // Gender and date of birth live on the identity record, not the health
    // profile — read them here so the whole picture is on one screen.
    final elder = await ref.read(elderProfileByIdProvider(widget.elderId).future);
    if (!mounted) return;
    setState(() {
      _displayName = elder?['display_name'] as String? ?? '';
      _gender = elder?['gender'] as String?;
      final dobRaw = elder?['dob'] as String?;
      _dob = dobRaw == null ? null : DateTime.tryParse(dobRaw);
      final h = health?['height_cm'];
      final w = health?['weight_kg'];
      _heightController.text = h == null ? '' : (h as num).toString();
      _weightController.text = w == null ? '' : (w as num).toString();
      _bloodTypeController.text = health?['blood_type'] as String? ?? '';
      _allergiesController.text =
          ((health?['allergies'] as List?)?.cast<String>() ?? []).join(', ');
      _conditionsController.text =
          ((health?['chronic_conditions'] as List?)?.cast<String>() ?? []).join(', ');
      _emergencyNotesController.text =
          health?['emergency_medical_notes'] as String? ?? '';
      _hospitalController.text =
          health?['preferred_hospital_note'] as String? ?? '';
      _adminVisible = admin != null;
      _physicianNameController.text = admin?['primary_physician_name'] as String? ?? '';
      _physicianContactController.text =
          admin?['primary_physician_contact'] as String? ?? '';
      _insuranceProviderController.text = admin?['insurance_provider'] as String? ?? '';
      _insurancePolicyController.text =
          admin?['insurance_policy_number'] as String? ?? '';
      _loaded = true;
    });
  }

  List<String> _splitList(String raw) =>
      raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  Future<void> _save() async {
    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) return;
    setState(() => _saving = true);
    try {
      await _repo.saveHealthProfile(
        elderId: widget.elderId,
        updatedBy: userId,
        bloodType: _bloodTypeController.text.trim().isEmpty
            ? null
            : _bloodTypeController.text.trim(),
        allergies: _splitList(_allergiesController.text),
        chronicConditions: _splitList(_conditionsController.text),
        emergencyMedicalNotes: _emergencyNotesController.text.trim().isEmpty
            ? null
            : _emergencyNotesController.text.trim(),
        heightCm: double.tryParse(_heightController.text.trim()),
        weightKg: double.tryParse(_weightController.text.trim()),
        preferredHospitalNote: _hospitalController.text.trim().isEmpty
            ? null
            : _hospitalController.text.trim(),
      );
      await _repo.saveGender(widget.elderId, _gender);
      // The dashboard header and any screen showing age read the elder row,
      // so refresh it rather than leaving stale values behind the save.
      ref.invalidate(elderProfileByIdProvider(widget.elderId));
      await _repo.saveAdministrativeProfile(
        elderId: widget.elderId,
        updatedBy: userId,
        physicianName: _physicianNameController.text.trim().isEmpty
            ? null
            : _physicianNameController.text.trim(),
        physicianContact: _physicianContactController.text.trim().isEmpty
            ? null
            : _physicianContactController.text.trim(),
        insuranceProvider: _insuranceProviderController.text.trim().isEmpty
            ? null
            : _insuranceProviderController.text.trim(),
        insurancePolicyNumber: _insurancePolicyController.text.trim().isEmpty
            ? null
            : _insurancePolicyController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Health profile saved')));
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save: $err')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('Health profile')),
        body: const SetuLoading(),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Health profile')),
      body: ListView(
        padding: const EdgeInsets.all(SetuSpacing.lg),
        children: [
          // Emergency-disclosure banner (Stitch "Medical ID"): makes it clear
          // this data is auto-shared the moment an SOS fires.
          Container(
            padding: const EdgeInsets.all(SetuSpacing.md),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  SetuColors.sosLight.withValues(alpha: 0.12),
                  SetuColors.paperLight,
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border:
                  Border.all(color: SetuColors.sosLight.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: SetuColors.sosLight.withValues(alpha: 0.14),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.emergency_outlined,
                      color: SetuColors.sosLight, size: 22),
                ),
                const SizedBox(width: SetuSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Emergency Disclosure',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: SetuColors.sosLight)),
                      const SizedBox(height: 2),
                      const Text(
                          'This profile is automatically shared during SOS activation.',
                          style: TextStyle(
                              color: SetuColors.mutedLight, fontSize: 13)),
                    ],
                  ),
                ),
                // The badge is now the way in to the card itself. This screen
                // is a form — fields, keyboard, Save — which is right for
                // filling it in and wrong for the ninety seconds it exists
                // for. Nobody scrolls a form while somebody is on the floor.
                FilledButton(
                  onPressed: () =>
                      context.push('/elder/${widget.elderId}/medical-id'),
                  style: FilledButton.styleFrom(
                    backgroundColor: SetuColors.sosLight,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('MEDICAL ID',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5)),
                ),
              ],
            ),
          ),
          const SizedBox(height: SetuSpacing.lg),

          // Who they are: age, gender, height, weight. Age is derived from the
          // date of birth rather than stored, so it can never drift out of
          // date, and BMI is computed on read for the same reason.
          _AboutSection(
            elderId: widget.elderId,
            displayName: _displayName,
            dob: _dob,
            gender: _gender,
            heightController: _heightController,
            weightController: _weightController,
            onGender: (g) => setState(() => _gender = g),
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: SetuSpacing.lg),

          // Blood group + allergies bento row.
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _BentoField(
                  label: 'BLOOD GROUP',
                  color: SetuColors.accentLight,
                  child: TextField(
                    controller: _bloodTypeController,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'e.g. O+',
                      hintStyle: TextStyle(color: Colors.white70),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: SetuSpacing.sm),
              Expanded(
                flex: 2,
                child: _BentoField(
                  label: 'ALLERGIES',
                  color: SetuColors.sosLight,
                  child: TextField(
                    controller: _allergiesController,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'e.g. Penicillin',
                      hintStyle: TextStyle(color: Colors.white70),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: SetuSpacing.md),

          // Chronic conditions, with a live pill preview of what will be saved.
          const Text('Chronic conditions',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: SetuSpacing.sm),
          TextField(
            controller: _conditionsController,
            decoration: const InputDecoration(
                labelText: 'Comma-separated, e.g. Hypertension, Diabetes'),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _conditionsController,
            builder: (context, value, _) {
              final conditions = _splitList(value.text);
              if (conditions.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: SetuSpacing.sm),
                child: Wrap(
                  spacing: SetuSpacing.sm,
                  runSpacing: SetuSpacing.sm,
                  children: [
                    for (final c in conditions)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: SetuColors.lavenderLight.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(c,
                            style: const TextStyle(
                                color: SetuColors.lavenderLight,
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: SetuSpacing.md),
          TextField(
            controller: _emergencyNotesController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Emergency medical notes'),
          ),
          const SizedBox(height: SetuSpacing.md),
          // "Which hospital" is the second question a paramedic asks, right
          // after "what happened". It was left out of this screen originally
          // because SETU had nowhere to put it and inventing a hospital would
          // have been worse than omitting one — that stopped being true when
          // the clinic directory landed.
          TextField(
            controller: _hospitalController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Preferred hospital',
              hintText: 'e.g. KIMS Icon, Sheela Nagar',
              helperText: 'Where they are registered, or would want to be taken',
              prefixIcon: Icon(Icons.local_hospital_outlined),
            ),
          ),
          const SizedBox(height: SetuSpacing.lg),

          // Current medications (real data, read-only preview).
          _PreviewCard(
            icon: Icons.medication_outlined,
            iconColor: SetuColors.peachLight,
            title: 'Current Medications',
            manageLabel: 'Manage',
            onManage: () => context.push('/elder/${widget.elderId}/medications'),
            child: _MedicationsPreview(elderId: widget.elderId),
          ),
          const SizedBox(height: SetuSpacing.md),

          // Emergency contacts (real family_links data).
          _PreviewCard(
            icon: Icons.contacts_outlined,
            iconColor: SetuColors.lavenderLight,
            title: 'Emergency Contacts',
            manageLabel: 'Manage',
            onManage: () => context.push('/elder/${widget.elderId}/family'),
            child: _EmergencyContactsPreview(elderId: widget.elderId),
          ),
          const SizedBox(height: SetuSpacing.xl),

          Text('Administrative information',
              style: Theme.of(context).textTheme.titleMedium),
          const Padding(
            padding: EdgeInsets.only(top: SetuSpacing.xs, bottom: SetuSpacing.sm),
            child: Text('Never visible to caregivers.'),
          ),
          if (!_adminVisible &&
              _physicianNameController.text.isEmpty &&
              _insuranceProviderController.text.isEmpty)
            const SizedBox.shrink(),
          Container(
            padding: const EdgeInsets.all(SetuSpacing.md),
            decoration: BoxDecoration(
              color: SetuColors.paperRaisedLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: SetuColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Physician', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: SetuSpacing.sm),
                TextField(
                  controller: _physicianNameController,
                  decoration: const InputDecoration(labelText: 'Primary physician'),
                ),
                const SizedBox(height: SetuSpacing.sm),
                TextField(
                  controller: _physicianContactController,
                  decoration: const InputDecoration(labelText: 'Physician contact'),
                ),
              ],
            ),
          ),
          const SizedBox(height: SetuSpacing.md),
          Container(
            padding: const EdgeInsets.all(SetuSpacing.md),
            decoration: BoxDecoration(
              color: SetuColors.peachLight.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Insurance', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: SetuSpacing.sm),
                TextField(
                  controller: _insuranceProviderController,
                  decoration: const InputDecoration(labelText: 'Insurance provider'),
                ),
                const SizedBox(height: SetuSpacing.sm),
                TextField(
                  controller: _insurancePolicyController,
                  decoration: const InputDecoration(labelText: 'Insurance policy number'),
                ),
              ],
            ),
          ),
          const SizedBox(height: SetuSpacing.xl),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save'),
          ),
          const SizedBox(height: SetuSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.verified_user_outlined,
                  size: 16, color: SetuColors.verifiedLight),
              const SizedBox(width: 6),
              Text('SECURED MEDICAL DATA',
                  style: TextStyle(
                      color: SetuColors.mutedLight,
                      fontSize: 11.5,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: SetuSpacing.md),
        ],
      ),
    );
  }
}

/// A colour-filled bento tile wrapping an editable field — matches the
/// Stitch design's solid "Blood Group" / "Allergies" tiles while keeping
/// the fields fully editable (this screen is a form, not a read-only ID
/// card).
class _BentoField extends StatelessWidget {
  const _BentoField({required this.label, required this.color, required this.child});
  final String label;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SetuSpacing.md),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6)),
          const SizedBox(height: SetuSpacing.xs),
          child,
        ],
      ),
    );
  }
}

/// A bordered card with an icon/title header and a "Manage" link into the
/// real full screen — the shared shell behind the medications and
/// emergency-contacts previews below.
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.manageLabel,
    required this.onManage,
    required this.child,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String manageLabel;
  final VoidCallback onManage;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SetuSpacing.md),
      decoration: BoxDecoration(
        color: SetuColors.paperRaisedLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SetuColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SetuIconChip(icon: icon, color: iconColor, size: 16),
              const SizedBox(width: SetuSpacing.sm),
              Expanded(
                child: Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              TextButton(onPressed: onManage, child: Text(manageLabel)),
            ],
          ),
          const SizedBox(height: SetuSpacing.xs),
          child,
        ],
      ),
    );
  }
}

/// Read-only preview of the elder's active medications (real data via
/// MedicationsRepository — the same repository the full Medications screen
/// uses).
class _MedicationsPreview extends ConsumerWidget {
  const _MedicationsPreview({required this.elderId});
  final String elderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: MedicationsRepository(ref.read(supabaseClientProvider))
          .fetchMedications(elderId),
      builder: (context, snapshot) {
        final meds = snapshot.data;
        if (meds == null) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: SetuSpacing.sm),
            child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (meds.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(top: SetuSpacing.sm),
            child: Text('No active medications on file.',
                style: TextStyle(
                    color: SetuColors.mutedLight, fontStyle: FontStyle.italic)),
          );
        }
        return Column(
          children: [
            for (final m in meds.take(4))
              Padding(
                padding: const EdgeInsets.only(top: SetuSpacing.sm),
                child: Row(
                  children: [
                    const Icon(Icons.circle,
                        size: 6, color: SetuColors.peachLight),
                    const SizedBox(width: SetuSpacing.sm),
                    Expanded(
                      child: Text(
                          '${m['name']} — ${m['dosage']}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Read-only preview of the elder's care-circle family members (real data
/// via FamilyAccessRepository), with a working call button when a phone
/// number is on file — no fabricated names or numbers.
class _EmergencyContactsPreview extends ConsumerWidget {
  const _EmergencyContactsPreview({required this.elderId});
  final String elderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: FamilyAccessRepository(ref.read(supabaseClientProvider))
          .fetchFamily(elderId),
      builder: (context, snapshot) {
        final rows = snapshot.data;
        if (rows == null) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: SetuSpacing.sm),
            child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final active = rows.where((r) => r['status'] == 'active').toList();
        if (active.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(top: SetuSpacing.sm),
            child: Text('No family linked yet.',
                style: TextStyle(
                    color: SetuColors.mutedLight, fontStyle: FontStyle.italic)),
          );
        }
        return Column(
          children: [
            for (final r in active.take(3))
              Padding(
                padding: const EdgeInsets.only(top: SetuSpacing.sm),
                child: _ContactRow(row: r),
              ),
          ],
        );
      },
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.row});
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    // Flat fields, not an embedded `profiles` object: family_circle() (0034)
    // returns the circle already joined, because the direct select with an
    // embed came back nameless under RLS. This row had been left reading the
    // old shape, so every emergency contact rendered as "Family member" with
    // no call button — on the one screen where that matters most.
    final name = row['display_name'] as String? ?? 'Family member';
    final phone = row['phone'] as String?;
    final relationship = row['relationship'] as String?;

    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: SetuColors.lavenderLight.withValues(alpha: 0.15),
              shape: BoxShape.circle),
          child: Text(
              name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(),
              style: const TextStyle(
                  color: SetuColors.lavenderLight, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: SetuSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
              if (relationship != null)
                Text(relationship,
                    style: const TextStyle(
                        color: SetuColors.mutedLight, fontSize: 12.5)),
            ],
          ),
        ),
        if (phone != null && phone.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.call, color: SetuColors.verifiedLight),
            tooltip: 'Call $name',
            onPressed: () => launchUrl(Uri.parse('tel:$phone')),
          ),
      ],
    );
  }
}

/// Age, gender, height and weight — the "who is this person" block that sat
/// above the medical detail.
///
/// Age is shown from the date of birth rather than stored as a number, and
/// BMI is computed from height and weight on read. Both would otherwise go
/// quietly stale: a stored age is wrong within a year, and a stored BMI is
/// wrong the moment someone's weight changes.
class _AboutSection extends StatelessWidget {
  const _AboutSection({
    required this.elderId,
    required this.displayName,
    required this.dob,
    required this.gender,
    required this.heightController,
    required this.weightController,
    required this.onGender,
    required this.onChanged,
  });

  final String elderId;
  final String displayName;
  final DateTime? dob;
  final String? gender;
  final TextEditingController heightController;
  final TextEditingController weightController;
  final ValueChanged<String?> onGender;
  final VoidCallback onChanged;

  static const _genders = {
    'female': 'Female',
    'male': 'Male',
    'other': 'Other',
    'prefer_not_to_say': 'Prefer not to say',
  };

  int? get _age {
    if (dob == null) return null;
    final now = DateTime.now();
    var years = now.year - dob!.year;
    if (now.month < dob!.month ||
        (now.month == dob!.month && now.day < dob!.day)) {
      years--;
    }
    return years < 0 || years > 130 ? null : years;
  }

  String? get _bmi {
    final h = double.tryParse(heightController.text.trim());
    final w = double.tryParse(weightController.text.trim());
    if (h == null || w == null || h <= 0) return null;
    final m = h / 100;
    return (w / (m * m)).toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final age = _age;
    final bmi = _bmi;
    return Container(
      padding: const EdgeInsets.all(SetuSpacing.lg),
      decoration: BoxDecoration(
        color: SetuColors.paperRaisedLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SetuColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ABOUT',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: SetuColors.mutedLight)),
          const SizedBox(height: SetuSpacing.md),
          // The photo lives here rather than on the dashboard because this is
          // the screen a family opens deliberately to fill in who the person
          // is. Tapping it uploads; the same face then appears wherever the
          // elder is shown.
          Row(
            children: [
              ElderAvatar(
                elderId: elderId,
                displayName: displayName,
                radius: 32,
                editable: true,
              ),
              const SizedBox(width: SetuSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 2),
                    const Text('Tap the photo to add or change it',
                        style: TextStyle(
                            color: SetuColors.mutedLight, fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: SetuSpacing.md),
          _WhereTheyLive(elderId: elderId),
          const SizedBox(height: SetuSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'Age',
                  value: age == null ? '—' : '$age',
                  hint: age == null ? 'Add a date of birth' : 'years',
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'BMI',
                  value: bmi ?? '—',
                  hint: bmi == null ? 'Needs height + weight' : 'calculated',
                ),
              ),
            ],
          ),
          const SizedBox(height: SetuSpacing.md),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: heightController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => onChanged(),
                  decoration: const InputDecoration(
                      labelText: 'Height', suffixText: 'cm'),
                ),
              ),
              const SizedBox(width: SetuSpacing.md),
              Expanded(
                child: TextField(
                  controller: weightController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => onChanged(),
                  decoration: const InputDecoration(
                      labelText: 'Weight', suffixText: 'kg'),
                ),
              ),
            ],
          ),
          const SizedBox(height: SetuSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: gender,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Gender'),
            items: [
              for (final e in _genders.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: onGender,
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.hint});

  final String label;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: SetuColors.mutedLight, fontSize: 12.5)),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800)),
        Text(hint,
            style: const TextStyle(
                color: SetuColors.mutedLight, fontSize: 11.5)),
      ],
    );
  }
}

/// Where the elder lives, and a way to change it.
///
/// This sits on the profile rather than in settings because it is a fact about
/// the person, not a preference of the app — and because it silently decides
/// which doctors and which caregivers the family is ever shown. A family whose
/// parent has moved to another city needs to be able to say so without
/// contacting support.
class _WhereTheyLive extends ConsumerWidget {
  const _WhereTheyLive({required this.elderId});

  final String elderId;

  Future<void> _change(BuildContext context, WidgetRef ref, String current) async {
    final regions = await ref.read(regionsProvider.future);
    if (!context.mounted) return;
    var picked = current;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Where do they live?'),
          content: SizedBox(
            width: double.maxFinite,
            // Scrollable because the "we're not there yet" note under the
            // dropdown runs to three lines on a small phone, and an
            // AlertDialog overflows rather than scrolling on its own.
            child: SingleChildScrollView(
              child: RegionPicker(
                value: picked,
                onChanged: (v) => setState(() => picked = v),
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    if (confirmed != true || picked == current) return;

    final region = regions.firstWhere((r) => r['code'] == picked,
        orElse: () => const <String, dynamic>{});
    final regionId = region['id'] as String?;
    if (regionId == null) return;
    try {
      await setElderRegion(ref, elderId: elderId, regionId: regionId);
      ref.invalidate(elderRegionProvider(elderId));
    } catch (err) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not change: $err')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final region = ref.watch(elderRegionProvider(elderId)).asData?.value;
    final name = region?['display_name'] as String? ?? 'Not set';
    final live = region?['status'] == 'active';
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _change(context, ref, region?['code'] as String? ?? 'vizag-ap-in'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: SetuSpacing.sm),
        child: Row(
          children: [
            const Icon(Icons.place_outlined, size: 20, color: SetuColors.mutedLight),
            const SizedBox(width: SetuSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 1),
                  Text(
                      live
                          ? 'Doctors and caregivers here'
                          : 'No SETU caregivers here yet',
                      style: TextStyle(
                          fontSize: 12,
                          color: live
                              ? SetuColors.mutedLight
                              : SetuColors.peachLight)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: SetuColors.mutedLight),
          ],
        ),
      ),
    );
  }
}
