import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ShareController {
  ShareController({
    Future<Directory> Function()? temporaryDirectory,
    Future<ShareResult> Function(ShareParams)? launch,
    bool Function()? canShare,
  }) : temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       launch = launch ?? SharePlus.instance.share,
       canShare = canShare ?? _alwaysAllowed;
  static bool _alwaysAllowed() => true;
  final bool Function() canShare;
  final Future<Directory> Function() temporaryDirectory;
  final Future<ShareResult> Function(ShareParams) launch;
  Future<void> text(String text) async {
    if (!canShare()) return;
    await launch(ShareParams(text: text));
  }

  Future<void> file(Uint8List bytes, String extension) async {
    if (!['csv', 'pdf'].contains(extension)) {
      throw ArgumentError('Unsupported export');
    }
    final parent = Directory('${(await temporaryDirectory()).path}/statements');
    await parent.create(recursive: true);
    for (final entry in parent.listSync()) {
      if (DateTime.now().difference(entry.statSync().modified) >
          const Duration(hours: 1)) {
        await entry.delete(recursive: true);
      }
    }
    final dir = await parent.createTemp('share_');
    var handedOff = false;
    try {
      final file = File('${dir.path}/statement.$extension');
      await file.writeAsBytes(bytes, flush: true);
      if (!canShare()) return;
      final result = await launch(
        ShareParams(
          files: [
            XFile(
              file.path,
              mimeType: extension == 'pdf' ? 'application/pdf' : 'text/csv',
            ),
          ],
        ),
      );
      handedOff = result.status != ShareResultStatus.dismissed;
      if (handedOff) {
        // A selected target may read asynchronously after Android closes the chooser.
        // Keep a short grace period, then delete. A crash is reaped on next share.
        Timer(const Duration(minutes: 5), () async {
          try {
            if (await dir.exists()) {
              await dir.delete(recursive: true);
            }
          } on FileSystemException {
            /* Reaped at next share if still present. */
          }
        });
      }
    } finally {
      if (!handedOff && await dir.exists()) {
        await dir.delete(recursive: true);
      }
    }
  }
}
