import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/product_lookup_result.dart';
import '../auth/auth_service.dart';

/// Why a barcode lookup failed, so the UI can show a matching message.
enum BarcodeLookupError { offline, timeout, signIn, invalidBarcode, unknown }

class BarcodeLookupException implements Exception {
  const BarcodeLookupException(this.error);

  final BarcodeLookupError error;

  String get userMessage => switch (error) {
    BarcodeLookupError.offline =>
      "Couldn't reach the product database. Check your connection and try "
          'again, or enter the item manually.',
    BarcodeLookupError.timeout =>
      'The lookup took too long. Try again, or enter the item manually.',
    BarcodeLookupError.signIn =>
      "Couldn't sign in to look up products. Check your connection and try "
          'again.',
    BarcodeLookupError.invalidBarcode =>
      "That barcode doesn't look like a product code. Try scanning again.",
    BarcodeLookupError.unknown =>
      'Something went wrong looking up that product. Try again, or enter '
          'the item manually.',
  };

  @override
  String toString() => 'BarcodeLookupException($error)';
}

/// Maps a `FirebaseFunctionsException.code` from the callable to a
/// [BarcodeLookupError]. Kept separate (and public) so it can be unit-tested
/// without constructing Firebase exceptions.
@visibleForTesting
BarcodeLookupError lookupErrorForFunctionsCode(String code) => switch (code) {
  'unavailable' => BarcodeLookupError.offline,
  'deadline-exceeded' => BarcodeLookupError.timeout,
  'unauthenticated' => BarcodeLookupError.signIn,
  'invalid-argument' => BarcodeLookupError.invalidBarcode,
  _ => BarcodeLookupError.unknown,
};

abstract class BarcodeLookupService {
  /// Product barcodes the backend accepts: 8 (EAN-8/UPC-E), 12 (UPC-A) or
  /// 13 (EAN-13) digits. Mirrors `clean_barcode` in
  /// `backend/functions/barcode_lookup.py`, so QR codes etc. are rejected
  /// before any network call.
  static bool isProductBarcode(String code) =>
      RegExp(r'^(\d{8}|\d{12}|\d{13})$').hasMatch(code.trim());

  /// Throws [BarcodeLookupException] on failure. Never retries (see the
  /// quota etiquette in AGENTS.md).
  Future<ProductLookupResult> lookup(String barcode);
}

/// Calls Chris's `lookup_barcode` Firebase callable function.
class FirebaseBarcodeLookupService implements BarcodeLookupService {
  FirebaseBarcodeLookupService({
    required this._auth,
    this._functions,
  });

  static const _timeout = Duration(seconds: 15);

  final AuthService _auth;
  final FirebaseFunctions? _functions;

  @override
  Future<ProductLookupResult> lookup(String barcode) async {
    try {
      await _auth.ensureSignedIn();
    } on FirebaseAuthException catch (e) {
      debugPrint('🔑 [BarcodeLookup] Anonymous sign-in failed: ${e.code}');
      throw BarcodeLookupException(
        e.code == 'network-request-failed'
            ? BarcodeLookupError.offline
            : BarcodeLookupError.signIn,
      );
    }

    try {
      final callable = (_functions ?? FirebaseFunctions.instance).httpsCallable(
        'lookup_barcode',
        options: HttpsCallableOptions(timeout: _timeout),
      );
      final response = await callable.call<Map<Object?, Object?>>({
        'barcode': barcode.trim(),
      });
      return ProductLookupResult.fromMap(response.data);
    } on FirebaseFunctionsException catch (e) {
      debugPrint('📦 [BarcodeLookup] ${e.code}: ${e.message}');
      throw BarcodeLookupException(lookupErrorForFunctionsCode(e.code));
    } on TimeoutException {
      throw const BarcodeLookupException(BarcodeLookupError.timeout);
    } catch (e) {
      debugPrint('📦 [BarcodeLookup] Unexpected error: $e');
      throw const BarcodeLookupException(BarcodeLookupError.unknown);
    }
  }
}

final barcodeLookupServiceProvider = Provider<BarcodeLookupService>(
  (ref) => FirebaseBarcodeLookupService(auth: ref.watch(authServiceProvider)),
);
