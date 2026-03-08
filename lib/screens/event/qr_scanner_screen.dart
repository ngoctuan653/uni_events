import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/checkin_services.dart';

/// QR Scanner screen for staff to scan student QR codes for check-in.
///
/// Uses the device camera to scan QR codes containing registration IDs.
/// Only accessible by club_staff or club_admin of the event's club.
class QRScannerScreen extends StatefulWidget {
  final String eventId;
  final String eventTitle;

  const QRScannerScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
  });

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final CheckInService _checkInService = CheckInService();
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;
  bool? _lastSuccess;
  String? _lastMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleScan(String registrationId) async {
    if (_isProcessing) return;

    // Stop camera immediately to prevent multiple scans
    _controller.stop();

    setState(() {
      _isProcessing = true;
    });

    try {
      final result = await _checkInService.checkInByQR(
        registrationId,
        expectedEventId: widget.eventId,
      );
      if (mounted) {
        setState(() {
          _lastSuccess = true;
          _lastMessage =
              '✓ ${result['userName']} (${result['studentId']})\nChecked in successfully!';
          _isProcessing = false;
        });

        // Show success dialog
        _showResultDialog(true, result['userName'], result['studentId']);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _lastSuccess = false;
          _lastMessage = e.toString().replaceFirst('Exception: ', '');
          _isProcessing = false;
        });

        // Show error dialog
        _showResultDialog(
          false,
          null,
          null,
          error: e.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  void _showResultDialog(
    bool success,
    String? name,
    String? studentId, {
    String? error,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error,
              color: success ? Colors.green : Colors.red,
              size: 28,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                success ? 'Check-in Successful' : 'Check-in Failed',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: success
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Name: $name', style: const TextStyle(fontSize: 16)),
                  if (studentId != null && studentId.isNotEmpty)
                    Text(
                      'Student ID: $studentId',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Event: ${widget.eventTitle}',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              )
            : Text(
                error ?? 'Unknown error',
                style: const TextStyle(fontSize: 15),
              ),
        actions: [
          if (success)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // close dialog
                Navigator.pop(context); // go back to ManageCheckInScreen
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Done', style: TextStyle(color: Colors.white)),
            )
          else
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // Resume camera for retry
                _controller.start();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Try Again',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _controller,
              builder: (context, state, child) {
                switch (state.torchState) {
                  case TorchState.off:
                    return const Icon(Icons.flash_off, color: Colors.grey);
                  case TorchState.on:
                    return const Icon(Icons.flash_on, color: Colors.yellow);
                  default:
                    return const Icon(Icons.flash_off, color: Colors.grey);
                }
              },
            ),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera view
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null && !_isProcessing) {
                  _handleScan(barcode.rawValue!);
                  break;
                }
              }
            },
          ),

          // Overlay with scan area
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.orange, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          // Instructions at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.8),
                    Colors.black,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.eventTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isProcessing
                        ? 'Processing...'
                        : 'Point camera at student\'s QR code',
                    style: TextStyle(color: Colors.grey.shade300, fontSize: 14),
                  ),
                  if (_lastMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _lastSuccess == true
                            ? Colors.green.withValues(alpha: 0.2)
                            : Colors.red.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _lastMessage!,
                        style: TextStyle(
                          color: _lastSuccess == true
                              ? Colors.green
                              : Colors.red,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Processing indicator
          if (_isProcessing)
            const Center(
              child: CircularProgressIndicator(color: Colors.orange),
            ),
        ],
      ),
    );
  }
}
