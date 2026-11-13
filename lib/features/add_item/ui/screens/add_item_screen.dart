import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Main Screen for Adding Grocery Items to Inventory
class AddItemScreen extends StatelessWidget {
  const AddItemScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add an item')),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),

        child: Column(
          children: [
            // Smart Capture Icon, Label, and Prompt
            const SizedBox(height: 32),
            const CircleAvatar(radius: 32, child: Icon(Icons.auto_awesome)),
            const SizedBox(height: 24),
            const Text('SMART CAPTURE', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            const Text(
              'How would you like to add it?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            // Header for camera-based options
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Using Camera',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 10),

            // Instructions for camera-based options
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Scan a package or point your camera at fresh food. '
                'We\'ll fill in the details for you.',
                style: TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(height: 12),

            // Add item via barcode scan
            _CaptureOptionCard(
              icon: Icons.qr_code_scanner,
              title: 'Scan a barcode',
              subtitle: 'Best for packaged groceries',
              onTap: () {
                context.push('/barcode-scan-add-item');
              },
            ),
            const SizedBox(height: 16),

            // Add item via AI model food recognition
            _CaptureOptionCard(
              icon: Icons.camera_alt_outlined,
              title: 'Recognize fresh food',
              subtitle: 'AI identifies produce and unlabeled items',
              onTap: () {
                context.push('/ai-add-item');
              },
            ),
            const SizedBox(height: 12),

            // Disclaimer for adding an item via camera
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Photos are analyzed securely and aren't saved after recognition",
                style: TextStyle(fontSize: 14, color: Colors.redAccent),
              ),
            ),
            const SizedBox(height: 24),

            // Header for manual entry options
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Manual Entry',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),

            // Add item via manual entry
            _CaptureOptionCard(
              icon: Icons.edit,
              title: 'Enter item manually',
              subtitle: 'Add an item without using camera',
              onTap: () {
                context.push('/manual-add-item');
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Private class for capturing information when adding grocery item to inventory
class _CaptureOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _CaptureOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Icon associated with capture option
              Container(
                width: 58,
                height: 58,

                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: const Color.fromARGB(255, 21, 207, 31),
                ),

                child: Icon(icon, color: Colors.white),
              ),

              const SizedBox(width: 16),

              // Title and subtitle for capture option
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(subtitle),
                  ],
                ),
              ),

              // Right arrow icon
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
