import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../inventory/domain/models/inventory_item.dart';
import '../../../inventory/ui/providers/inventory_provider.dart';
import '../../../inventory/data/services/expiry_est_service.dart';


// Screen for Manually Entering Information to Add Grocery Item to Inventory
class ManuallyAddItemScreen extends ConsumerStatefulWidget {
  const ManuallyAddItemScreen({super.key});

  @override
  ConsumerState<ManuallyAddItemScreen> createState() =>
      _ManuallyAddItemScreenState();
}

class _ManuallyAddItemScreenState extends ConsumerState<ManuallyAddItemScreen> {
  final _nameController = TextEditingController();      // Allows control for what user types in for name

  final _quantityController = TextEditingController();  // Allows control for what user types in for quantity

  final expiryService = ExpiryEstService(); // Retrieve expiry information

  bool _nameError = false; // Flag for validating entry for item name

  bool _quantityError = false; // Flag for validating entry for item quantity

  bool _expiryError = false; // Flag for validating entry for item expiry

  bool _displayExpiryField = false; // Flag for displaying the expiry field

  DateTime? selectedExpiryDate; // Declaring the selected expiry date as a DateTime or Null

  Package selectedPackage = Package.item; // Initializes the package type

  StorageLocation selectedLocation = StorageLocation.fridge;  // Initializes the storage location

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manual Entry')),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            // Name Entry Box for Grocery Item
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Item Name',
                border: OutlineInputBorder(),
                errorText: _nameError ? 'Item name is required' : null, 
              ),
            ),

            // Space
            const SizedBox(height: 16), 

            // Row of methods to set expiry date
            Row(
              children: [

                // Button for estimating expiry (Calls service)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        selectedExpiryDate = expiryService.estimateExpiry(_nameController.text);
                        _displayExpiryField = true;
                      });
                    },

                    child: const Text('Estimate Expiry'),
                  ),
                ),

                // Space
                const SizedBox(width: 12),

                // Button for manually setting expiry
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      setState(() {_displayExpiryField = true;});

                      // Store date picked in calendar
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: selectedExpiryDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );

                      if (pickedDate != null) {
                        setState(() {selectedExpiryDate = pickedDate;});
                      }
                    },

                    icon: const Icon(Icons.calendar_month),

                    label: const Text('Set Expiry Date'),
                  ),
                ),
              ],
            ),

            // Space
            const SizedBox(height: 16),

            // If date was picked, estimated, or if form submitted without selecting date,
            //    display the expiry date field
            if (_displayExpiryField)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _expiryError ? Colors.red : Colors.grey,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),

                // Expiry date contents
                child: Text(
                  selectedExpiryDate == null
                      ? 'Expiration Date Required'
                      : 'Expiry: '
                            '${selectedExpiryDate!.month}/'
                            '${selectedExpiryDate!.day}/'
                            '${selectedExpiryDate!.year}',
                  style: TextStyle(
                    color: _expiryError ? Colors.red : Colors.grey,
                  ),
                ),
              ),

            // Space
            const SizedBox(height: 24),

            // Field for recording quantity
            TextField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
                errorText: _quantityError
                    ? 'A valid quantity is required'
                    : null,
              ),
            ),

            // Space
            const SizedBox(height: 16),

            // Package type selection field
            const Text('Package Type'),
            DropdownButton<Package>(
              value: selectedPackage,
              isExpanded: true,
              items: Package.values.map((package) {
                return DropdownMenuItem(
                  value: package,
                  child: Text(package.name),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {selectedPackage = value!;});
              },
            ),

            // Space
            const SizedBox(height: 16),

            // Storage location selection field
            const Text('Storage Location'),
            DropdownButton<StorageLocation>(
              value: selectedLocation,
              isExpanded: true,
              items: StorageLocation.values.map((location) {
                return DropdownMenuItem(
                  value: location,
                  child: Text(location.name),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {selectedLocation = value!;});
              },
            ),

            // Space
            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final quantity = int.tryParse(_quantityController.text);

                  // Perform validation
                  setState(() {
                    _nameError = _nameController.text.trim().isEmpty;
                    _quantityError = quantity == null || quantity <= 0;
                    _expiryError = selectedExpiryDate == null;
                  });

                  if (_expiryError) {_displayExpiryField = true;}

                  if (_nameError || _quantityError || _expiryError) {return;}

                  // Compiling entered data into inventory item
                  final item = InventoryItem(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),

                    name: _nameController.text,

                    quantity: int.parse(_quantityController.text),

                    location: selectedLocation,

                    purchaseDate: DateTime.now(),

                    expiryDate: selectedExpiryDate!,

                    packageType: selectedPackage,
                  );


                  // Add item to inventory
                  ref.read(inventoryProvider.notifier).addItem(item);

                  // Navigate back to inventory
                  context.go('/inventory');
                },

                child: const Text('Save Item'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Cleanup operations for controllers used
  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();

    super.dispose();
  }
}
