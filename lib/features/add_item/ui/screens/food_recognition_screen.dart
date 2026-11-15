import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../models/produce_scan_result.dart';
import '../../../../services/recognition/recognition_providers.dart';
import '../../../inventory/data/services/expiry_est_service.dart';
import '../../../inventory/ui/providers/inventory_provider.dart';
import '../widgets/item_confirmation_form.dart';

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
  final _form = ItemFormController();
  final _expiryService = ExpiryEstService();

  _ScanPhase _phase = _ScanPhase.start;
  _ScanError _error = _ScanError.recognition;
  bool _lastFromCamera = true;

  /// User opt-in: when on, every scan goes to Gemini Cloud for ripeness and
  /// spoilage days. When off, a confident on-device result returns instantly.
  bool _requireRipeness = false;
  ProduceScanResult? _result;
  String? _selectedChoice;

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
          .scanProduce(bytes, requireRipeness: _requireRipeness);
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
      _phase = _ScanPhase.form;
    });
    _form.prefill(
      itemName: result.itemName,
      expiry: _expiryFor(result.itemName),
    );
  }

  /// Uses the scan's own spoilage estimate for the item it recognized; any
  /// other name (an alternative chip) falls back to [ExpiryEstService].
  DateTime _expiryFor(String name) {
    final days = _result?.estDaysUntilSpoil;
    if (days != null && name == _result?.itemName) {
      return ItemFormController.today.add(Duration(days: days < 0 ? 0 : days));
    }
    return _expiryService.estimateExpiry(name);
  }

  List<String> get _choices {
    final result = _result;
    if (result == null) return const [];
    return {result.itemName, ...result.alternatives}.toList();
  }

  void _selectChoice(String choice) {
    setState(() => _selectedChoice = choice);
    _form
      ..setName(choice)
      ..setExpiry(_expiryFor(choice));
  }

  void _save() {
    final item = _form.buildItem();
    if (item == null) return;
    ref.read(inventoryProvider.notifier).addItem(item);
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
            const SizedBox(height: 16),
            SwitchListTile(
              key: const Key('requireRipenessSwitch'),
              value: _requireRipeness,
              onChanged: (value) => setState(() => _requireRipeness = value),
              title: const Text('Check ripeness & spoilage'),
              subtitle: const Text(
                'Sends the photo to Gemini (cloud) to estimate ripeness and '
                'days until it spoils. Needs internet and takes a few '
                'seconds longer.',
              ),
            ),
            const SizedBox(height: 16),
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            _requireRipeness
                ? 'Checking ripeness with Gemini…'
                : 'Identifying your produce…',
          ),
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

    return ItemConfirmationForm(
      controller: _form,
      onSave: _save,
      onNameChanged: (value) => setState(() => _selectedChoice = value),
      header: [
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
      ],
      details: [
        Text('Category: ${result.category}'),
        Text(
          result.source == ScanSource.geminiCloud
              ? 'Identified with Gemini'
              : 'Identified on device',
          key: const Key('scanSourceText'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (result.ripeness != null) Text('Ripeness: ${result.ripeness}'),
      ],
      footer: [
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
    );
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }
}
