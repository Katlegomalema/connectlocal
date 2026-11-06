import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// Opens the device camera with a live preview and a capture button, and
/// returns the picture taken (an [XFile]) or null if the person backed out.
/// Used in the browser, where the system "take a photo" picker is not available
/// on computers. On phones and tablets the native camera is used instead.
class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  List<CameraDescription> _cameras = const [];
  CameraController? _controller;
  int _index = 0;
  String? _error;
  bool _taking = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _error = 'No camera was found on this device.');
        return;
      }
      // Prefer the back camera (phones), otherwise the first one.
      final back = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
      _index = back >= 0 ? back : 0;
      await _open();
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Couldn\u2019t open the camera. Allow camera access in your browser and try again.');
      }
    }
  }

  Future<void> _open() async {
    final old = _controller;
    final next = CameraController(_cameras[_index], ResolutionPreset.high, enableAudio: false);
    _controller = next;
    if (mounted) setState(() {});
    await old?.dispose();
    try {
      await next.initialize();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Couldn\u2019t open the camera. Allow camera access in your browser and try again.');
      }
    }
  }

  Future<void> _flip() async {
    if (_cameras.length < 2) return;
    _index = (_index + 1) % _cameras.length;
    await _open();
  }

  Future<void> _shoot() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _taking) return;
    setState(() => _taking = true);
    try {
      final file = await controller.takePicture();
      if (mounted) Navigator.pop(context, file);
    } catch (_) {
      if (mounted) {
        setState(() => _taking = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(duration: Duration(seconds: 3), content: Text('Couldn\u2019t take the picture. Try again.')));
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Take a photo'),
        actions: [
          if (_cameras.length > 1)
            IconButton(
              tooltip: 'Switch camera',
              icon: const Icon(Icons.cameraswitch_outlined),
              onPressed: _flip,
            ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4)),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: Center(
                    child: ready
                        ? CameraPreview(controller)
                        : const CircularProgressIndicator(color: Colors.white),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: GestureDetector(
                      onTap: ready ? _shoot : null,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _taking ? Colors.grey : Colors.white,
                          border: Border.all(color: Colors.white54, width: 5),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
