import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:easy_localization/easy_localization.dart'; // Importation de easy_localization

class ScannerPresenceScreen extends StatefulWidget {
  final int adminId;

  const ScannerPresenceScreen({Key? key, required this.adminId}) : super(key: key);

  @override
  State<ScannerPresenceScreen> createState() => _ScannerPresenceScreenState();
}

class _ScannerPresenceScreenState extends State<ScannerPresenceScreen> {
  bool _isProcessing = false;
  final MobileScannerController cameraController = MobileScannerController();

  void _onDetect(BarcodeCapture barcodeCapture) async {
    if (_isProcessing) return;

    final barcode = barcodeCapture.barcodes.first;
    final String? qrData = barcode.rawValue;

    if (qrData != null) {
      setState(() {
        _isProcessing = true;
      });

      cameraController.stop();
      _traiterEmargementMembres(qrData);
    }
  }

  Future<void> _traiterEmargementMembres(String qrData) async {
    try {
      String cleanId = qrData.replaceAll(RegExp(r'[^0-9]'), '');
      int? membreId = int.tryParse(cleanId);

      if (membreId == null) {
        throw Exception("invalid_qr_format".tr());
      }

      // Simulation de la validation réseau
      await Future.delayed(const Duration(milliseconds: 600));

      _afficherSuccesScan("Membre #$membreId ${"member_marked_present".tr()}");
    } catch (e) {
      _afficherErreurScan("${"validation_error".tr()} : ${e.toString()}");
    }
  }

  void _afficherSuccesScan(String message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            Text('success_title'.tr(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF009688),
                minimumSize: const Size(double.infinity, 45),
              ),
              onPressed: () {
                Navigator.pop(context);
                _relancerCamera();
              },
              child: Text('scan_next_member'.tr(), style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    ).then((_) => _relancerCamera());
  }

  void _afficherErreurScan(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 3),
      ),
    );
    _relancerCamera();
  }

  void _relancerCamera() {
    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
      cameraController.start();
    }
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = const Color(0xFF1A529B);

    return Scaffold(
      appBar: AppBar(
        title: Text('scanner_title'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Bouton Basculer Flash
          IconButton(
            icon: const Icon(Icons.flash_on, color: Colors.white),
            onPressed: () => cameraController.toggleTorch(),
          ),
          // Bouton Inverser Caméra Avant/Arrière
          IconButton(
            icon: const Icon(Icons.cameraswitch, color: Colors.white),
            onPressed: () => cameraController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: _onDetect,
          ),
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: primaryColor, width: 4),
                borderRadius: BorderRadius.circular(16),
                color: Colors.black.withOpacity(0.1),
              ),
            ),
          ),
          Positioned(
            top: 30,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'scan_instruction'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}