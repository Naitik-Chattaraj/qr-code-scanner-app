import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/models/scan_result.dart';

class ScanHudOverlay extends StatelessWidget {
  final bool isProcessing;
  final ScanResultData? scanResult;
  final VoidCallback? onDismiss;

  const ScanHudOverlay({
    super.key,
    required this.isProcessing,
    this.scanResult,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    Color statusBgColor = Colors.white;
    IconData statusIcon = Icons.qr_code_scanner;

    if (scanResult != null) {
      if (scanResult!.status == 'success') {
        statusBgColor = AppColors.success;
        statusIcon = Icons.check_circle_outline;
      } else if (scanResult!.status == 'warning') {
        statusBgColor = AppColors.warning;
        statusIcon = Icons.warning_amber_rounded;
      } else if (scanResult!.status == 'error') {
        statusBgColor = AppColors.error;
        statusIcon = Icons.cancel_outlined;
      }
    }

    return Stack(
      children: [
        // Default Scanner View (hardware-accelerated, flicker-free CustomPaint)
        if (scanResult == null)
          const Positioned.fill(
            child: CustomPaint(
              painter: ScannerOverlayPainter(),
            ),
          ),

        // Processing Spinner Indicator
        if (isProcessing && scanResult == null)
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Verifying badge...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Result Solid Overlay
        if (scanResult != null)
          Positioned.fill(
            child: Container(
              color: statusBgColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  // Icon
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: Icon(statusIcon, size: 64, color: Colors.white),
                  ),
                  const SizedBox(height: 24),
                  
                  // Title
                  Text(
                    scanResult!.message.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Name & Org
                  if (scanResult!.data != null && scanResult!.data!['name'] != null)
                    Text(
                      scanResult!.data!['name'].toString().toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  if (scanResult!.data != null && scanResult!.data!['organization'] != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      scanResult!.data!['organization'].toString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],

                  // Details/Message
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      scanResult!.data?['details']?.toString() ?? scanResult!.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Next QR Button
                  if (onDismiss != null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: onDismiss,
                        icon: const Text('Next QR', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        label: const Icon(Icons.arrow_forward),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: statusBgColor,
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 8,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  if (onDismiss != null)
                    const Text(
                      'Press Next QR to scan the next attendee',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Hardware-accelerated, zero-flicker overlay painter that uses the even-odd
/// path fill rule to punch out a centered viewfinder hole without GPU blend mode passes.
class ScannerOverlayPainter extends CustomPainter {
  final Color overlayColor;
  final double cutoutSize;
  final double borderRadius;
  final Color borderColor;
  final double borderWidth;

  const ScannerOverlayPainter({
    this.overlayColor = const Color(0x80000000), // 50% opacity black
    this.cutoutSize = 260.0,
    this.borderRadius = 20.0,
    this.borderColor = Colors.white54,
    this.borderWidth = 3.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final cutoutRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: cutoutSize,
      height: cutoutSize,
    );
    final cutoutRRect = RRect.fromRectAndRadius(
      cutoutRect,
      Radius.circular(borderRadius),
    );

    // 1. Draw darkened overlay with clean transparent cutout using even-odd fill rule
    final overlayPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(backgroundRect)
      ..addRRect(cutoutRRect);

    canvas.drawPath(path, overlayPaint);

    // 2. Draw border around viewfinder cutout
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    canvas.drawRRect(cutoutRRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant ScannerOverlayPainter oldDelegate) => false;
}
