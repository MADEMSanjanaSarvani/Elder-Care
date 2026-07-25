import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';
import '../data/doctors_repository.dart';
import 'consultations_screen.dart';

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
            return const SetuEmptyState(
              icon: Icons.medical_services_outlined,
              title: 'No doctors listed yet',
              message: 'Doctors for your city will appear here soon.',
            );
          }
          final doctors = _query.isEmpty
              ? allDoctors
              : allDoctors
                  .where((d) =>
                      d.displayName.toLowerCase().contains(_query) ||
                      d.specialty.toLowerCase().contains(_query))
                  .toList();
          return ListView(
            padding: const EdgeInsets.all(SetuSpacing.lg),
            children: [
              Text('Expert Consultations',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('Book a video, audio or in-person consult for your family.',
                  style: TextStyle(color: SetuColors.mutedLight)),
              const SizedBox(height: SetuSpacing.md),
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search by name or specialty',
                  prefixIcon: Icon(Icons.search),
                ),
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
          const SizedBox(height: SetuSpacing.md),
          Row(
            children: [
              Text('₹${doctor.consultFee.toStringAsFixed(0)}',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const Text(' / consult',
                  style: TextStyle(color: SetuColors.mutedLight)),
              const Spacer(),
              FilledButton(onPressed: onBook, child: const Text('Book')),
            ],
          ),
        ],
      ),
    );
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
