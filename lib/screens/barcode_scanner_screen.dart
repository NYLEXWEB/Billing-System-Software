import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _hasDetected = false;
  PermissionStatus _permissionStatus = PermissionStatus.denied;
  bool _isCheckingPermission = true;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    setState(() {
      _isCheckingPermission = true;
    });

    var status = await Permission.camera.status;
    if (status.isDenied) {
      status = await Permission.camera.request();
    }

    setState(() {
      _permissionStatus = status;
      _isCheckingPermission = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildPermissionDeniedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.camera_alt_outlined, size: 56, color: Color(0xFFEF4444)),
            ),
            const SizedBox(height: 24),
            const Text(
              "Camera Access Required",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 12),
            const Text(
              "To scan product barcodes, we need permission to use your camera. Please grant access to continue.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), height: 1.4, fontSize: 14),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () async {
                if (_permissionStatus.isPermanentlyDenied) {
                  await openAppSettings();
                } else {
                  await _checkPermission();
                }
              },
              icon: const Icon(Icons.security, size: 18),
              label: Text(
                _permissionStatus.isPermanentlyDenied ? "Open System Settings" : "Grant Permission",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasCameraAccess = _permissionStatus.isGranted;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan Barcode / QR", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (hasCameraAccess) ...[
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
          ]
        ],
      ),
      body: _isCheckingPermission
          ? const Center(child: CircularProgressIndicator())
          : !hasCameraAccess
              ? _buildPermissionDeniedView()
              : Stack(
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
