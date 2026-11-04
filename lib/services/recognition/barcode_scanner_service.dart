import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerService {
  /// Underlying controller that manages device camera for barcode detection.
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.qrCode,
    ],
  );

  String? _lastScannedCode;
  DateTime? _lastScanTime;

  /// Cooldown window so holding an item in front of the camera doesn't
  /// trigger 30+ identical database lookups per second.
  final Duration scanCooldown;

  BarcodeScannerService({this.scanCooldown = const Duration(seconds: 3)});

  /// Processes a raw frame event from MobileScanner and returns a valid
  /// barcode string ONLY if it passes the debounce filter.
  String? processBarcodeCapture(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue?.trim();
      if (rawValue == null || rawValue.isEmpty) continue;

      final now = DateTime.now();
      final isDuplicate =
          (rawValue == _lastScannedCode) &&
          (_lastScanTime != null) &&
          (now.difference(_lastScanTime!) < scanCooldown);

      if (isDuplicate) {
        return null; // Ignore duplicate frame within cooldown window
      }

      _lastScannedCode = rawValue;
      _lastScanTime = now;
      debugPrint('📦 Barcode locked: $rawValue (${barcode.format.name})');
      return rawValue;
    }
    return null;
  }

  /// Resets the last scanned code so the user can intentionally scan the same
  /// item twice.
  void resetCooldown() {
    _lastScannedCode = null;
    _lastScanTime = null;
  }

  void dispose() {
    controller.dispose();
  }
}
