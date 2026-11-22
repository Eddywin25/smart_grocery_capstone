import 'package:flutter/material.dart';
import 'package:smart_grocery/features/inventory/data/services/expiry_est_service.dart';
import '../../domain/models/inventory_item.dart';
import 'package:flutter/services.dart';


// Form used to capture item details for inventory
class InventoryItemForm
    extends StatefulWidget {

  final InventoryItem? initialItem;

  final void Function(
    InventoryItem item,
  ) onSave;

  final String saveButtonName;

  const InventoryItemForm({
    super.key,
    this.initialItem,
    required this.onSave,
    required this.saveButtonName,
  });

  @override
  State<InventoryItemForm>
      createState() =>
          _InventoryItemFormState();
}


// Class for screen state 
class _InventoryItemFormState
    extends State<InventoryItemForm> {

  final _nameController = TextEditingController(); // Allows control for what user types in for name

  final _quantityController = TextEditingController();  // Allows control ffor what user types in for quantity

  final expiryService = ExpiryEstService(); // Retrieve expiry information

  bool _nameError = false; // Flag for validating entry for item name

  bool _quantityError = false; // Flag for validating entry for item quantity

  bool _expiryError = false; // Flag for validating entry for item expiry

  Package selectedPackage = Package.item; // Initializes the package type

  StorageLocation selectedLocation = StorageLocation.fridge;  // Initializes the storage location

  DateTime? selectedExpiryDate;       // Declaring the selected expiry data as a DateTime

  bool _displayExpiryField = false;   // Flag for display the expiry field

  // Set up existing data for item
  @override
  void initState() {
    super.initState();

    // For edit/update functionality set initial inventory state
    if (widget.initialItem != null) {

      _nameController.text = widget.initialItem!.name;

      _quantityController.text = widget.initialItem!.quantity.toString();

      selectedPackage = widget.initialItem!.packageType;

      selectedLocation = widget.initialItem!.location;

      selectedExpiryDate = widget.initialItem!.expiryDate;

      _displayExpiryField = true;
    }
  }

  // Edit Screen detail
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
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
                        selectedExpiryDate =
                            expiryService.estimateExpiry(
                              _nameController.text,
                            );

                        _displayExpiryField = true;
                        _expiryError = false;
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

                      if (!mounted) {
                        return;
                      }

                      if (pickedDate != null && mounted) {
                        setState(() {
                          selectedExpiryDate = pickedDate;
                          _expiryError = false;
                        });
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
                    color: selectedExpiryDate == null &&
                            _expiryError
                        ? Colors.red
                        : Colors.black,
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
                    color: selectedExpiryDate == null &&
                            _expiryError
                        ? Colors.red
                        : Colors.black,
                  ),
                ),
              ),

            // Space
            const SizedBox(height: 24),

            // Field for recording quantity
            TextField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
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
                  final quantity = int.tryParse(_quantityController.text.trim());
                  final trimmedName = _nameController.text.trim();

                  // Perform validation
                  setState(() {
                    _nameError = trimmedName.isEmpty;
                    _quantityError = quantity == null || quantity <= 0;
                    _expiryError = selectedExpiryDate == null;
                  });

                  if (_expiryError) {_displayExpiryField = true;}

                  if (_nameError || _quantityError || _expiryError) {return;}

                  // Compiling entered data into inventory item
                  final item =
                    widget.initialItem == null
                      ? InventoryItem(
                          id: DateTime.now()
                              .millisecondsSinceEpoch
                              .toString(),
                          name: trimmedName,
                          quantity: quantity!,
                          location:
                              selectedLocation,
                          purchaseDate:
                              DateTime.now(),
                          expiryDate:
                              selectedExpiryDate!,
                          packageType:
                              selectedPackage,
                        )

                      : widget.initialItem!.itemCopyUpdate(
                          name:
                              _nameController.text,
                          quantity:
                              quantity,
                          location:
                              selectedLocation,
                          packageType:
                              selectedPackage,
                          expiryDate:
                              selectedExpiryDate!,
                        );

                widget.onSave(item);
              },
              child: Text(widget.saveButtonName),
              ),
            ),
          ],
        ),
      );
    }
  

  // Cleanup controllers used
  @override
  void dispose() {
  _nameController.dispose();
  _quantityController.dispose();

  super.dispose();
  }
}