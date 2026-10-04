import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/models/scan_result.dart';

class ScanHudOverlay extends StatelessWidget {
  final bool isProcessing;
  final ScanResultData? scanResult;

  const ScanHudOverlay({
    super.key,
    required this.isProcessing,
    this.scanResult,
  });

  @override
  Widget build(BuildContext context) {
    Color borderColor = Colors.white54;
    if (scanResult != null) {
      if (scanResult!.status == 'success') {
        borderColor = AppColors.success;
      } else if (scanResult!.status == 'warning') {
        borderColor = AppColors.warning;
      } else if (scanResult!.status == 'error') {
        borderColor = AppColors.error;
      }
    }

    return Stack(
      children: [
        // Dark overlay outside the scanning area
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.5),
            BlendMode.srcOut,
          ),
          child: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              Center(
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Scanning frame
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: borderColor, width: 4),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        
        // Processing indicator
        if (isProcessing)
          const Center(
            child: CircularProgressIndicator(color: AppColors.ieeeLight),
          ),
          
        // Scan Result Message
        if (scanResult != null)
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    scanResult!.status == 'success' ? Icons.check_circle :
                    scanResult!.status == 'warning' ? Icons.warning : Icons.error,
                    color: borderColor,
                    size: 48,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    scanResult!.message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: borderColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  if (scanResult!.data != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      scanResult!.data!['name'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      scanResult!.data!['organization'] ?? '',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ]
                ],
              ),
            ),
          ),
      ],
    );
  }
}
