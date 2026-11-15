import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../models/produce_scan_result.dart';
import '../../../../services/recognition/recognition_providers.dart';
import '../../../inventory/data/services/expiry_est_service.dart';
import '../../../inventory/domain/models/inventory_item.dart';
import '../../../inventory/ui/providers/inventory_provider.dart';

enum _ScanPhase { start, loading, form, error }

/// Why the error screen is showing, so the message matches the failure.
enum _ScanError { cameraPermission, camera, recognition }

/// Screen for adding produce by photo. Uses the hybrid
/// [RecognitionCoordinator] (Edge ML -> Gemini Cloud) and lets the user
/// confirm or correct the result before saving it to inventory.
class FoodRecognitionScreen extends ConsumerStatefulWidget {
  const FoodRecognitionScreen({super.key});

  @override
  ConsumerState<FoodRecognitionScreen> createState() =>
      _FoodRecognitionScreenState();
}

class _FoodRecognitionScreenState extends ConsumerState<FoodRecognitionScreen> {
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _expiryService = ExpiryEstService();

  _ScanPhase _phase = _ScanPhase.start;
  _ScanError _error = _ScanError.recognition;
  bool _lastFromCamera = true;
  ProduceScanResult? _result;
  String? _selectedChoice;
  DateTime? _expiryDate;
  StorageLocation _location = StorageLocation.fridge;
  Package _package = Package.item;
  bool _nameError = false;
  bool _quantityError = false;

  static DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  // ---------------------------------------------------------------------------
  // Capture + recognition
  // ---------------------------------------------------------------------------

  Future<void> _captureAndScan({required bool fromCamera}) async {
    _lastFromCamera = fromCamera;
    final Uint8List? bytes;
    try {
      bytes = await ref
          .read(imageCaptureProvider)
          .capture(fromCamera: fromCamera);
    } catch (e) {
      debugPrint('📷 [FoodRecognition] Capture failed: $e');
      if (!mounted) return;
      setState(() {
        _error = _isPermissionDenied(e)
            ? _ScanError.cameraPermission
            : _ScanError.camera;
        _phase = _ScanPhase.error;
      });
      return;
    }
    // User cancelled: stay where we are (start screen, or the previous result
    // when retaking).
    if (bytes == null || !mounted) return;

    setState(() => _phase = _ScanPhase.loading);

    try {
      final result = await ref
          .read(recognitionCoordinatorProvider)
          .scanProduce(bytes, requireRipeness: true);
      if (!mounted) return;
      _applyResult(result);
    } catch (e) {
      debugPrint('❌ [FoodRecognition] Recognition failed: $e');
      if (!mounted) return;
      setState(() {
        _error = _ScanError.recognition;
        _phase = _ScanPhase.error;
      });
    }
  }

  /// image_picker reports a denied camera/photo permission with these codes.
  static bool _isPermissionDenied(Object e) =>
      e is PlatformException &&
      (e.code == 'camera_access_denied' || e.code == 'photo_access_denied');

  void _applyResult(ProduceScanResult result) {
    setState(() {
      _result = result;
      _selectedChoice = result.itemName;
      _nameController.text = result.itemName;
      _expiryDate = _expiryFor(result.itemName);
      _nameError = false;
      _quantityError = false;
      _phase = _ScanPhase.form;
    });
  }

  /// Uses the scan's own spoilage estimate for the item it recognized; any
  /// other name (an alternative chip) falls back to [ExpiryEstService].
  DateTime _expiryFor(String name) {
    final days = _result?.estDaysUntilSpoil;
    if (days != null && name == _result?.itemName) {
      return _today.add(Duration(days: days < 0 ? 0 : days));
    }
    return _dateOnly(_expiryService.estimateExpiry(name));
  }

  List<String> get _choices {
    final result = _result;
    if (result == null) return const [];
    return {result.itemName, ...result.alternatives}.toList();
  }

  void _selectChoice(String choice) {
    setState(() {
      _selectedChoice = choice;
      _nameController.text = choice;
      _expiryDate = _expiryFor(choice);
      _nameError = false;
    });
  }

  Future<void> _pickExpiryDate() async {
    final first = _today;
    final last = first.add(const Duration(days: 365));
    var initial = _expiryDate ?? first;
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked == null || !mounted) return;
    setState(() => _expiryDate = _dateOnly(picked));
  }

  void _save() {
    final name = _nameController.text.trim();
    final quantity = int.tryParse(_quantityController.text.trim());

    setState(() {
      _nameError = name.isEmpty;
      _quantityError = quantity == null || quantity <= 0;
    });
    if (_nameError || _quantityError || _expiryDate == null) return;

    final now = DateTime.now();
    ref
        .read(inventoryProvider.notifier)
        .addItem(
          InventoryItem(
            id: now.millisecondsSinceEpoch.toString(),
            name: name,
            quantity: quantity!,
            location: _location,
            purchaseDate: now,
            expiryDate: _expiryDate!,
            packageType: _package,
          ),
        );
    context.go('/inventory');
  }

  void _restart() => setState(() => _phase = _ScanPhase.start);

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recognize Food')),
      body: switch (_phase) {
        _ScanPhase.start => _buildStart(),
        _ScanPhase.loading => _buildLoading(),
        _ScanPhase.form => _buildForm(),
        _ScanPhase.error => _buildError(),
      },
    );
  }

  Widget _buildStart() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.eco, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            const Text(
              'Take a photo of a fruit or vegetable to identify it.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const Key('takePhotoButton'),
              onPressed: () => _captureAndScan(fromCamera: true),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Take Photo'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('galleryButton'),
              onPressed: () => _captureAndScan(fromCamera: false),
              icon: const Icon(Icons.photo_library),
              label: const Text('Choose from Gallery'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Identifying your produce…'),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _error == _ScanError.recognition
                  ? Icons.error_outline
                  : Icons.no_photography,
              size: 56,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              switch (_error) {
                _ScanError.cameraPermission =>
                  'Camera access is turned off. Allow camera access for '
                      'Smart Grocery in your phone\'s Settings, then try '
                      'again, or enter the item manually.',
                _ScanError.camera =>
                  "Couldn't open the camera. Try again, choose a photo from "
                      'your gallery, or enter the item manually.',
                _ScanError.recognition =>
                  "We couldn't identify that item. Check your connection "
                      'and try again, or enter it manually.',
              },
              key: const Key('scanErrorText'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('tryAgainButton'),
              onPressed: _restart,
              child: const Text('Try again'),
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
    final result = _result!;
    final expiry = _expiryDate;
    final daysLeft = expiry?.difference(_today).inDays;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (result.needsReview) ...[
            Container(
              key: const Key('needsReviewBanner'),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Not sure about this one. Tap the correct item or edit the name.',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final choice in _choices)
                  ChoiceChip(
                    label: Text(choice),
                    selected: _selectedChoice == choice,
                    onSelected: (_) => _selectChoice(choice),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          TextField(
            key: const Key('scanNameField'),
            controller: _nameController,
            onChanged: (value) => setState(() => _selectedChoice = value),
            decoration: InputDecoration(
              labelText: 'Item Name',
              border: const OutlineInputBorder(),
              errorText: _nameError ? 'Item name is required' : null,
            ),
          ),
          const SizedBox(height: 12),

          Text('Category: ${result.category}'),
          if (result.ripeness != null) Text('Ripeness: ${result.ripeness}'),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: Text(
                  daysLeft == null
                      ? 'Expiry date required'
                      : 'Best used within $daysLeft '
                            '${daysLeft == 1 ? 'day' : 'days'}',
                  key: const Key('bestUsedWithinText'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              TextButton.icon(
                onPressed: _pickExpiryDate,
                icon: const Icon(Icons.calendar_month),
                label: Text(
                  expiry == null
                      ? 'Set date'
                      : '${expiry.month}/${expiry.day}/${expiry.year}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          TextField(
            key: const Key('scanQuantityField'),
            controller: _quantityController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Quantity',
              border: const OutlineInputBorder(),
              errorText: _quantityError ? 'A valid quantity is required' : null,
            ),
          ),
          const SizedBox(height: 16),

          const Text('Package Type'),
          DropdownButton<Package>(
            value: _package,
            isExpanded: true,
            items: [
              for (final p in Package.values)
                DropdownMenuItem(value: p, child: Text(p.name)),
            ],
            onChanged: (v) => setState(() => _package = v!),
          ),
          const SizedBox(height: 16),

          const Text('Storage Location'),
          DropdownButton<StorageLocation>(
            value: _location,
            isExpanded: true,
            items: [
              for (final l in StorageLocation.values)
                DropdownMenuItem(value: l, child: Text(l.name)),
            ],
            onChanged: (v) => setState(() => _location = v!),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: const Key('saveScannedItemButton'),
              onPressed: _save,
              child: const Text('Save Item'),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              key: const Key('retakeButton'),
              onPressed: () => _captureAndScan(fromCamera: _lastFromCamera),
              icon: const Icon(Icons.refresh),
              label: Text(
                _lastFromCamera ? 'Retake photo' : 'Choose another photo',
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }
}
