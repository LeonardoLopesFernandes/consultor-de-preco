import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/icons.dart';

/// Equivalente a io.amer.scanner.BarcodeScannerActivity (scanner nativo).
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  late MobileScannerController _controller;
  bool _torchOn = false;
  double _zoom = 1.0;
  final double _minZoom = 1.0;
  final double _maxZoom = 3.0;
  final double _zoomStep = 0.5;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      facing: CameraLensDirection.back,
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
    _requestCamera();
  }

  Future<void> _requestCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Câmera necessária')),
      );
      Navigator.pop(context);
    }
  }

  void _toggleTorch() {
    _controller.toggleTorch();
    setState(() => _torchOn = !_torchOn);
  }

  void _toggleZoom() {
    double next = _zoom + _zoomStep;
    if (next > _maxZoom) next = _minZoom;
    _zoom = next;
    _controller.setZoomScale(_zoom);
    setState(() {});
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              String? raw;
              for (final b in capture.barcodes) {
                if (b.rawValue != null) {
                  raw = b.rawValue;
                  break;
                }
              }
              if (raw != null && raw.isNotEmpty && mounted) {
                Navigator.pop(context, raw);
              }
            },
          ),
          Positioned(
            top: 16,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: IconButton(
              icon: AppIcons.asset(AppIcons.zoom, size: 28, color: Colors.white),
              onPressed: _toggleZoom,
            ),
          ),
          Positioned(
            top: 80,
            right: 16,
            child: IconButton(
              icon: AppIcons.asset(
                _torchOn ? AppIcons.flashOn : AppIcons.flashOff,
                size: 28,
                color: Colors.white,
              ),
              onPressed: _toggleTorch,
            ),
          ),
          Positioned(
            top: 80,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(4),
                color: const Color(0x80000000),
                child: Text(_zoom == _minZoom ? 'Zoom normal' : 'Zoom ${_zoom.toStringAsFixed(1)}x',
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ),
          ),
          const Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Text('Código de barras / QR Code',
                  style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ),
          const Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: Text('posicione o código no centro',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
