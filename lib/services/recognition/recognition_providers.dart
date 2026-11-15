import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'recognition_coordinator.dart';

/// App-wide [RecognitionCoordinator]. Kept alive for the session so the
/// TFLite interpreter is only loaded once; disposed with the ProviderScope.
final recognitionCoordinatorProvider = Provider<RecognitionCoordinator>((ref) {
  final coordinator = RecognitionCoordinator();
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

/// Source of photo bytes for produce recognition. Abstracted so widget tests
/// can supply fake bytes and so an in-app `camera` implementation can replace
/// [ImagePickerCaptureService] later without touching the screens.
abstract class ImageCaptureService {
  /// Returns JPEG bytes, or `null` if the user cancelled.
  Future<Uint8List?> capture({required bool fromCamera});
}

class ImagePickerCaptureService implements ImageCaptureService {
  ImagePickerCaptureService({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<Uint8List?> capture({required bool fromCamera}) async {
    // Downsize natively at capture time: a full 12 MP Pixel photo would make
    // the Edge ML isolate decode much slower, and Gemini only needs 512 px.
    final file = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    return file?.readAsBytes();
  }
}

final imageCaptureProvider = Provider<ImageCaptureService>(
  (ref) => ImagePickerCaptureService(),
);
