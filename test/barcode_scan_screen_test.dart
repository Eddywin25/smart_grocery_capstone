import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:smart_grocery/features/add_item/ui/screens/barcode_scan_screen.dart';
import 'package:smart_grocery/features/add_item/ui/widgets/live_barcode_camera.dart';
import 'package:smart_grocery/features/inventory/ui/providers/inventory_provider.dart';
import 'package:smart_grocery/models/product_lookup_result.dart';
import 'package:smart_grocery/services/barcode/barcode_lookup_service.dart';

import 'fakes/fake_recognition_services.dart';

void main() {
  late FakeBarcodeLookupService fakeLookup;
  late ProviderContainer container;

  /// The code the fake camera "scans" when its button is tapped.
  var codeToScan = '3017620422003';

  setUp(() {
    codeToScan = '3017620422003';
    fakeLookup = FakeBarcodeLookupService();
    container = ProviderContainer(
      overrides: [
        barcodeLookupServiceProvider.overrideWithValue(fakeLookup),
        barcodeCameraViewProvider.overrideWithValue(
          ({required onBarcode}) => Center(
            child: ElevatedButton(
              key: const Key('fakeScanButton'),
              onPressed: () => onBarcode(codeToScan),
              child: const Text('FAKE CAMERA'),
            ),
          ),
        ),
      ],
    );
  });

  tearDown(() => container.dispose());

  Future<void> pumpScreen(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/barcode-scan-add-item',
      routes: [
        GoRoute(
          path: '/barcode-scan-add-item',
          builder: (_, _) => const BarcodeScanScreen(),
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

  Future<void> scan(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('fakeScanButton')));
    await tester.pumpAndSettle();
  }

  String nameFieldText(WidgetTester tester) => tester
      .widget<TextField>(find.byKey(const Key('scanNameField')))
      .controller!
      .text;

  testWidgets('a match pre-fills the form and saving adds it to inventory', (
    tester,
  ) async {
    fakeLookup.resultToReturn = const ProductLookupResult(
      barcode: '3017620422003',
      name: 'Nutella',
      brand: 'Ferrero',
      category: 'Other',
      shelfLifeDays: 180,
    );
    final before = container.read(inventoryProvider).length;

    await pumpScreen(tester);
    await scan(tester);

    expect(fakeLookup.lookedUp, ['3017620422003']);
    expect(find.text('FAKE CAMERA'), findsNothing); // camera released
    expect(nameFieldText(tester), 'Nutella');
    expect(find.text('Brand: Ferrero'), findsOneWidget);
    expect(find.text('Category: Other'), findsOneWidget);
    expect(find.text('Best used within 180 days'), findsOneWidget);
    expect(find.byKey(const Key('shelfLifeHintText')), findsOneWidget);

    final save = find.byKey(const Key('saveScannedItemButton'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    final items = container.read(inventoryProvider);
    expect(items.length, before + 1);
    expect(items.last.name, 'Nutella');
    final expected = DateTime.now().copyWith(
      hour: 0,
      minute: 0,
      second: 0,
      millisecond: 0,
      microsecond: 0,
    );
    final e = items.last.expiryDate;
    expect(
      DateTime(e.year, e.month, e.day),
      DateTime(expected.year, expected.month, expected.day + 180),
    );
    expect(find.text('INVENTORY'), findsOneWidget);
  });

  testWidgets('not found offers manual entry (opened empty)', (tester) async {
    fakeLookup.resultToReturn = const ProductLookupResult(
      barcode: '0000000000000',
      notFound: true,
    );

    await pumpScreen(tester);
    await scan(tester);

    expect(find.byKey(const Key('barcodeNotFoundText')), findsOneWidget);

    await tester.tap(find.byKey(const Key('enterManuallyButton')));
    await tester.pumpAndSettle();
    expect(find.text('MANUAL ENTRY'), findsOneWidget);
  });

  testWidgets('an error shows its message and Scan again reopens the camera', (
    tester,
  ) async {
    fakeLookup.errorToThrow = const BarcodeLookupException(
      BarcodeLookupError.offline,
    );

    await pumpScreen(tester);
    await scan(tester);

    expect(
      tester.widget<Text>(find.byKey(const Key('barcodeErrorText'))).data,
      startsWith("Couldn't reach the product database"),
    );

    await tester.tap(find.byKey(const Key('scanAgainButton')));
    await tester.pumpAndSettle();
    expect(find.text('FAKE CAMERA'), findsOneWidget);
  });

  testWidgets('a QR code is rejected without calling the backend', (
    tester,
  ) async {
    codeToScan = 'https://example.com/menu';

    await pumpScreen(tester);
    await scan(tester);

    expect(fakeLookup.lookedUp, isEmpty);
    expect(find.textContaining("That's not a product barcode"), findsOneWidget);
    expect(find.text('FAKE CAMERA'), findsOneWidget); // still scanning
  });

  testWidgets('Scan a different item returns from the form to the camera', (
    tester,
  ) async {
    fakeLookup.resultToReturn = const ProductLookupResult(
      barcode: '3017620422003',
      name: 'Nutella',
      shelfLifeDays: 180,
    );

    await pumpScreen(tester);
    await scan(tester);

    final again = find.byKey(const Key('scanAnotherButton'));
    await tester.ensureVisible(again);
    await tester.tap(again);
    await tester.pumpAndSettle();

    expect(find.text('FAKE CAMERA'), findsOneWidget);
  });
}
