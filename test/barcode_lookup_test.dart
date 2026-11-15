import 'package:flutter_test/flutter_test.dart';
import 'package:smart_grocery/models/product_lookup_result.dart';
import 'package:smart_grocery/services/barcode/barcode_lookup_service.dart';

void main() {
  group('ProductLookupResult.fromMap', () {
    test(
      'parses a found product (Map<Object?, Object?> as Firebase sends)',
      () {
        final Map<Object?, Object?> data = {
          'barcode': '3017620422003',
          'name': 'Nutella',
          'brand': 'Ferrero',
          'category': 'Other',
          'imageUrl': 'https://example.com/n.jpg',
          'shelfLifeDays': 180,
          'fetchedAt': '2026-11-15T21:30:00+00:00',
        };

        final result = ProductLookupResult.fromMap(data);

        expect(result.notFound, isFalse);
        expect(result.barcode, '3017620422003');
        expect(result.name, 'Nutella');
        expect(result.brand, 'Ferrero');
        expect(result.category, 'Other');
        expect(result.shelfLifeDays, 180);
      },
    );

    test('parses a notFound record', () {
      final result = ProductLookupResult.fromMap({
        'barcode': '0000000000000',
        'notFound': true,
        'fetchedAt': '2026-11-15T21:30:00+00:00',
      });

      expect(result.notFound, isTrue);
      expect(result.name, isNull);
      expect(result.shelfLifeDays, isNull);
    });

    test('treats blank strings as missing and tolerates double numbers', () {
      final result = ProductLookupResult.fromMap({
        'barcode': '012345678905',
        'name': '  ',
        'brand': '',
        'shelfLifeDays': 7.0,
      });

      expect(result.name, isNull);
      expect(result.brand, isNull);
      expect(result.shelfLifeDays, 7);
    });
  });

  group('lookupErrorForFunctionsCode', () {
    test('maps backend error codes to user-facing errors', () {
      expect(
        lookupErrorForFunctionsCode('unavailable'),
        BarcodeLookupError.offline,
      );
      expect(
        lookupErrorForFunctionsCode('deadline-exceeded'),
        BarcodeLookupError.timeout,
      );
      expect(
        lookupErrorForFunctionsCode('unauthenticated'),
        BarcodeLookupError.signIn,
      );
      expect(
        lookupErrorForFunctionsCode('invalid-argument'),
        BarcodeLookupError.invalidBarcode,
      );
      expect(
        lookupErrorForFunctionsCode('internal'),
        BarcodeLookupError.unknown,
      );
    });

    test('every error has a non-empty user message', () {
      for (final error in BarcodeLookupError.values) {
        expect(BarcodeLookupException(error).userMessage, isNotEmpty);
      }
    });
  });

  group('BarcodeLookupService.isProductBarcode', () {
    test('accepts 8, 12 and 13 digit codes (matches clean_barcode)', () {
      expect(BarcodeLookupService.isProductBarcode('12345670'), isTrue);
      expect(BarcodeLookupService.isProductBarcode('012345678905'), isTrue);
      expect(BarcodeLookupService.isProductBarcode('3017620422003'), isTrue);
      expect(BarcodeLookupService.isProductBarcode(' 012345678905 '), isTrue);
    });

    test('rejects QR text and other lengths', () {
      expect(
        BarcodeLookupService.isProductBarcode('https://example.com'),
        isFalse,
      );
      expect(BarcodeLookupService.isProductBarcode('1234567'), isFalse);
      expect(BarcodeLookupService.isProductBarcode('12345678901'), isFalse);
      expect(BarcodeLookupService.isProductBarcode('01234567890a'), isFalse);
    });
  });
}
