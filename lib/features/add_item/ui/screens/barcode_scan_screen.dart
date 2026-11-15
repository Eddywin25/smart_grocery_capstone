import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../models/product_lookup_result.dart';
import '../../../../services/barcode/barcode_lookup_service.dart';
import '../../../inventory/data/services/expiry_est_service.dart';
import '../../../inventory/ui/providers/inventory_provider.dart';
import '../widgets/item_confirmation_form.dart';
import '../widgets/live_barcode_camera.dart';

enum _BarcodePhase { scanning, loading, form, notFound, error }

/// Screen for adding a packaged item by scanning its barcode. Looks the code
/// up with the `lookup_barcode` Cloud Function and pre-fills the shared
/// confirmation form.
class BarcodeScanScreen extends ConsumerStatefulWidget {
  const BarcodeScanScreen({super.key});

  @override
  ConsumerState<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends ConsumerState<BarcodeScanScreen> {
  final _form = ItemFormController();
  final _expiryService = ExpiryEstService();

  _BarcodePhase _phase = _BarcodePhase.scanning;
  ProductLookupResult? _product;
  String? _errorMessage;

  Future<void> _onBarcode(String code) async {
    // A second frame can arrive before the camera view is torn down.
    if (_phase != _BarcodePhase.scanning) return;

    if (!BarcodeLookupService.isProductBarcode(code)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              "That's not a product barcode. Scan the barcode on the "
              'package.',
            ),
          ),
        );
      return;
    }

    // Leaving the scanning phase removes the camera view, releasing it.
    setState(() => _phase = _BarcodePhase.loading);

    try {
      final product = await ref.read(barcodeLookupServiceProvider).lookup(code);
      if (!mounted) return;

      if (product.notFound) {
        setState(() => _phase = _BarcodePhase.notFound);
        return;
      }

      final name = product.name ?? '';
      final days = product.shelfLifeDays;
      setState(() {
        _product = product;
        _phase = _BarcodePhase.form;
      });
      _form.prefill(
        itemName: name,
        expiry: days != null
            ? ItemFormController.todayPlusDays(days)
            : (name.isEmpty ? null : _expiryService.estimateExpiry(name)),
      );
    } on BarcodeLookupException catch (e) {
      debugPrint('📦 [BarcodeScan] Lookup failed: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = e.userMessage;
        _phase = _BarcodePhase.error;
      });
    }
  }

  void _scanAgain() => setState(() => _phase = _BarcodePhase.scanning);

  void _save() {
    final item = _form.buildItem();
    if (item == null) return;
    ref.read(inventoryProvider.notifier).addItem(item);
    context.go('/inventory');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Barcode')),
      body: switch (_phase) {
        _BarcodePhase.scanning => _buildScanning(),
        _BarcodePhase.loading => _buildLoading(),
        _BarcodePhase.form => _buildForm(),
        _BarcodePhase.notFound => _buildMessage(
          key: const Key('barcodeNotFoundText'),
          icon: Icons.search_off,
          message:
              "We don't have this product yet. Enter it manually, or scan "
              'another item.',
        ),
        _BarcodePhase.error => _buildMessage(
          key: const Key('barcodeErrorText'),
          icon: Icons.cloud_off,
          message: _errorMessage ?? 'Something went wrong.',
        ),
      },
    );
  }

  Widget _buildScanning() {
    final cameraView = ref.watch(barcodeCameraViewProvider);
    return Stack(
      children: [
        Positioned.fill(child: cameraView(onBarcode: _onBarcode)),
        Positioned(
          left: 16,
          right: 16,
          bottom: 24,
          child: Column(
            children: [
              const Text(
                'Point the camera at the barcode on the package.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  shadows: [Shadow(blurRadius: 4)],
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                key: const Key('enterManuallyButton'),
                onPressed: () => context.go('/manual-add-item'),
                child: const Text('Enter manually instead'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Looking up product…'),
        ],
      ),
    );
  }

  Widget _buildMessage({
    required Key key,
    required IconData icon,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey),
            const SizedBox(height: 16),
            Text(message, key: key, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('scanAgainButton'),
              onPressed: _scanAgain,
              child: const Text('Scan again'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              key: const Key('enterManuallyButton'),
              onPressed: () => context.go('/manual-add-item'),
              child: const Text('Enter manually'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    final product = _product!;
    final small = Theme.of(context).textTheme.bodySmall;

    return ItemConfirmationForm(
      controller: _form,
      onSave: _save,
      details: [
        if (product.brand != null) Text('Brand: ${product.brand}'),
        if (product.category != null) Text('Category: ${product.category}'),
        Text('Barcode: ${product.barcode}', style: small),
        if (product.shelfLifeDays != null)
          Text(
            'Expiry estimated from the product category. Adjust it if the '
            'package shows a date.',
            key: const Key('shelfLifeHintText'),
            style: small,
          ),
      ],
      footer: [
        Center(
          child: TextButton.icon(
            key: const Key('scanAnotherButton'),
            onPressed: _scanAgain,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan a different item'),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }
}
