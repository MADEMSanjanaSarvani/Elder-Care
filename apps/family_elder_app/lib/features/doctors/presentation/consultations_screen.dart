import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';
import '../data/doctors_repository.dart';

final myConsultationsProvider =
    FutureProvider.family<List<Consultation>, String>((ref, elderId) async {
  ref.watch(authStateProvider);
  return DoctorsRepository(ref.watch(supabaseClientProvider))
      .myConsultations(elderId);
});

final prescriptionsProvider =
    FutureProvider.family<List<Prescription>, String>((ref, elderId) async {
  ref.watch(authStateProvider);
  return DoctorsRepository(ref.watch(supabaseClientProvider))
      .prescriptions(elderId);
});

/// A family's consultations with doctors, plus the prescriptions doctors have
/// issued. Two tabs: upcoming/past consults, and the prescription history.
class ConsultationsScreen extends ConsumerWidget {
  const ConsultationsScreen({required this.elderId, super.key});
  final String elderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Consultations'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Consults'),
            Tab(text: 'Prescriptions'),
          ]),
        ),
        body: TabBarView(children: [
          _ConsultsTab(elderId: elderId),
          _PrescriptionsTab(elderId: elderId),
        ]),
      ),
    );
  }
}

class _ConsultsTab extends ConsumerWidget {
  const _ConsultsTab({required this.elderId});
  final String elderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myConsultationsProvider(elderId));
    return async.when(
      loading: () => const SetuLoading(),
      error: (e, _) => const SetuErrorState(),
      data: (items) {
        if (items.isEmpty) {
          return const SetuEmptyState(
            icon: Icons.event_note_outlined,
            title: 'No consultations yet',
            message: 'Book a doctor and your consults will show here.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async =>
              ref.refresh(myConsultationsProvider(elderId).future),
          child: ListView.separated(
            padding: const EdgeInsets.all(SetuSpacing.lg),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: SetuSpacing.md),
            itemBuilder: (context, i) =>
                _ConsultCard(consult: items[i], elderId: elderId),
          ),
        );
      },
    );
  }
}

class _ConsultCard extends StatelessWidget {
  const _ConsultCard({required this.consult, required this.elderId});
  final Consultation consult;
  final String elderId;

  @override
  Widget build(BuildContext context) {
    final upcoming = consult.scheduledAt.isAfter(DateTime.now());
    final canJoin = consult.isVideo &&
        consult.agoraChannel != null &&
        consult.status != 'completed' &&
        consult.status != 'cancelled';
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
          Row(children: [
            SetuIconChip(
                icon: consult.isVideo
                    ? Icons.videocam_outlined
                    : consult.mode == 'audio'
                        ? Icons.call_outlined
                        : Icons.local_hospital_outlined),
            const SizedBox(width: SetuSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(consult.doctorName ?? 'Doctor',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(consult.doctorSpecialty ?? '',
                      style: const TextStyle(
                          color: SetuColors.mutedLight, fontSize: 12.5)),
                ],
              ),
            ),
            SetuStatusPill(
              label: consult.status,
              color: upcoming ? SetuColors.accentLight : SetuColors.mutedLight,
            ),
          ]),
          const SizedBox(height: SetuSpacing.sm),
          Row(children: [
            const Icon(Icons.schedule,
                size: 15, color: SetuColors.mutedLight),
            const SizedBox(width: 6),
            Text(_pretty(consult.scheduledAt),
                style: const TextStyle(color: SetuColors.mutedLight)),
            const Spacer(),
            if (consult.fee > 0)
              Text('₹${consult.fee.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
          if (canJoin) ...[
            const SizedBox(height: SetuSpacing.md),
            FilledButton.icon(
              onPressed: () => context.push(
                  '/elder/$elderId/consult/${consult.id}/video?channel=${consult.agoraChannel}'),
              icon: const Icon(Icons.videocam),
              label: const Text('Join video consult'),
            ),
          ],
        ],
      ),
    );
  }

  static String _pretty(DateTime d) {
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

class _PrescriptionsTab extends ConsumerWidget {
  const _PrescriptionsTab({required this.elderId});
  final String elderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(prescriptionsProvider(elderId));
    return async.when(
      loading: () => const SetuLoading(),
      error: (e, _) => const SetuErrorState(),
      data: (items) {
        if (items.isEmpty) {
          return const SetuEmptyState(
            icon: Icons.description_outlined,
            title: 'No prescriptions yet',
            message: 'Prescriptions doctors write will appear here.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(SetuSpacing.lg),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: SetuSpacing.md),
          itemBuilder: (context, i) => _PrescriptionCard(rx: items[i]),
        );
      },
    );
  }
}

class _PrescriptionCard extends StatelessWidget {
  const _PrescriptionCard({required this.rx});
  final Prescription rx;

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
          Row(children: [
            const SetuIconChip(
                icon: Icons.description_outlined,
                color: SetuColors.lavenderLight),
            const SizedBox(width: SetuSpacing.md),
            Expanded(
              child: Text(rx.doctorName ?? 'Prescription',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            Text(_date(rx.issuedAt),
                style: const TextStyle(
                    color: SetuColors.mutedLight, fontSize: 12.5)),
          ]),
          const SizedBox(height: SetuSpacing.md),
          for (final m in rx.medicines) _medicineRow(m),
          if (rx.advice != null && rx.advice!.isNotEmpty) ...[
            const SizedBox(height: SetuSpacing.sm),
            Text('Advice: ${rx.advice}',
                style: const TextStyle(color: SetuColors.mutedLight)),
          ],
          if (rx.followUpDate != null) ...[
            const SizedBox(height: SetuSpacing.xs),
            Text('Follow-up: ${_date(rx.followUpDate!)}',
                style: const TextStyle(
                    color: SetuColors.accentLight,
                    fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }

  Widget _medicineRow(Map<String, dynamic> m) {
    final name = m['name']?.toString() ?? '';
    final parts = [
      m['dosage'],
      m['frequency'],
      m['duration'],
    ].where((e) => e != null && e.toString().isNotEmpty).join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.only(top: 3, right: 8),
          child: Icon(Icons.medication_outlined,
              size: 16, color: SetuColors.accentLight),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (parts.isNotEmpty)
              Text(parts,
                  style: const TextStyle(
                      color: SetuColors.mutedLight, fontSize: 12.5)),
          ]),
        ),
      ]),
    );
  }

  static String _date(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}
