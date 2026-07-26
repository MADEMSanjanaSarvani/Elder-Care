import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:setu_core/setu_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers.dart';
import '../data/doctors_repository.dart';
import 'consultations_screen.dart';
import '../../../core/illustrations.dart';

final doctorsProvider =
    FutureProvider.family<List<Doctor>, String?>((ref, specialty) async {
  return DoctorsRepository(ref.watch(supabaseClientProvider))
      .list(specialty: specialty);
});

/// The doctor directory, matching the Stitch "doctor_consultations" design:
/// a search bar over the same already-fetched doctor list (client-side
/// filter, no new query), and restyled cards. Browse SETU-empanelled
/// doctors and book a video / audio / in-person consult for an elder.
///
/// The Stitch mock also shows a review count next to the star rating
/// ("4.9 (120+)") and a "Preparing for your call" checklist (connection
/// test, health records, symptoms) — SETU's Doctor model has no review
/// count field, and there's no pre-call prep feature behind that checklist,
/// so neither is invented here.
class DoctorsScreen extends ConsumerStatefulWidget {
  const DoctorsScreen({required this.elderId, super.key});
  final String elderId;

  @override
  ConsumerState<DoctorsScreen> createState() => _DoctorsScreenState();
}

class _DoctorsScreenState extends ConsumerState<DoctorsScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String? _specialty;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(doctorsProvider(null));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consult a doctor'),
        actions: [
          IconButton(
            tooltip: 'My consultations',
            icon: const Icon(Icons.event_note_outlined),
            onPressed: () => context.push('/elder/${widget.elderId}/consultations'),
          ),
        ],
      ),
      body: async.when(
        loading: () => const SetuLoading(),
        error: (e, _) => const SetuErrorState(),
        data: (allDoctors) {
          if (allDoctors.isEmpty) {
            return SetuEmptyState(
              artwork: SetuArt.emptyCare(),
              icon: Icons.medical_services_outlined,
              title: 'No doctors listed yet',
              message: 'Doctors for your city will appear here soon.',
            );
          }
          final bySpecialty = _specialty == null
              ? allDoctors
              : allDoctors.where((d) => d.specialty == _specialty).toList();
          final doctors = _query.isEmpty
              ? bySpecialty
              : bySpecialty
                  .where((d) =>
                      d.displayName.toLowerCase().contains(_query) ||
                      d.specialty.toLowerCase().contains(_query) ||
                      (d.clinicName ?? '').toLowerCase().contains(_query))
                  .toList();
          return ListView(
            padding: const EdgeInsets.all(SetuSpacing.lg),
            children: [
              Text('Find a doctor',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text(
                  'Who to see and where. Book a caregiver to take them, or '
                  'just call the clinic yourself.',
                  style: TextStyle(color: SetuColors.mutedLight)),
              const SizedBox(height: SetuSpacing.md),
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search by name, specialty or hospital',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: SetuSpacing.md),
              _SpecialtyFilter(
                specialties: {for (final d in allDoctors) d.specialty}.toList()
                  ..sort(),
                selected: _specialty,
                onChanged: (s) => setState(() => _specialty = s),
              ),
              const SizedBox(height: SetuSpacing.lg),
              if (doctors.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: SetuSpacing.lg),
                  child: Text('No doctors match your search.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: SetuColors.mutedLight)),
                )
              else
                for (final d in doctors) ...[
                  _DoctorCard(
                      doctor: d, onBook: () => _openBooking(context, ref, d)),
                  const SizedBox(height: SetuSpacing.md),
                ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _openBooking(
      BuildContext context, WidgetRef ref, Doctor doctor) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _BookingSheet(elderId: widget.elderId, doctor: doctor),
    );
  }
}

class _DoctorCard extends StatelessWidget {
  const _DoctorCard({required this.doctor, required this.onBook});
  final Doctor doctor;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: SetuColors.accentLight.withValues(alpha: 0.14),
                backgroundImage: doctor.photoUrl != null
                    ? NetworkImage(doctor.photoUrl!)
                    : null,
                child: doctor.photoUrl == null
                    ? const Icon(Icons.person, color: SetuColors.accentLight)
                    : null,
              ),
              const SizedBox(width: SetuSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(doctor.displayName,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    Text(doctor.specialty,
                        style: const TextStyle(
                            color: SetuColors.accentLight,
                            fontWeight: FontWeight.w600)),
                    if (doctor.qualification != null)
                      Text(doctor.qualification!,
                          style: const TextStyle(
                              color: SetuColors.mutedLight, fontSize: 12.5)),
                  ],
                ),
              ),
              if (doctor.rating != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: SetuColors.peachLight.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.star_rounded,
                        size: 15, color: SetuColors.peachLight),
                    const SizedBox(width: 2),
                    Text(doctor.rating!.toStringAsFixed(1),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ]),
                ),
            ],
          ),
          const SizedBox(height: SetuSpacing.md),
          Wrap(
            spacing: SetuSpacing.sm,
            runSpacing: 6,
            children: [
              if (doctor.yearsExperience != null)
                _chip(Icons.workspace_premium_outlined,
                    '${doctor.yearsExperience}+ yrs'),
              for (final l in doctor.languages.take(3))
                _chip(Icons.translate, l),
            ],
          ),
          if (doctor.clinicName != null) ...[
            const SizedBox(height: SetuSpacing.md),
            _ClinicBlock(doctor: doctor),
          ],
          const SizedBox(height: SetuSpacing.md),
          Row(
            children: [
              if (doctor.consultFee > 0) ...[
                Text('₹${doctor.consultFee.toStringAsFixed(0)}',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const Text(' / consult',
                    style: TextStyle(color: SetuColors.mutedLight)),
              ],
              const Spacer(),
              if (doctor.phone != null)
                IconButton(
                  tooltip: 'Call the clinic',
                  icon: const Icon(Icons.call_outlined),
                  onPressed: () => launchUrl(Uri.parse('tel:${doctor.phone}')),
                ),
              if (doctor.address != null || doctor.lat != null)
                IconButton(
                  tooltip: 'Directions',
                  icon: const Icon(Icons.directions_outlined),
                  onPressed: () => _openMaps(doctor),
                ),
              const SizedBox(width: 4),
              FilledButton(
                onPressed: doctor.escortAvailable ? onBook : null,
                child: Text(doctor.escortAvailable ? 'Take them' : 'No escort'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Open the clinic in Google Maps — by coordinates when we have them,
  /// otherwise by its address, which is what a hand-entered listing usually
  /// has.
  static void _openMaps(Doctor d) {
    final q = (d.lat != null && d.lng != null)
        ? '${d.lat},${d.lng}'
        : Uri.encodeComponent('${d.clinicName ?? ''} ${d.address ?? ''}'.trim());
    launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=$q'),
        mode: LaunchMode.externalApplication);
  }

  Widget _chip(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: SetuColors.accentLight.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: SetuColors.mutedLight),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(fontSize: 12)),
        ]),
      );
}

class _BookingSheet extends ConsumerStatefulWidget {
  const _BookingSheet({required this.elderId, required this.doctor});
  final String elderId;
  final Doctor doctor;

  @override
  ConsumerState<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends ConsumerState<_BookingSheet> {
  String _mode = 'video';
  DateTime _when = DateTime.now().add(const Duration(hours: 1));
  final _reason = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickWhen() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_when),
    );
    if (time == null) return;
    setState(() => _when =
        DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _confirm() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await DoctorsRepository(ref.read(supabaseClientProvider)).book(
        elderId: widget.elderId,
        doctorId: widget.doctor.id,
        mode: _mode,
        scheduledAt: _when,
        reason: _reason.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Consultation booked.')),
      );
      ref.invalidate(myConsultationsProvider(widget.elderId));
    } catch (err) {
      setState(() => _error = err.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.doctor;
    return Padding(
      padding: EdgeInsets.only(
        left: SetuSpacing.lg,
        right: SetuSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + SetuSpacing.lg,
        top: SetuSpacing.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Book ${d.displayName}',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          Text(d.specialty, style: const TextStyle(color: SetuColors.mutedLight)),
          const SizedBox(height: SetuSpacing.lg),
          const Text('How would you like to consult?',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: SetuSpacing.sm),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                  value: 'video',
                  icon: Icon(Icons.videocam_outlined),
                  label: Text('Video')),
              ButtonSegment(
                  value: 'audio',
                  icon: Icon(Icons.call_outlined),
                  label: Text('Audio')),
              ButtonSegment(
                  value: 'in_person',
                  icon: Icon(Icons.local_hospital_outlined),
                  label: Text('Clinic')),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          const SizedBox(height: SetuSpacing.lg),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const SetuIconChip(icon: Icons.schedule),
            title: const Text('When'),
            subtitle: Text(_prettyWhen(_when)),
            trailing: TextButton(
                onPressed: _pickWhen, child: const Text('Change')),
          ),
          const SizedBox(height: SetuSpacing.sm),
          TextField(
            controller: _reason,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Reason (optional)',
              hintText: 'e.g. BP review, knee pain, general check-up',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: SetuSpacing.sm),
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: SetuSpacing.lg),
          FilledButton(
            onPressed: _busy ? null : _confirm,
            child: Text(_busy
                ? 'Booking…'
                : d.consultFee > 0
                    ? 'Confirm · ₹${d.consultFee.toStringAsFixed(0)}'
                    : 'Confirm booking'),
          ),
        ],
      ),
    );
  }

  static String _prettyWhen(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour < 12 ? 'AM' : 'PM';
    final min = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month - 1]}, $h:$min $ampm';
  }
}

/// Horizontal specialty filter, built from the specialties actually present
/// in the directory rather than a hard-coded list — a fixed list would show
/// "Cardiology" in a city where no cardiologist has been added yet.
class _SpecialtyFilter extends StatelessWidget {
  const _SpecialtyFilter({
    required this.specialties,
    required this.selected,
    required this.onChanged,
  });

  final List<String> specialties;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (specialties.length < 2) return const SizedBox.shrink();
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: SetuSpacing.sm),
            child: ChoiceChip(
              label: const Text('All'),
              selected: selected == null,
              onSelected: (_) => onChanged(null),
            ),
          ),
          for (final s in specialties)
            Padding(
              padding: const EdgeInsets.only(right: SetuSpacing.sm),
              child: ChoiceChip(
                label: Text(s),
                selected: selected == s,
                onSelected: (_) => onChanged(selected == s ? null : s),
              ),
            ),
        ],
      ),
    );
  }
}

/// Where the doctor sits and when — the part a family actually acts on,
/// whether they book an escort or simply walk in.
///
/// When the consulting hours aren't known this says "call to confirm timings"
/// rather than staying silent or implying the clinic is closed. Sending an
/// elderly person across town to a shut clinic is the failure that matters
/// here, so an unknown must never read as a fact.
class _ClinicBlock extends StatelessWidget {
  const _ClinicBlock({required this.doctor});
  final Doctor doctor;

  @override
  Widget build(BuildContext context) {
    final hours = doctor.hoursLabel;
    final today = doctor.consultsToday;
    return Container(
      padding: const EdgeInsets.all(SetuSpacing.md),
      decoration: BoxDecoration(
        color: SetuColors.paperLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SetuColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.local_hospital_outlined,
                  size: 18, color: SetuColors.accentLight),
              const SizedBox(width: SetuSpacing.sm),
              Expanded(
                child: Text(doctor.clinicName!,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              if (doctor.registrationVerified)
                const Tooltip(
                  message: 'Registration checked against the medical register',
                  child: Icon(Icons.verified,
                      size: 18, color: SetuColors.verifiedLight),
                ),
            ],
          ),
          if (doctor.address != null) ...[
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Text(doctor.address!,
                  style: const TextStyle(
                      color: SetuColors.mutedLight, fontSize: 12.5)),
            ),
          ],
          const SizedBox(height: SetuSpacing.sm),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Row(
              children: [
                Icon(Icons.schedule,
                    size: 15,
                    color: hours == null
                        ? SetuColors.peachLight
                        : SetuColors.mutedLight),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    hours ?? 'Call to confirm timings',
                    style: TextStyle(
                        fontSize: 12.5,
                        color: hours == null
                            ? SetuColors.peachLight
                            : SetuColors.mutedLight),
                  ),
                ),
                if (hours != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (today
                              ? SetuColors.verifiedLight
                              : SetuColors.mutedLight)
                          .withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      today ? 'Sits today' : 'Not today',
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: today
                              ? SetuColors.verifiedLight
                              : SetuColors.mutedLight),
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
