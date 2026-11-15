import 'package:flutter/services.dart'
    show MissingPluginException, PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:smart_grocery/features/add_item/ui/screens/food_recognition_screen.dart';
import 'package:smart_grocery/features/inventory/ui/providers/inventory_provider.dart';
import 'package:smart_grocery/models/produce_scan_result.dart';
import 'package:smart_grocery/services/recognition/barcode_scanner_service.dart';
import 'package:smart_grocery/services/recognition/recognition_coordinator.dart';
import 'package:smart_grocery/services/recognition/recognition_providers.dart';

import 'fakes/fake_recognition_services.dart';

void main() {
  late FakeEdgeMlService fakeEdge;
  late FakeGeminiVisionService fakeGemini;
  late FakeImageCaptureService fakeCapture;
  late ProviderContainer container;

  setUp(() {
    fakeEdge = FakeEdgeMlService()
      ..resultToReturn = const ProduceScanResult(
        itemName: 'Banana',
        category: 'Fruit',
        confidence: 0.9,
        source: ScanSource.edgeMl,
      );
    fakeGemini = FakeGeminiVisionService();
    fakeCapture = FakeImageCaptureService();
    container = ProviderContainer(
      overrides: [
        recognitionCoordinatorProvider.overrideWithValue(
          RecognitionCoordinator(
            edgeMlService: fakeEdge,
            geminiService: fakeGemini,
            barcodeScanner: BarcodeScannerService(),
          ),
        ),
        imageCaptureProvider.overrideWithValue(fakeCapture),
      ],
    );
  });

  tearDown(() => container.dispose());

  Future<void> pumpScreen(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/ai-add-item',
      routes: [
        GoRoute(
          path: '/ai-add-item',
          builder: (_, _) => const FoodRecognitionScreen(),
        ),
        GoRoute(
          path: '/inventory',
          builder: (_, _) => const Scaffold(body: Text('INVENTORY')),
        ),
        GoRoute(
          path: '/manual-add-item',
          builder: (_, _) => const Scaffold(body: Text('MANUAL ENTRY')),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> takePhoto(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('takePhotoButton')));
    await tester.pumpAndSettle();
  }

  Future<void> enableRipeness(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('requireRipenessSwitch')));
    await tester.pumpAndSettle();
  }

  String nameFieldText(WidgetTester tester) => tester
      .widget<TextField>(find.byKey(const Key('scanNameField')))
      .controller!
      .text;

  testWidgets('ripeness is off by default: a confident on-device result is '
      'used without calling Gemini', (tester) async {
    await pumpScreen(tester);

    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const Key('requireRipenessSwitch')),
          )
          .value,
      isFalse,
    );
    expect(find.textContaining('Sends the photo to Gemini'), findsOneWidget);

    await takePhoto(tester);

    expect(fakeGemini.callCount, 0);
    expect(nameFieldText(tester), 'Banana');
    expect(find.text('Identified on device'), findsOneWidget);
    expect(find.textContaining('Ripeness:'), findsNothing);
    // No Gemini spoilage estimate -> ExpiryEstService ('banana' = 6 days).
    expect(find.text('Best used within 6 days'), findsOneWidget);
  });

  testWidgets('ripeness off still escalates to Gemini when on-device '
      'confidence is low', (tester) async {
    fakeEdge.resultToReturn = const ProduceScanResult(
      itemName: 'Lemon',
      category: 'Fruit',
      confidence: 0.4,
      source: ScanSource.edgeMl,
      needsReview: true,
    );
    fakeGemini.resultToReturn = const ProduceScanResult(
      itemName: 'Lime',
      category: 'Fruit',
      confidence: 0.9,
      source: ScanSource.geminiCloud,
    );

    await pumpScreen(tester);
    await takePhoto(tester);

    expect(fakeGemini.callCount, 1);
    expect(nameFieldText(tester), 'Lime');
    expect(find.text('Identified with Gemini'), findsOneWidget);
  });

  testWidgets('confident scan pre-fills name, ripeness and expiry', (
    tester,
  ) async {
    fakeGemini.resultToReturn = const ProduceScanResult(
      itemName: 'Banana',
      category: 'Fruit',
      confidence: 0.95,
      source: ScanSource.geminiCloud,
      ripeness: 'Ripe',
      estDaysUntilSpoil: 4,
    );

    await pumpScreen(tester);
    await enableRipeness(tester);
    await takePhoto(tester);

    expect(fakeCapture.calls, [true]);
    expect(fakeGemini.callCount, 1); // ripeness switch on -> always Gemini
    expect(nameFieldText(tester), 'Banana');
    expect(find.text('Category: Fruit'), findsOneWidget);
    expect(find.text('Ripeness: Ripe'), findsOneWidget);
    expect(find.text('Best used within 4 days'), findsOneWidget);
    expect(find.byKey(const Key('needsReviewBanner')), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);
  });

  testWidgets('uncertain scan shows alternative chips; tapping one updates '
      'the name and re-estimates expiry', (tester) async {
    fakeGemini.resultToReturn = const ProduceScanResult(
      itemName: 'Banana',
      category: 'Fruit',
      confidence: 0.5,
      source: ScanSource.geminiCloud,
      estDaysUntilSpoil: 4,
      alternatives: ['Plantain', 'Banana'],
      needsReview: true,
    );

    await pumpScreen(tester);
    await enableRipeness(tester);
    await takePhoto(tester);

    expect(find.byKey(const Key('needsReviewBanner')), findsOneWidget);
    // Duplicate alternative ('Banana') is collapsed into the top guess.
    expect(find.byType(ChoiceChip), findsNWidgets(2));

    await tester.tap(find.widgetWithText(ChoiceChip, 'Plantain'));
    await tester.pumpAndSettle();

    expect(nameFieldText(tester), 'Plantain');
    // 'plantain' is not in ExpiryEstService's table -> 7-day default.
    expect(find.text('Best used within 7 days'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Banana'));
    await tester.pumpAndSettle();
    expect(find.text('Best used within 4 days'), findsOneWidget);
  });

  testWidgets('failed scan shows error with retry and manual entry', (
    tester,
  ) async {
    fakeEdge
      ..resultToReturn = null
      ..errorToThrow = Exception('tflite failed');
    fakeGemini.errorToThrow = Exception('offline');

    await pumpScreen(tester);
    await takePhoto(tester);

    expect(find.byKey(const Key('tryAgainButton')), findsOneWidget);

    await tester.tap(find.byKey(const Key('tryAgainButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('takePhotoButton')), findsOneWidget);

    await takePhoto(tester);
    await tester.tap(find.byKey(const Key('enterManuallyButton')));
    await tester.pumpAndSettle();
    expect(find.text('MANUAL ENTRY'), findsOneWidget);
  });

  String errorText(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('scanErrorText'))).data!;

  testWidgets('denied camera permission shows a Settings message, not a '
      'recognition error', (tester) async {
    fakeCapture.errorToThrow = PlatformException(
      code: 'camera_access_denied',
      message: 'The user did not allow camera access.',
    );

    await pumpScreen(tester);
    await takePhoto(tester);

    expect(errorText(tester), contains('Camera access is turned off'));
    expect(errorText(tester), contains('Settings'));
    expect(fakeGemini.callCount, 0);
    expect(find.byKey(const Key('enterManuallyButton')), findsOneWidget);
  });

  testWidgets('other camera failures show a camera-specific message', (
    tester,
  ) async {
    fakeCapture.errorToThrow = MissingPluginException('no image_picker');

    await pumpScreen(tester);
    await takePhoto(tester);

    expect(errorText(tester), startsWith("Couldn't open the camera"));
    expect(fakeGemini.callCount, 0);
  });

  testWidgets('recognition failure keeps the "couldn\'t identify" message', (
    tester,
  ) async {
    fakeEdge
      ..resultToReturn = null
      ..errorToThrow = Exception('tflite failed');
    fakeGemini.errorToThrow = Exception('offline');

    await pumpScreen(tester);
    await takePhoto(tester);

    expect(errorText(tester), startsWith("We couldn't identify that item"));
  });

  testWidgets('Retake photo opens the camera directly and rescans', (
    tester,
  ) async {
    fakeGemini.resultToReturn = const ProduceScanResult(
      itemName: 'Banana',
      category: 'Fruit',
      confidence: 0.95,
      source: ScanSource.geminiCloud,
      estDaysUntilSpoil: 4,
    );

    await pumpScreen(tester);
    await enableRipeness(tester);
    await takePhoto(tester);
    expect(nameFieldText(tester), 'Banana');

    fakeGemini.resultToReturn = const ProduceScanResult(
      itemName: 'Lemon',
      category: 'Fruit',
      confidence: 0.95,
      source: ScanSource.geminiCloud,
      estDaysUntilSpoil: 14,
    );
    final retake = find.byKey(const Key('retakeButton'));
    await tester.ensureVisible(retake);
    await tester.tap(retake);
    await tester.pumpAndSettle();

    expect(fakeCapture.calls, [true, true]); // camera both times
    expect(find.byKey(const Key('takePhotoButton')), findsNothing);
    expect(nameFieldText(tester), 'Lemon');
  });

  testWidgets('cancelling a retake keeps the current result', (tester) async {
    fakeGemini.resultToReturn = const ProduceScanResult(
      itemName: 'Banana',
      category: 'Fruit',
      confidence: 0.95,
      source: ScanSource.geminiCloud,
      estDaysUntilSpoil: 4,
    );

    await pumpScreen(tester);
    await enableRipeness(tester);
    await takePhoto(tester);

    fakeCapture.bytesToReturn = null;
    final retake = find.byKey(const Key('retakeButton'));
    await tester.ensureVisible(retake);
    await tester.tap(retake);
    await tester.pumpAndSettle();

    expect(nameFieldText(tester), 'Banana');
    expect(fakeGemini.callCount, 1);
  });

  testWidgets('cancelling the camera stays on the start screen', (
    tester,
  ) async {
    fakeCapture.bytesToReturn = null;

    await pumpScreen(tester);
    await takePhoto(tester);

    expect(find.byKey(const Key('takePhotoButton')), findsOneWidget);
    expect(fakeGemini.callCount, 0);
  });

  testWidgets('saving adds the item to inventory and returns to /inventory', (
    tester,
  ) async {
    fakeGemini.resultToReturn = const ProduceScanResult(
      itemName: 'Banana',
      category: 'Fruit',
      confidence: 0.95,
      source: ScanSource.geminiCloud,
      estDaysUntilSpoil: 4,
    );
    final before = container.read(inventoryProvider).length;

    await pumpScreen(tester);
    await enableRipeness(tester);
    await takePhoto(tester);

    await tester.enterText(find.byKey(const Key('scanQuantityField')), '3');
    final save = find.byKey(const Key('saveScannedItemButton'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    final items = container.read(inventoryProvider);
    expect(items.length, before + 1);
    expect(items.last.name, 'Banana');
    expect(items.last.quantity, 3);
    expect(items.last.daysLeft, 4);
    expect(find.text('INVENTORY'), findsOneWidget);
  });
}
