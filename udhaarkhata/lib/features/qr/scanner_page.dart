import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../app/app_strings.dart';
import '../../app/status_page.dart';
import '../../core/network/contracts.dart';
import '../../core/network/app_failure.dart';
import '../auth/session_controller.dart';
import 'owner_link_repository.dart';
import 'resolve_controller.dart';
import 'link_confirm_page.dart';

class ScannerPage extends ConsumerStatefulWidget {
  const ScannerPage({super.key, required this.shopId});
  final OpaqueId shopId;
  @override
  ConsumerState<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends ConsumerState<ScannerPage> {
  ResolveController? _controller;
  bool _navigating = false;
  @override
  void initState() {
    super.initState();
    final repo = ref.read(ownerLinkRepositoryProvider);
    if (repo != null) {
      _controller = ResolveController(repo, widget.shopId)
        ..addListener(_changed);
      _controller!.initialize();
    }
  }

  void _changed() {
    if (!mounted) return;
    final state = _controller!;
    if (!identical(state.repository, ref.read(ownerLinkRepositoryProvider))) {
      return;
    }
    if (state.error is AppFailure &&
        (state.error as AppFailure).code == 'AUTH_REQUIRED') {
      ref.invalidate(sessionProvider);
    }
    if (state.stage == ScanStage.linked && !_navigating) {
      _navigating = true;
      ref.invalidate(customerLinksProvider(widget.shopId.value));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            identical(
              state.repository,
              ref.read(ownerLinkRepositoryProvider),
            )) {
          context.pushReplacement(
            '/owner/customer/${widget.shopId.value}/${state.link!.id.value}',
          );
        }
      });
    }
    setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(ownerLinkRepositoryProvider), state = _controller;
    return Scaffold(
      appBar: AppBar(title: const Text('Scan customer QR')),
      body: SafeArea(
        child: state == null || !identical(repo, state.repository)
            ? const StatusPage(
                title: 'Please sign in',
                message: 'Open your shop again to scan a customer.',
              )
            : switch (state.stage) {
                ScanStage.loading => const StatusPage(
                  title: 'Checking previous request',
                  message: 'Please wait.',
                  loading: true,
                ),
                ScanStage.resolving => const StatusPage(
                  title: 'Finding customer',
                  message: 'Checking this QR online.',
                  loading: true,
                ),
                ScanStage.ready => Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Scan the customer’s Udhaar Khata QR. Internet is needed to identify and add customers.',
                      ),
                    ),
                    Expanded(child: _Camera(onScan: state.scan)),
                  ],
                ),
                ScanStage.confirm ||
                ScanStage.saving ||
                ScanStage.recovery => LinkConfirmation(controller: state),
                ScanStage.linked => const StatusPage(
                  title: 'Opening customer',
                  message: 'Please wait.',
                  loading: true,
                ),
                ScanStage.failed => SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Could not open customer',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          errorMessage(
                            state.error is AppFailure
                                ? (state.error as AppFailure).messageKey
                                : 'link.failed',
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: state.retry,
                        child: const Text('Try again'),
                      ),
                      if (state.attempt == null)
                        TextButton(
                          onPressed: state.rescan,
                          child: const Text('Scan another QR'),
                        ),
                    ],
                  ),
                ),
              },
      ),
    );
  }
}

class _Camera extends StatefulWidget {
  const _Camera({required this.onScan});
  final Future<void> Function(String) onScan;
  @override
  State<_Camera> createState() => _CameraState();
}

class _CameraState extends State<_Camera> with WidgetsBindingObserver {
  // The plugin owns one native camera. Serialize operations across widget instances,
  // including teardown after navigation and initialization of the next scanner.
  static Future<void>? _nativeQueue;
  static Future<void> _native(Future<void> Function() operation) {
    final before = _nativeQueue;
    final result = before == null
        ? Future<void>.sync(operation)
        : before.then((_) => operation());
    late final Future<void> tail;
    void finished() {
      if (identical(_nativeQueue, tail)) _nativeQueue = null;
    }

    tail = result.then<void>(
      (_) => finished(),
      onError: (Object _, StackTrace _) => finished(),
    );
    _nativeQueue = tail;
    return result;
  }

  MobileScannerController _camera = MobileScannerController(
    formats: [BarcodeFormat.qrCode],
    autoStart: false,
  );
  int _generation = 0;
  bool _detected = false;
  bool _restarting = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleStart();
  }

  void _scheduleStart() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final camera = _camera;
      unawaited(
        _native(() async {
          if (mounted && identical(camera, _camera) && !_restarting) {
            await camera.start();
          }
        }).catchError((Object _) {}),
      );
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_camera.value.hasCameraPermission) return;
    if (state == AppLifecycleState.resumed) {
      _scheduleStart();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      final camera = _camera;
      unawaited(_native(camera.stop).catchError((Object _) {}));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final camera = _camera;
    unawaited(_native(camera.dispose).catchError((Object _) {}));
    super.dispose();
  }

  Future<void> _retry() async {
    if (_restarting) return;
    setState(() => _restarting = true);
    final old = _camera;
    await _native(old.dispose);
    if (!mounted) return;
    setState(() {
      _camera = MobileScannerController(
        formats: [BarcodeFormat.qrCode],
        autoStart: false,
      );
      _generation++;
      _detected = false;
      _restarting = false;
    });
    _scheduleStart();
  }

  Future<void> _settings() async {
    try {
      await const MethodChannel('com.udhaarkhata.app/settings')
          .invokeMethod<void>('openSettings');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Open Android Settings, then Apps, Udhaar Khata, Permissions to allow Camera.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Customer QR camera scanner',
    child: MobileScanner(
      key: ValueKey(_generation),
      controller: _camera,
      onDetect: (capture) {
        if (_detected) return;
        final values = capture.barcodes
            .where(
              (b) => b.format == BarcodeFormat.qrCode && b.rawValue != null,
            )
            .toList();
        if (values.isEmpty) return;
        _detected = true;
        widget.onScan(values.first.rawValue!);
      },
      errorBuilder: (_, error) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              error.errorCode == MobileScannerErrorCode.permissionDenied
                  ? 'Camera permission needed'
                  : 'Camera unavailable',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            const Text(
              'Allow camera access to scan a customer QR. You can change Camera permission in Android Settings.',
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _restarting ? null : _retry,
              child: const Text('Try camera again'),
            ),
            TextButton(
              onPressed: _settings,
              child: const Text('Open settings'),
            ),
          ],
        ),
      ),
    ),
  );
}
