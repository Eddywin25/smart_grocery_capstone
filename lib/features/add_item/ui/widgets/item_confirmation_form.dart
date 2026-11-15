import 'package:material_ui/material_ui.dart';

import '../../../inventory/domain/models/inventory_item.dart';

/// Holds the editable state of an [ItemConfirmationForm] so the owning screen
/// can pre-fill it from a scan/lookup and update it (e.g. when the user taps
/// an alternative chip) without the form widget owning that logic.
class ItemFormController extends ChangeNotifier {
  final TextEditingController name = TextEditingController();
  final TextEditingController quantity = TextEditingController(text: '1');

  DateTime? _expiryDate;
  StorageLocation location = StorageLocation.fridge;
  Package package = Package.item;
  bool nameError = false;
  bool quantityError = false;

  static DateTime get today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Today plus [days] calendar days (negative counts as 0). Uses the
  /// DateTime constructor rather than `add(Duration(days: n))`, which adds
  /// exact 24-hour periods and lands on the previous day when the range
  /// crosses a daylight-saving change.
  static DateTime todayPlusDays(int days) {
    final t = today;
    return DateTime(t.year, t.month, t.day + (days < 0 ? 0 : days));
  }

  DateTime? get expiryDate => _expiryDate;

  /// Whole calendar days from today to the expiry date, or null if no date
  /// is set. Compared in UTC so a daylight-saving change can't make it a
  /// day short.
  int? get daysLeft {
    final e = _expiryDate;
    if (e == null) return null;
    final t = today;
    return DateTime.utc(
      e.year,
      e.month,
      e.day,
    ).difference(DateTime.utc(t.year, t.month, t.day)).inDays;
  }

  /// Pre-fills the form for a new scan/lookup. Quantity, package and
  /// location keep whatever the user last chose.
  void prefill({required String itemName, DateTime? expiry}) {
    name.text = itemName;
    _expiryDate = expiry == null ? null : dateOnly(expiry);
    nameError = false;
    quantityError = false;
    notifyListeners();
  }

  void setName(String value) {
    name.text = value;
    nameError = false;
    notifyListeners();
  }

  void setExpiry(DateTime value) {
    _expiryDate = dateOnly(value);
    notifyListeners();
  }

  void setLocation(StorageLocation value) {
    location = value;
    notifyListeners();
  }

  void setPackage(Package value) {
    package = value;
    notifyListeners();
  }

  /// Validates the fields and returns the item to save, or null (with the
  /// error flags set) if something is missing.
  InventoryItem? buildItem() {
    final trimmedName = name.text.trim();
    final qty = int.tryParse(quantity.text.trim());
    nameError = trimmedName.isEmpty;
    quantityError = qty == null || qty <= 0;
    notifyListeners();
    if (nameError || quantityError || _expiryDate == null) return null;

    final now = DateTime.now();
    return InventoryItem(
      id: now.millisecondsSinceEpoch.toString(),
      name: trimmedName,
      quantity: qty!,
      location: location,
      purchaseDate: now,
      expiryDate: _expiryDate!,
      packageType: package,
    );
  }

  @override
  void dispose() {
    name.dispose();
    quantity.dispose();
    super.dispose();
  }
}

/// Confirmation form shared by the food-recognition and barcode screens:
/// name, "Best used within X days" with a date override, quantity, package
/// type and storage location, plus a Save button.
///
/// Screen-specific content goes in the slots: [header] above the name field
/// (e.g. a review banner and alternative chips), [details] between the name
/// and expiry (category, source, ripeness...), and [footer] under Save.
class ItemConfirmationForm extends StatelessWidget {
  const ItemConfirmationForm({
    super.key,
    required this.controller,
    required this.onSave,
    this.onNameChanged,
    this.header = const [],
    this.details = const [],
    this.footer = const [],
  });

  final ItemFormController controller;
  final VoidCallback onSave;
  final ValueChanged<String>? onNameChanged;
  final List<Widget> header;
  final List<Widget> details;
  final List<Widget> footer;

  Future<void> _pickExpiryDate(BuildContext context) async {
    final first = ItemFormController.today;
    final last = ItemFormController.todayPlusDays(365);
    var initial = controller.expiryDate ?? first;
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked == null || !context.mounted) return;
    controller.setExpiry(picked);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final expiry = controller.expiryDate;
        final daysLeft = controller.daysLeft;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...header,

              TextField(
                key: const Key('scanNameField'),
                controller: controller.name,
                onChanged: onNameChanged,
                decoration: InputDecoration(
                  labelText: 'Item Name',
                  border: const OutlineInputBorder(),
                  errorText: controller.nameError
                      ? 'Item name is required'
                      : null,
                ),
              ),
              const SizedBox(height: 12),

              ...details,
              if (details.isNotEmpty) const SizedBox(height: 16),

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
                    onPressed: () => _pickExpiryDate(context),
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
                controller: controller.quantity,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Quantity',
                  border: const OutlineInputBorder(),
                  errorText: controller.quantityError
                      ? 'A valid quantity is required'
                      : null,
                ),
              ),
              const SizedBox(height: 16),

              const Text('Package Type'),
              DropdownButton<Package>(
                value: controller.package,
                isExpanded: true,
                items: [
                  for (final p in Package.values)
                    DropdownMenuItem(value: p, child: Text(p.name)),
                ],
                onChanged: (v) => controller.setPackage(v!),
              ),
              const SizedBox(height: 16),

              const Text('Storage Location'),
              DropdownButton<StorageLocation>(
                value: controller.location,
                isExpanded: true,
                items: [
                  for (final l in StorageLocation.values)
                    DropdownMenuItem(value: l, child: Text(l.name)),
                ],
                onChanged: (v) => controller.setLocation(v!),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const Key('saveScannedItemButton'),
                  onPressed: onSave,
                  child: const Text('Save Item'),
                ),
              ),
              if (footer.isNotEmpty) const SizedBox(height: 8),
              ...footer,
            ],
          ),
        );
      },
    );
  }
}
