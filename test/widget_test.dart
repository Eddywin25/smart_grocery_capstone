// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_grocery/features/inventory/domain/models/inventory_item.dart';
import 'package:smart_grocery/features/inventory/ui/widgets/inventory_item_card.dart';
import 'package:smart_grocery/features/inventory/ui/widgets/inventory_item_form.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


void main() {
  testWidgets(
    'Test that inventory card displays item information',
    (tester) async {
      // Set Item Information
      final item = InventoryItem(
        id: '42',
        name: 'Cheese',
        quantity: 9,
        location: StorageLocation.fridge,
        purchaseDate: DateTime.now(),
        expiryDate: DateTime.now().add(
          const Duration(days: 20),
        ),
        packageType: Package.item,
      );

      // Create Inventory Item Card with Item
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: InventoryItemCard(
              item: item,
            ),
          ),
        ),
      );

      // Check name
      expect(find.text('Cheese'), findsOneWidget);

      // Check quantity/location
      expect(
        find.text(item.displayQuantLocation),
        findsOneWidget,
      );

      // Check purchase date
      expect(
        find.text(item.displayPurchaseDate),
        findsOneWidget,
      );

      // Check expiry date
      expect(
        find.text(item.displayExpiryDate),
        findsOneWidget,
      );
    },
  );


  testWidgets(
    'Test for Validation Error when adding item with no name',
    (tester) async {

      // Setting up item details form
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InventoryItemForm(
              saveButtonName: 'Save Item',
              onSave: (_) {},
            ),
          ),
        ),
      );

      // Save the item
      await tester.tap(
        find.text('Save Item'),
      );

      // Rebuild widget
      await tester.pump();

      // Check if item name validation message appears
      expect(
        find.text('Item name is required'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Ensure Estimate Expiry Button Returns Date',
    (tester) async {

      // Setting up item details form
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InventoryItemForm(
              saveButtonName: 'Save Item',
              onSave: (_) {},
            ),
          ),
        ),
      );

      // Enter a grocery item name
      await tester.enterText(
        find.byType(TextField).first,
        'Pork Chop',
      );

      // Ensure date is initially unpopulated
      expect(
        find.textContaining('Expiry:'),
        findsNothing,
      );

      // Tap Estimate Expiry button
      await tester.tap(
        find.text('Estimate Expiry'),
      );

      // Rebuild widget
      await tester.pump();

      // Check that expiry appears
      expect(
        find.textContaining('Expiry:'),
        findsOneWidget,
      );
    },
  );
}