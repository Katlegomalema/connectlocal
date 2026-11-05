import 'dart:typed_data';

import 'package:flutter/material.dart';

/// One photo in the app.
///
/// A photo the person just picked on this device has [bytes] and no [url].
/// A photo that is already stored online has a [url] and no [bytes].
///
/// BACKEND HAND-OVER: after the person saves a form, upload every photo that
/// has [bytes] (Supabase Storage), then keep the returned public URL as a
/// [PhotoRef] with only [url] set. Screens already show both kinds.
@immutable
class PhotoRef {
  final Uint8List? bytes;
  final String? url;
  final String name;

  const PhotoRef({this.bytes, this.url, this.name = ''})
      : assert(bytes != null || url != null, 'A photo needs bytes or a url');

  bool get isLocal => bytes != null;

  /// A PDF (or other non-image) document rather than a picture.
  bool get isDocument => name.toLowerCase().endsWith('.pdf');
}

/// Shows a [PhotoRef] (picked on device or loaded from a URL) with a spinner
/// while it loads and a neutral icon if it can't be shown.
class PhotoImage extends StatelessWidget {
  final PhotoRef photo;
  final double? width;
  final double? height;
  final BoxFit fit;

  const PhotoImage(
    this.photo, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  Widget _fallback() => Container(
        width: width,
        height: height,
        color: const Color(0xFFE6EEF8),
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image_outlined, color: Color(0xFF1F5FA8)),
      );

  @override
  Widget build(BuildContext context) {
    if (photo.isDocument) {
      return Container(
        width: width,
        height: height,
        color: const Color(0xFFE6EEF8),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFF1F5FA8), size: 32),
            const SizedBox(height: 4),
            Text(photo.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Color(0xFF1F5FA8))),
          ],
        ),
      );
    }
    final bytes = photo.bytes;
    if (bytes != null) {
      return Image.memory(
        bytes,
        width: width,
        height: height,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => _fallback(),
      );
    }
    return Image.network(
      photo.url!,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, _, _) => _fallback(),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          width: width,
          height: height,
          color: const Color(0xFFF3F4F6),
          alignment: Alignment.center,
          child: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
    );
  }
}
