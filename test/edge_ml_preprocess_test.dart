import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:smart_grocery/services/recognition/edge_ml_service.dart';

void main() {
  group('preprocessImageForModel (runs in a real background isolate)', () {
    // Regression test: the isolate closure used to capture EdgeMlService
    // (and its unsendable _initFuture), which failed on device with
    // "Illegal argument in isolate message: object is unsendable".
    final jpeg = img.encodeJpg(
      img.Image(width: 40, height: 30)..clear(img.ColorRgb8(255, 255, 255)),
    );

    test('float model input is [1, 224, 224, 3] normalized to [-1, 1]', () async {
      final tensor = await preprocessImageForModel(jpeg, 224, false);

      expect(tensor.length, 1);
      expect(tensor[0].length, 224);
      expect(tensor[0][0].length, 224);
      expect(tensor[0][0][0].length, 3);
      // White pixels -> (255 - 127.5) / 127.5 = 1.0 (allow JPEG rounding).
      expect(tensor[0][112][112][0], closeTo(1.0, 0.02));
    });

    test('quantized model input keeps uint8 values', () async {
      final tensor = await preprocessImageForModel(jpeg, 224, true);

      expect(tensor[0][112][112][0], isA<int>());
      expect(tensor[0][112][112][0], greaterThan(250));
    });

    test('undecodable bytes surface as an error', () async {
      await expectLater(
        preprocessImageForModel(Uint8List.fromList([1, 2, 3]), 224, false),
        throwsA(anything),
      );
    });
  });
}
