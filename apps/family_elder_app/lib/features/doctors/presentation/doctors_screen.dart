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

/// The doctor directory: browse SETU-empanelled doctors and book a
/// video / audio / in-person consult for an elder.
class DoctorsScreen extends ConsumerWidget {
  const DoctorsScreen({required this.elderId, super.key});
  final String elderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(doctorsProvider(null));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consult a doctor'),
        actions: [
          IconButton(
            tooltip: 'My consultations',
            icon: const Icon(Icons.event_note_outlined),
            onPressed: () => context.push('/elder/$elderId/consultations'),
          ),
        ],
      ),
      body: async.when(
        loading: () => const SetuLoading(),
        error: (e, _) => const SetuErrorState(),
        data: (doctors) {
          if (doctors.isEmpty) {
            return const SetuEmptyState(
              icon: Icons.medical_services_outlined,
              title: 'No doctors listed yet',
              message: 'Doctors for your city will appear here soon.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(SetuSpacing.lg),
            itemCount: doctors.length,
            separatorBuilder: (_, __) => const SizedBox(height: SetuSpacing.md),
            itemBuilder: (context, i) => _DoctorCard(
              doctor: doctors[i],
              onBook: () => _openBooking(context, ref, doctors[i]),
            ),
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
      builder: (_) => _BookingSheet(elderId: elderId, doctor: doctor),
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
        color: SetuColors.paperLight,
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
                radius: 26,
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
                        style: const TextStyle(color: SetuColors.accentLight)),
                    if (doctor.qualification != null)
                      Text(doctor.qualification!,
                          style: const TextStyle(
                              color: SetuColors.mutedLight, fontSize: 12.5)),
                  ],
                ),
              ),
              if (doctor.rating != null)
                Row(children: [
                  const Icon(Icons.star_rounded,
                      size: 16, color: SetuColors.peachLight),
                  const SizedBox(width: 2),
                  Text(doctor.rating!.toStringAsFixed(1),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ]),
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
