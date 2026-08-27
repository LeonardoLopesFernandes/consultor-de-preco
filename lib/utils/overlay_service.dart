import 'package:flutter/services.dart';

/// Comunica com o serviço de bolinha flutuante nativo (substitui FloatingButtonService).
class OverlayService {
  static const MethodChannel _channel =
      MethodChannel('io.amer.scanner/overlay');

  static Future<void> openPermission() async {
    try {
      await _channel.invokeMethod('openPermission');
    } catch (_) {}
  }

  static Future<void> start() async {
    try {
      await _channel.invokeMethod('startOverlay');
    } catch (_) {}
  }

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod('stopOverlay');
    } catch (_) {}
  }
}
