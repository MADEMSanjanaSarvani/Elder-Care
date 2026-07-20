import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';
import '../data/health_profile_repository.dart';

/// Health Records Management (PRD Part 6, Batch 3, Module 12): one screen,
/// visually split into an emergency-info section and an
/// administrative-info section, matching the underlying two-table split.
/// A viewer who can't read the administrative half (e.g. a caregiver
/// mid-visit) simply gets nothing back from that table — RLS decides, the
/// UI just renders what came back.
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
  final _physicianNameController = TextEditingController();
  final _physicianContactController = TextEditingController();
  final _insuranceProviderController = TextEditingController();
  final _insurancePolicyController = TextEditingController();

  bool _loaded = false;
  bool _adminVisible = false;
  bool _saving = false;

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
    if (!mounted) return;
    setState(() {
      _bloodTypeController.text = health?['blood_type'] as String? ?? '';
      _allergiesController.text =
          ((health?['allergies'] as List?)?.cast<String>() ?? []).join(', ');
      _conditionsController.text =
          ((health?['chronic_conditions'] as List?)?.cast<String>() ?? []).join(', ');
      _emergencyNotesController.text =
          health?['emergency_medical_notes'] as String? ?? '';
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
      );
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
                  SetuColors.sosLight.withValues(alpha: 0.10),
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
              ],
            ),
          ),
          const SizedBox(height: SetuSpacing.lg),
          Row(
            children: [
              const SetuIconChip(
                  icon: Icons.health_and_safety_outlined,
                  color: SetuColors.sosLight,
                  size: 16),
              const SizedBox(width: SetuSpacing.sm),
              Text('Emergency information',
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(top: SetuSpacing.xs, bottom: SetuSpacing.sm),
            child: Text(
                'Visible to a caregiver during an active visit or SOS response.'),
          ),
          TextField(
            controller: _bloodTypeController,
            decoration: const InputDecoration(labelText: 'Blood type'),
          ),
          const SizedBox(height: SetuSpacing.sm),
          TextField(
            controller: _allergiesController,
            decoration: const InputDecoration(
                labelText: 'Allergies (comma-separated)'),
          ),
          const SizedBox(height: SetuSpacing.sm),
          TextField(
            controller: _conditionsController,
            decoration: const InputDecoration(
                labelText: 'Chronic conditions (comma-separated)'),
          ),
          const SizedBox(height: SetuSpacing.sm),
          TextField(
            controller: _emergencyNotesController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Emergency medical notes'),
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
          TextField(
            controller: _physicianNameController,
            decoration: const InputDecoration(labelText: 'Primary physician'),
          ),
          const SizedBox(height: SetuSpacing.sm),
          TextField(
            controller: _physicianContactController,
            decoration: const InputDecoration(labelText: 'Physician contact'),
          ),
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
