import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import 'camera_capture_screen.dart';
import 'photo.dart';

/// Lets the person take a photo or choose photos from their gallery.
///
/// Returns the chosen photos (empty if they cancelled or something went wrong;
/// a message is shown in that case). Photos are shrunk to at most 1600 px and
/// recompressed where the platform supports it, so uploads stay small.
class PhotoPicker {
  PhotoPicker._();

  static final ImagePicker _picker = ImagePicker();

  /// Largest single photo accepted (after compression).
  static const int _maxBytes = 8 * 1024 * 1024;

  /// The camera is offered on phones and tablets, and in the browser (phone
  /// browsers open the camera; computers just open the file chooser). It is
  /// hidden on Windows / Linux / macOS apps, which have no camera picker.
  static bool get _cameraAvailable =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  /// Opens the "Take photo / Choose from gallery" sheet and returns up to
  /// [max] photos.
  static Future<List<PhotoRef>> pick(
    BuildContext context, {
    int max = 1,
    String title = 'Add photo',

    /// Also offer "Choose a document (PDF)", for certificates and IDs.
    bool allowDocument = false,
  }) async {
    final source = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(title,
                    style: Theme.of(sheetContext)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
            ),
            if (_cameraAvailable)
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take a photo'),
                onTap: () => Navigator.pop(sheetContext, 'camera'),
              ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(max > 1 ? 'Choose from gallery' : 'Choose a photo'),
              onTap: () => Navigator.pop(sheetContext, 'gallery'),
            ),
            if (allowDocument)
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Choose a document (PDF)'),
                subtitle: const Text('From your files or downloads'),
                onTap: () => Navigator.pop(sheetContext, 'file'),
              ),
          ],
        ),
      ),
    );
    if (source == null || !context.mounted) return const [];

    if (source == 'file') return _pickDocument(context);

    try {
      final List<XFile> files;
      if (source == 'camera') {
        // In the browser the in-app camera opens a real live preview (the system
        // picker would only open a file chooser on a computer). On phones and
        // tablets the native camera app is used.
        final XFile? shot = kIsWeb
            ? await Navigator.of(context).push<XFile>(
                MaterialPageRoute(builder: (_) => const CameraCaptureScreen()))
            : await _picker.pickImage(
                source: ImageSource.camera,
                maxWidth: 1600,
                maxHeight: 1600,
                imageQuality: 85,
              );
        files = shot == null ? const [] : [shot];
      } else if (max > 1) {
        files = await _picker.pickMultiImage(
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 85,
          limit: max,
        );
      } else {
        final one = await _picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 85,
        );
        files = one == null ? const [] : [one];
      }

      final photos = <PhotoRef>[];
      var tooLarge = 0;
      for (final file in files.take(max)) {
        final bytes = await file.readAsBytes();
        if (bytes.length > _maxBytes) {
          tooLarge++;
          continue;
        }
        photos.add(PhotoRef(bytes: bytes, name: file.name));
      }
      if (tooLarge > 0 && context.mounted) {
        _tell(context, tooLarge == 1
            ? 'That photo is too large (max 8 MB).'
            : '$tooLarge photos were too large (max 8 MB each).');
      }
      return photos;
    } catch (_) {
      if (context.mounted) {
        _tell(
          context,
          source == 'camera'
              ? 'Couldn\'t open the camera. Check that camera access is allowed.'
              : 'Couldn\'t open your photos. Check that photo access is allowed.',
        );
      }
      return const [];
    }
  }

  /// Lets the person choose a PDF (or a picture) file from their device.
  static Future<List<PhotoRef>> _pickDocument(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return const [];
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) return const [];
      if (bytes.length > _maxBytes) {
        if (context.mounted) _tell(context, 'That file is too large (max 8 MB).');
        return const [];
      }
      return [PhotoRef(bytes: bytes, name: file.name)];
    } catch (_) {
      if (context.mounted) {
        _tell(context, 'Couldn\'t open your files. Check that file access is allowed.');
      }
      return const [];
    }
  }

  static void _tell(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(duration: const Duration(seconds: 3), content: Text(message)));
  }
}
