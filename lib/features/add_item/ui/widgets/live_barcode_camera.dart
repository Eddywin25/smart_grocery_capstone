import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../services/recognition/barcode_scanner_service.dart';

/// Builds the live camera view for [BarcodeScanScreen]. It's a provider so
/// widget tests can swap in a fake view (the real one needs native camera
/// channels that don't exist in headless CI).
typedef BarcodeCameraViewBuilder = Widget Function({
  required ValueChanged<String> onBarcode,
});

final barcodeCameraViewProvider = Provider<BarcodeCameraViewBuilder>(
  (ref) =>
      ({required onBarcode}) => LiveBarcodeCamera(onBarcode: onBarcode),
);

/// Live `mobile_scanner` preview wired through [BarcodeScannerService] (with
/// its 3-second duplicate filter). The camera is released whenever this
/// widget leaves the tree, e.g. while a lookup is running.
class LiveBarcodeCamera extends StatefulWidget {
  const LiveBarcodeCamera({super.key, required this.onBarcode});

  final ValueChanged<String> onBarcode;

  @override
  State<LiveBarcodeCamera> createState() => _LiveBarcodeCameraState();
}

class _LiveBarcodeCameraState extends State<LiveBarcodeCamera> {
  final _scanner = BarcodeScannerService();

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MobileScanner(
      controller: _scanner.controller,
      onDetect: (capture) {
        final code = _scanner.processBarcodeCapture(capture);
        if (code != null) widget.onBarcode(code);
      },
      errorBuilder: (context, error) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            error.errorCode == MobileScannerErrorCode.permissionDenied
                ? 'Camera access is turned off. Allow camera access for '
                      "Smart Grocery in your phone's Settings, or enter the "
                      'item manually.'
                : "Couldn't start the camera. Go back and try again, or "
                      'enter the item manually.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
