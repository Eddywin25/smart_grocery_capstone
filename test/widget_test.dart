import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:smart_grocery/models/produce_scan_result.dart';
import 'package:smart_grocery/services/recognition/barcode_scanner_service.dart';
import 'package:smart_grocery/services/recognition/recognition_coordinator.dart';

import 'fakes/fake_recognition_services.dart';

void main() {
  group('ProduceScanResult Serialization & Normalization', () {
    test(
      'normalizes N/A ripeness to null and computes needsReview from threshold',
      () {
        final result = ProduceScanResult.fromJson(
          {
            'itemName': 'Apple',
            'category': 'Fruit',
            'confidence': 0.65,
            'ripeness': 'N/A',
            'estDaysUntilSpoil': 7,
            'alternatives': ['Pear', 'Peach'],
          },
          source: ScanSource.geminiCloud,
          confidenceThreshold: 0.75,
        );

        expect(result.itemName, 'Apple');
        expect(result.ripeness, isNull);
        expect(result.source, ScanSource.geminiCloud);
        expect(result.needsReview, isTrue);

        final roundTrip = ProduceScanResult.fromJson(result.toJson());
        expect(roundTrip.itemName, 'Apple');
        expect(roundTrip.needsReview, isTrue);
      },
    );
  });

  group('BarcodeScannerService Debounce Cooldown', () {
    test(
      'blocks duplicate barcode within cooldown window and allows new barcode',
      () {
        final service = BarcodeScannerService(
          scanCooldown: const Duration(seconds: 3),
        );

        const captureA = BarcodeCapture(
          barcodes: [
            Barcode(rawValue: '012345678905', format: BarcodeFormat.upcA),
          ],
        );
        const captureB = BarcodeCapture(
          barcodes: [
            Barcode(rawValue: '987654321098', format: BarcodeFormat.ean13),
          ],
        );

        // First scan locks in
        expect(service.processBarcodeCapture(captureA), '012345678905');
        // Immediate duplicate frame is ignored
        expect(service.processBarcodeCapture(captureA), isNull);
        // Different barcode locks in immediately
        expect(service.processBarcodeCapture(captureB), '987654321098');

        // Resetting cooldown allows scanning the same barcode again
        service.resetCooldown();
        expect(service.processBarcodeCapture(captureB), '987654321098');
      },
    );
  });

  group('RecognitionCoordinator Routing & Fallback', () {
    late FakeEdgeMlService fakeEdge;
    late FakeGeminiVisionService fakeGemini;
    late RecognitionCoordinator coordinator;
    final dummyBytes = Uint8List.fromList([1, 2, 3, 4]);

    setUp(() {
      fakeEdge = FakeEdgeMlService();
      fakeGemini = FakeGeminiVisionService();
      coordinator = RecognitionCoordinator(
        edgeMlService: fakeEdge,
        geminiService: fakeGemini,
        barcodeScanner: BarcodeScannerService(),
        confidenceThreshold: 0.75,
      );
    });

    test('returns fast Edge ML result without calling Cloud when confident and ripeness not required', () async {
      fakeEdge.resultToReturn = const ProduceScanResult(
        itemName: 'Banana',
        category: 'Fruit',
        confidence: 0.95,
        source: ScanSource.edgeMl,
        needsReview: false,
      );

      final result = await coordinator.scanProduce(
        dummyBytes,
        requireRipeness: false,
      );

      expect(result.source, ScanSource.edgeMl);
      expect(result.itemName, 'Banana');
      expect(fakeGemini.callCount, 0);
    });

    test('escalates to Gemini Cloud when requireRipeness is true', () async {
      fakeEdge.resultToReturn = const ProduceScanResult(
        itemName: 'Banana',
        category: 'Fruit',
        confidence: 0.99,
        source: ScanSource.edgeMl,
      );
      fakeGemini.resultToReturn = const ProduceScanResult(
        itemName: 'Cavendish Banana',
        category: 'Fruit',
        confidence: 0.98,
        source: ScanSource.geminiCloud,
        ripeness: 'Ripe',
        estDaysUntilSpoil: 4,
      );

      final result = await coordinator.scanProduce(
        dummyBytes,
        requireRipeness: true,
      );

      expect(result.source, ScanSource.geminiCloud);
      expect(result.ripeness, 'Ripe');
      expect(fakeGemini.callCount, 1);
    });

    test(
      'escalates to Gemini Cloud when Edge ML confidence is below threshold',
      () async {
        fakeEdge.resultToReturn = const ProduceScanResult(
          itemName: 'Apple',
          category: 'Fruit',
          confidence: 0.45,
          source: ScanSource.edgeMl,
          needsReview: true,
        );
        fakeGemini.resultToReturn = const ProduceScanResult(
          itemName: 'Honeycrisp Apple',
          category: 'Fruit',
          confidence: 0.92,
          source: ScanSource.geminiCloud,
        );

        final result = await coordinator.scanProduce(
          dummyBytes,
          requireRipeness: false,
        );

        expect(result.source, ScanSource.geminiCloud);
        expect(result.itemName, 'Honeycrisp Apple');
        expect(fakeGemini.callCount, 1);
      },
    );

    test('falls back gracefully to Edge ML with needsReview=true when Gemini Cloud fails', () async {
      fakeEdge.resultToReturn = const ProduceScanResult(
        itemName: 'Banana',
        category: 'Fruit',
        confidence: 0.95,
        source: ScanSource.edgeMl,
        needsReview: false,
      );
      fakeGemini.errorToThrow = Exception('500 Server Error');

      final result = await coordinator.scanProduce(
        dummyBytes,
        requireRipeness: true,
      );

      expect(result.source, ScanSource.edgeMl);
      expect(result.itemName, 'Banana');
      expect(result.needsReview, isTrue);
    });
  });
}
