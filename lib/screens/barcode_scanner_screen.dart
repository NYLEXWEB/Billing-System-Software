import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/services.dart';
import '../services/analytics_service.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _hasDetected = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan Barcode / QR", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          ValueListenableBuilder(
            valueListenable: _controller.torchState,
            builder: (context, state, child) {
              final isTorchOn = state == TorchState.on;
              return IconButton(
                icon: Icon(isTorchOn ? Icons.flash_on : Icons.flash_off, color: isTorchOn ? Colors.yellow : Colors.white),
                onPressed: () => _controller.toggleTorch(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios_outlined),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Camera scanner viewfinder
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_hasDetected) return;

              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final barcode = barcodes.first.rawValue;
                if (barcode != null && barcode.isNotEmpty) {
                  setState(() {
                    _hasDetected = true;
                  });
                  // Trigger a short haptic vibration
                  HapticFeedback.lightImpact();
                  AnalyticsService.logBarcodeScan(barcode);
                  Navigator.pop(context, barcode);
                }
              }
            },
          ),

          // 2. Viewfinder Overlay UI
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blueAccent, width: 4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Align(
                alignment: Alignment.center,
                child: SizedBox(
                  width: 230,
                  height: 2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: Colors.redAccent),
                  ),
                ),
              ),
            ),
          ),

          // Instruction Text
          Positioned(
            bottom: 60,
            left: 20,
            right: 20,
            child: Card(
              elevation: 4,
              color: Colors.black.withOpacity(0.7),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  "Align barcode within the framing box to scan",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
