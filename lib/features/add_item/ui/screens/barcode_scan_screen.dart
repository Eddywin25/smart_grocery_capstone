import 'package:flutter/material.dart';

// Screen for Barcode Scan with Camera
//    Currently screen is placeholder and will utilize call to scanner

class BarcodeScanScreen extends StatelessWidget {
  const BarcodeScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Barcode')),

      body: const Center(child: Text('PLACEHOLDER FOR BARCODE SCANNER')),
    );
  }
}
