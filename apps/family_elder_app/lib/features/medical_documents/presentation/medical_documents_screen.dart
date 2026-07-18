import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setu_core/setu_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers.dart';
import '../data/medical_documents_repository.dart';

final _documentsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, elderId) async {
  final client = ref.watch(supabaseClientProvider);
  return MedicalDocumentsRepository(client).list(elderId);
});

const _categories = {
  'lab_report': ('Lab report', Icons.science_outlined),
  'prescription': ('Prescription', Icons.receipt_long_outlined),
  'scan': ('Scan / X-ray / MRI', Icons.radio_button_checked_outlined),
  'discharge_summary': ('Discharge summary', Icons.local_hospital_outlined),
  'vaccination': ('Vaccination', Icons.vaccines_outlined),
  'insurance': ('Insurance', Icons.shield_outlined),
  'other': ('Other', Icons.description_outlined),
};

/// Secure medical document vault: upload and view lab reports, prescriptions,
/// scans and more. Files live in a private bucket and open via short-lived
/// signed links; access is consent-gated by RLS.
class MedicalDocumentsScreen extends ConsumerWidget {
  const MedicalDocumentsScreen({required this.elderId, super.key});

  final String elderId;

  MedicalDocumentsRepository _repo(WidgetRef ref) =>
      MedicalDocumentsRepository(ref.read(supabaseClientProvider));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(_documentsProvider(elderId));
    return Scaffold(
      appBar: AppBar(title: const Text('Medical records')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _upload(context, ref),
        icon: const Icon(Icons.upload_file),
        label: const Text('Upload'),
      ),
      body: docsAsync.when(
        data: (docs) {
          if (docs.isEmpty) {
            return const SetuEmptyState(
              icon: Icons.folder_outlined,
              title: 'No documents yet',
              message:
                  'Upload lab reports, prescriptions and scans to keep them '
                  'safe and handy for every visit.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(SetuSpacing.lg),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: SetuSpacing.sm),
            itemBuilder: (context, i) => _DocCard(
              doc: docs[i],
              onOpen: () => _open(context, ref, docs[i]),
              onDelete: () => _delete(context, ref, docs[i]),
            ),
          );
        },
        loading: () => const SetuLoading(),
        error: (err, stack) => const SetuErrorState(),
      ),
    );
  }

  Future<void> _open(
      BuildContext context, WidgetRef ref, Map<String, dynamic> doc) async {
    try {
      final url =
          await _repo(ref).signedUrl(doc['storage_path'] as String);
      if (!await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication)) {
        throw StateError('Could not open');
      }
    } catch (err) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not open: $err')));
      }
    }
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, Map<String, dynamic> doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete document?'),
        content: Text('Remove "${doc['title']}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: SetuColors.sosLight),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repo(ref).delete(
          id: doc['id'] as String, storagePath: doc['storage_path'] as String);
      ref.invalidate(_documentsProvider(elderId));
    } catch (err) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not delete: $err')));
      }
    }
  }

  Future<void> _upload(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    final file = result?.files.singleOrNull;
    if (file == null || file.bytes == null) return;
    if (!context.mounted) return;

    final titleController = TextEditingController(
        text: file.name.replaceAll(RegExp(r'\.[^.]+$'), ''));
    var category = 'lab_report';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add document'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: SetuSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Type'),
                items: [
                  for (final e in _categories.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value.$1)),
                ],
                onChanged: (v) => setState(() => category = v ?? 'other'),
              ),
              const SizedBox(height: SetuSpacing.sm),
              Text(file.name,
                  style: const TextStyle(
                      fontSize: 12, color: SetuColors.mutedLight)),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Upload')),
          ],
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final ext = file.extension ?? 'bin';
      await _repo(ref).upload(
        elderId: elderId,
        title: titleController.text.trim().isEmpty
            ? file.name
            : titleController.text.trim(),
        category: category,
        bytes: file.bytes!,
        extension: ext,
        mimeType: _mimeFor(ext),
      );
      ref.invalidate(_documentsProvider(elderId));
      messenger.showSnackBar(const SnackBar(content: Text('Document uploaded.')));
    } catch (err) {
      messenger
          .showSnackBar(SnackBar(content: Text('Could not upload: $err')));
    }
  }

  static String? _mimeFor(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      default:
        return null;
    }
  }
}

class _DocCard extends StatelessWidget {
  const _DocCard(
      {required this.doc, required this.onOpen, required this.onDelete});

  final Map<String, dynamic> doc;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final category = doc['category'] as String? ?? 'other';
    final meta = _categories[category] ?? _categories['other']!;
    final uploaded =
        DateTime.tryParse(doc['uploaded_at'] as String? ?? '')?.toLocal();
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.all(SetuSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: SetuColors.borderLight),
        ),
        child: Row(
          children: [
            SetuIconChip(icon: meta.$2, color: SetuColors.lavenderLight),
            const SizedBox(width: SetuSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(doc['title'] as String? ?? 'Document',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    '${meta.$1}${uploaded != null ? ' · ${SetuFormat.friendlyDate(uploaded)}' : ''}',
                    style: const TextStyle(
                        fontSize: 12.5, color: SetuColors.mutedLight),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: SetuColors.mutedLight),
              onPressed: onDelete,
            ),
            const Icon(Icons.open_in_new, size: 18, color: SetuColors.accentLight),
          ],
        ),
      ),
    );
  }
}
