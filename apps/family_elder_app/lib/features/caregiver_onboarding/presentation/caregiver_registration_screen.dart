import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/location.dart';
import '../../../core/providers.dart';
import '../../../core/role_exit.dart';
import '../data/caregiver_registration_repository.dart';
import '../../auth/data/auth_repository.dart';

/// Professional application for caregivers. On submit it files the application
/// (caregiver-register) and the caregiver moves to "pending verification"
/// until an admin activates them — no one goes live unreviewed.
class CaregiverRegistrationScreen extends ConsumerStatefulWidget {
  const CaregiverRegistrationScreen({super.key});

  @override
  ConsumerState<CaregiverRegistrationScreen> createState() =>
      _CaregiverRegistrationScreenState();
}

class _CaregiverRegistrationScreenState
    extends ConsumerState<CaregiverRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _gender = ValueNotifier<String>('female');
  DateTime? _dob;
  final _address = TextEditingController();
  final _govId = TextEditingController();
  final _qualification = TextEditingController();
  final _experience = TextEditingController();
  final _certifications = TextEditingController();
  final _languages = TextEditingController();
  final _skills = TextEditingController();
  final _bio = TextEditingController();
  final _hours = TextEditingController();
  final _radius = TextEditingController();
  final _charge = TextEditingController();
  final _councilReg = TextEditingController();
  final _emergencyName = TextEditingController();
  final _emergencyPhone = TextEditingController();

  double? _latitude;
  double? _longitude;
  bool _locating = false;
  String _type = 'non_clinical';
  String _subRole = 'companion';
  bool _busy = false;

  static const _subRolesByType = {
    'clinical': ['nurse', 'physiotherapist'],
    'non_clinical': [
      'companion',
      'hospital_attendant',
      'home_service_maid',
      'home_service_general',
    ],
  };

  static const _subRoleLabels = {
    'nurse': 'Nurse',
    'physiotherapist': 'Physiotherapist',
    'hospital_attendant': 'Hospital attendant',
    'companion': 'Companion',
    'home_service_maid': 'Home helper',
    'home_service_general': 'General home services',
  };

  @override
  void dispose() {
    for (final c in [
      _name, _address, _govId, _qualification, _experience, _certifications,
      _languages, _skills, _bio, _hours, _radius, _charge, _councilReg,
      _emergencyName, _emergencyPhone
    ]) {
      c.dispose();
    }
    _gender.dispose();
    super.dispose();
  }

  List<String> _split(String s) =>
      s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  /// Captures the caregiver's base location so families can find them by
  /// distance. Consent-based; if denied, they can still register (no distance).
  ///
  /// Everything about why this used to fail — an eight-second budget on a fix
  /// that routinely takes thirty, no check that location services were even on,
  /// and a raw TimeoutException shown to the caregiver — now lives in
  /// captureLocation(), which returns a sentence instead of a stack trace.
  Future<void> _captureLocation() async {
    setState(() => _locating = true);
    final result = await captureLocation();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (result.ok) {
        _latitude = result.position!.latitude;
        _longitude = result.position!.longitude;
      }
    });
    if (!result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.problem!),
        duration: const Duration(seconds: 6),
        action: result.needsSettings
            ? const SnackBarAction(
                label: 'Settings',
                onPressed: Geolocator.openAppSettings,
              )
            : null,
      ));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_type == 'clinical' && _councilReg.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Clinical roles need a council registration number.')));
      return;
    }
    setState(() => _busy = true);
    try {
      await CaregiverRegistrationRepository(ref.read(supabaseClientProvider))
          .submit({
        'full_name': _name.text.trim(),
        'caregiver_type': _type,
        'sub_role': _subRole,
        'professional_council_reg_no': _councilReg.text.trim(),
        'date_of_birth': _dob?.toIso8601String().substring(0, 10),
        'gender': _gender.value,
        'address': {'line': _address.text.trim()},
        'government_id': _govId.text.trim(),
        'qualification': _qualification.text.trim(),
        'experience_years': num.tryParse(_experience.text.trim()),
        'certifications': _certifications.text.trim(),
        'languages': _split(_languages.text),
        'skills': _split(_skills.text),
        'bio': _bio.text.trim(),
        'preferred_hours': _hours.text.trim(),
        'service_radius_km': num.tryParse(_radius.text.trim()),
        'expected_charge': num.tryParse(_charge.text.trim()),
        'emergency_contact_name': _emergencyName.text.trim(),
        'emergency_contact_phone': _emergencyPhone.text.trim(),
        'latitude': _latitude,
        'longitude': _longitude,
      });
      // The caregiver row now exists (inactive) — refreshing sends the app to
      // the pending-verification screen.
      ref.invalidate(myCaregiverProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Application submitted — our team will review it.')));
      }
    } catch (err) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not submit: $err')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final subRoles = _subRolesByType[_type]!;
    // This form is the root of the caregiver shell — there is nothing beneath
    // it to pop — so "back" has to mean "return to the role picker" or it
    // means "close the app". Someone who tapped Caregiver by mistake was
    // otherwise stuck here with Sign out as the only way out.
    return RoleRootPopScope(
      child: Scaffold(
        appBar: AppBar(
          leading: const RolePickerBackButton(),
          title: const Text('Join as a caregiver'),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(SetuSpacing.lg),
            children: [
              const Text(
                'Tell us about your professional background. Our team verifies '
                'every caregiver before your profile goes live.',
                style: TextStyle(color: SetuColors.mutedLight),
              ),
              const SizedBox(height: SetuSpacing.lg),
              _section('About you'),
              _field(_name, 'Full name', required: true,
                  capitalization: TextCapitalization.words),
              _dobField(),
              _genderField(),
              _field(_address, 'Address', maxLines: 2),
              _field(_govId, 'Government ID (Aadhaar / other)',
                  helper: 'Used only for verification.'),
              const SizedBox(height: SetuSpacing.lg),
              _section('Your work'),
              _typeField(),
              _subRoleField(subRoles),
              if (_type == 'clinical')
                _field(_councilReg, 'Council registration number',
                    required: true),
              _field(_qualification, 'Highest qualification'),
              _field(_experience, 'Years of experience',
                  keyboard: TextInputType.number),
              _field(_certifications, 'Certifications',
                  helper: 'Comma-separated, if any.'),
              _field(_languages, 'Languages spoken',
                  helper: 'e.g. Telugu, Hindi, English'),
              _field(_skills, 'Key skills',
                  helper: 'Comma-separated'),
              _field(_bio, 'Short bio (shown to families)', maxLines: 3),
              const SizedBox(height: SetuSpacing.lg),
              _section('Availability & charges'),
              _field(_hours, 'Preferred working hours',
                  helper: 'e.g. 9 AM – 6 PM, weekdays'),
              _field(_radius, 'Service radius (km)',
                  keyboard: TextInputType.number),
              _field(_charge, 'Expected charge (₹ per visit)',
                  keyboard: TextInputType.number),
              const SizedBox(height: SetuSpacing.sm),
              OutlinedButton.icon(
                onPressed: _locating ? null : _captureLocation,
                icon: _locating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(_latitude != null
                        ? Icons.check_circle_outline
                        : Icons.my_location),
                label: Text(_latitude != null
                    ? 'Location captured — tap to update'
                    : 'Use my current location'),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Helps families near you find you. Optional.',
                  style: TextStyle(fontSize: 12, color: SetuColors.mutedLight),
                ),
              ),
              const SizedBox(height: SetuSpacing.lg),
              _section('Emergency contact'),
              _field(_emergencyName, 'Contact name'),
              _field(_emergencyPhone, 'Contact phone',
                  keyboard: TextInputType.phone),
              const SizedBox(height: SetuSpacing.xl),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: Text(_busy ? 'Submitting…' : 'Submit application'),
              ),
              const SizedBox(height: SetuSpacing.md),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => AuthRepository(ref.read(supabaseClientProvider)).signOut(),
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: SetuSpacing.sm),
        child: Text(title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: SetuColors.accentLight)),
      );

  Widget _field(
    TextEditingController c,
    String label, {
    bool required = false,
    String? helper,
    int maxLines = 1,
    TextInputType? keyboard,
    TextCapitalization capitalization = TextCapitalization.none,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SetuSpacing.md),
      child: TextFormField(
        controller: c,
        maxLines: maxLines,
        keyboardType: keyboard,
        textCapitalization: capitalization,
        decoration: InputDecoration(labelText: label, helperText: helper),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
            : null,
      ),
    );
  }

  Widget _dobField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: SetuSpacing.md),
      child: InkWell(
        onTap: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: DateTime(now.year - 30),
            firstDate: DateTime(now.year - 75),
            lastDate: DateTime(now.year - 18),
          );
          if (picked != null) setState(() => _dob = picked);
        },
        child: InputDecorator(
          decoration: const InputDecoration(labelText: 'Date of birth'),
          child: Text(_dob == null
              ? 'Select date'
              : SetuFormat.friendlyDate(_dob!)),
        ),
      ),
    );
  }

  Widget _genderField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: SetuSpacing.md),
      child: ValueListenableBuilder<String>(
        valueListenable: _gender,
        builder: (_, value, __) => DropdownButtonFormField<String>(
          initialValue: value,
          decoration: const InputDecoration(labelText: 'Gender'),
          items: const [
            DropdownMenuItem(value: 'female', child: Text('Female')),
            DropdownMenuItem(value: 'male', child: Text('Male')),
            DropdownMenuItem(value: 'other', child: Text('Other')),
          ],
          onChanged: (v) => _gender.value = v ?? 'female',
        ),
      ),
    );
  }

  Widget _typeField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: SetuSpacing.md),
      child: SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'non_clinical', label: Text('Non-clinical')),
          ButtonSegment(value: 'clinical', label: Text('Clinical')),
        ],
        selected: {_type},
        onSelectionChanged: (s) => setState(() {
          _type = s.first;
          _subRole = _subRolesByType[_type]!.first;
        }),
      ),
    );
  }

  Widget _subRoleField(List<String> subRoles) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SetuSpacing.md),
      child: DropdownButtonFormField<String>(
        initialValue: _subRole,
        decoration: const InputDecoration(labelText: 'Role'),
        items: [
          for (final r in subRoles)
            DropdownMenuItem(value: r, child: Text(_subRoleLabels[r] ?? r)),
        ],
        onChanged: (v) => setState(() => _subRole = v ?? subRoles.first),
      ),
    );
  }
}
