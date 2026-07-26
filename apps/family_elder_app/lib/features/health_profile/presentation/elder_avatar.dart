import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setu_core/setu_core.dart';

import '../../../core/providers.dart';
import '../data/elder_photo_repository.dart';

/// A signed URL for the elder's photo, or null when they don't have one.
///
/// Kept as a provider rather than fetched inside the widget so the dashboard
/// and the health profile show the same photo from one round trip, and so a
/// fresh upload can invalidate every place the face appears at once.
final elderPhotoProvider =
    FutureProvider.family<String?, String>((ref, elderId) async {
  ref.watch(authStateProvider);
  return ElderPhotoRepository(ref.watch(supabaseClientProvider))
      .signedUrl(elderId);
});

/// The elder's face, falling back to their initials.
///
/// [editable] adds a camera badge and the pick/upload flow. It is off by
/// default: the same avatar appears on read-only surfaces like the dashboard,
/// and a photo that changes when someone brushes the screen is worse than one
/// that can only be changed deliberately from the profile.
class ElderAvatar extends ConsumerStatefulWidget {
  const ElderAvatar({
    super.key,
    required this.elderId,
    required this.displayName,
    this.radius = 34,
    this.editable = false,
  });

  final String elderId;
  final String displayName;
  final double radius;
  final bool editable;

  @override
  ConsumerState<ElderAvatar> createState() => _ElderAvatarState();
}

class _ElderAvatarState extends ConsumerState<ElderAvatar> {
  bool _busy = false;

  String get _initials {
    final parts = widget.displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  Future<void> _pick() async {
    // FilePicker rather than image_picker: it is already a proven dependency
    // in this build (medical documents use it) and needs no new native code.
    // withData loads the bytes in memory, which is fine for a portrait and
    // avoids dealing with a file path that Android may not grant access to.
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    final file = result?.files.singleOrNull;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;

    // Photos off a modern phone are several megabytes and there is no image
    // resizing in this build, so the upload is bounded rather than left to
    // stall on a slow connection with no explanation.
    const maxBytes = 5 * 1024 * 1024;
    if (bytes.lengthInBytes > maxBytes) {
      if (mounted) {
        _say('That photo is larger than 5 MB. Please pick a smaller one.');
      }
      return;
    }

    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await ElderPhotoRepository(ref.read(supabaseClientProvider)).upload(
        elderId: widget.elderId,
        bytes: bytes,
        extension: file.extension ?? 'jpg',
        mimeType: _mimeFor(file.extension),
      );
      ref.invalidate(elderPhotoProvider(widget.elderId));
      ref.invalidate(myElderProfilesProvider);
    } catch (err) {
      if (mounted) _say("Couldn't save that photo: $err");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    setState(() => _busy = true);
    try {
      await ElderPhotoRepository(ref.read(supabaseClientProvider))
          .clear(widget.elderId);
      ref.invalidate(elderPhotoProvider(widget.elderId));
      ref.invalidate(myElderProfilesProvider);
    } catch (err) {
      if (mounted) _say("Couldn't remove that photo: $err");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _say(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  static String _mimeFor(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _onTap(bool hasPhoto) async {
    if (_busy) return;
    if (!hasPhoto) {
      await _pick();
      return;
    }
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: SetuColors.paperLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Change photo'),
              onTap: () => Navigator.of(context).pop('change'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: SetuColors.sosLight),
              title: const Text('Remove photo'),
              onTap: () => Navigator.of(context).pop('remove'),
            ),
          ],
        ),
      ),
    );
    if (action == 'change') await _pick();
    if (action == 'remove') await _remove();
  }

  @override
  Widget build(BuildContext context) {
    final photo = ref.watch(elderPhotoProvider(widget.elderId));
    final url = photo.asData?.value;
    final size = widget.radius * 2;

    final circle = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: SetuColors.accentLight.withValues(alpha: 0.14),
        shape: BoxShape.circle,
        border: Border.all(color: SetuColors.borderLight),
      ),
      child: url == null
          ? Text(_initials,
              style: TextStyle(
                color: SetuColors.accentLight,
                fontWeight: FontWeight.w800,
                fontSize: widget.radius * 0.7,
              ))
          : Image.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              // A signed URL can expire mid-session; initials are a better
              // answer than a broken-image glyph on a screen about a person.
              errorBuilder: (context, _, __) => Text(_initials,
                  style: TextStyle(
                    color: SetuColors.accentLight,
                    fontWeight: FontWeight.w800,
                    fontSize: widget.radius * 0.7,
                  )),
            ),
    );

    if (!widget.editable) {
      return Semantics(
        label: url == null
            ? 'No photo of ${widget.displayName}'
            : 'Photo of ${widget.displayName}',
        child: circle,
      );
    }

    return Semantics(
      button: true,
      label: url == null
          ? 'Add a photo of ${widget.displayName}'
          : 'Change the photo of ${widget.displayName}',
      child: InkWell(
        onTap: () => _onTap(url != null),
        customBorder: const CircleBorder(),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            circle,
            if (_busy)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    ),
                  ),
                ),
              )
            else
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: SetuColors.accentLight,
                    shape: BoxShape.circle,
                    border: Border.all(color: SetuColors.paperLight, width: 2),
                  ),
                  child: const Icon(Icons.photo_camera_outlined,
                      size: 13, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
