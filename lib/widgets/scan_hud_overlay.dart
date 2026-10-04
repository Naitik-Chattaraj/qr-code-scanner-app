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
    Color statusBgColor = Colors.white;
    IconData statusIcon = Icons.qr_code_scanner;

    if (scanResult != null) {
      if (scanResult!.status == 'success') {
        borderColor = AppColors.success;
        statusBgColor = const Color(0xFFECFDF5);
        statusIcon = Icons.check_circle_rounded;
      } else if (scanResult!.status == 'warning') {
        borderColor = AppColors.warning;
        statusBgColor = const Color(0xFFFFFBEB);
        statusIcon = Icons.warning_amber_rounded;
      } else if (scanResult!.status == 'error') {
        borderColor = AppColors.error;
        statusBgColor = const Color(0xFFFEF2F2);
        statusIcon = Icons.cancel_rounded;
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
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Scanning Reticle Frame
        Center(
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              border: Border.all(color: borderColor, width: 3.5),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),

        // Processing Spinner Indicator
        if (isProcessing)
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

        // Result Card Modal at Bottom
        if (scanResult != null)
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: statusBgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(statusIcon, color: borderColor, size: 36),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          scanResult!.message,
                          style: TextStyle(
                            color: borderColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (scanResult!.data != null &&
                      scanResult!.data!.isNotEmpty) ...[
                    const Divider(height: 20, thickness: 1),
                    if (scanResult!.data!['name'] != null &&
                        scanResult!.data!['name'].toString().isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.person, size: 18, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              scanResult!.data!['name'].toString().toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (scanResult!.data!['organization'] != null &&
                        scanResult!.data!['organization'].toString().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.business, size: 18, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              scanResult!.data!['organization'].toString(),
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (scanResult!.data!['details'] != null &&
                        scanResult!.data!['details'].toString().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: borderColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          scanResult!.data!['details'].toString(),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: borderColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}
