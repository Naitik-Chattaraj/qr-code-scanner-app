import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/meal_sessions.dart';
import '../core/models/participant.dart';
import '../core/models/scan_result.dart';
import '../core/services/audio_service.dart';
import '../core/services/device_service.dart';
import '../core/services/haptics_service.dart';
import '../core/services/supabase_service.dart';
import '../core/services/sync_service.dart';
import '../core/utils/qr_parser.dart';
import '../widgets/scan_hud_overlay.dart';
import '../core/database/local_database.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final AudioService _audioService = AudioService();
  final SupabaseService _supabaseService = SupabaseService();
  final SyncService _syncService = SyncService();
  final LocalDatabase _localDb = LocalDatabase.instance;
  final DeviceService _deviceService = DeviceService();

  String _mode = 'registration'; // 'registration' or 'meal'
  String _selectedMealSession = MealSessions.sessions.first;
  String _deviceId = '';

  bool _isProcessing = false;
  ScanResultData? _lastResult;

  @override
  void initState() {
    super.initState();
    _loadDeviceId();
  }

  Future<void> _loadDeviceId() async {
    final id = await _deviceService.getDeviceId();
    if (mounted) setState(() => _deviceId = id);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatTimestamp(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('hh:mm a, dd MMM').format(dt);
    } catch (_) {
      return iso;
    }
  }

  Future<void> _handleScan(BarcodeCapture capture) async {
    if (_isProcessing || capture.barcodes.isEmpty) return;

    final String? rawData = capture.barcodes.first.rawValue;
    if (rawData == null || rawData.trim().isEmpty) return;

    final String ticketId = QrParser.extractParticipantId(rawData);
    if (ticketId.isEmpty) {
      _showError('Invalid QR Code: No ticket or participant identifier found.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _lastResult = null;
    });

    try {
      final isOnline = await _syncService.isOnline() && SupabaseService.isConfigured;

      if (_mode == 'registration') {
        await _handleCheckIn(ticketId, isOnline);
      } else {
        await _handleMealScan(ticketId, isOnline);
      }
    } catch (e) {
      _handleGeneralError(e, ticketId);
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
      // Auto-clear result after 3.5 seconds
      Future.delayed(const Duration(milliseconds: 3500), () {
        if (mounted) setState(() => _lastResult = null);
      });
    }
  }

  Future<void> _handleCheckIn(String ticketId, bool isOnline) async {
    if (isOnline) {
      try {
        final res = await _supabaseService.checkInAttendee(ticketId);
        final status = (res['status'] ?? '').toString().toUpperCase();
        final name = (res['name'] ?? 'Attendee').toString();
        final org = (res['organization'] ?? '').toString();
        final scannedAt = res['scanned_at']?.toString();

        if (status == 'SUCCESS') {
          _showSuccess(
            'Check-in Successful',
            {'name': name, 'organization': org, 'details': 'Welcome to AICSSYC 2026!'},
          );
        } else if (status == 'ALREADY_USED') {
          final timeStr = _formatTimestamp(scannedAt);
          _showWarning(
            'Already Checked In',
            {
              'name': name,
              'organization': org,
              'details': timeStr.isNotEmpty ? 'Checked in at $timeStr' : 'Badge was already scanned',
            },
          );
        } else {
          final message = res['message']?.toString() ?? 'Participant not found in registry.';
          _showError('Invalid Badge: $message');
        }
        return;
      } catch (err) {
        debugPrint('Online check-in RPC failed, attempting offline fallback: $err');
      }
    }

    // Offline check-in logic
    await _handleOfflineCheckIn(ticketId);
  }

  Future<void> _handleOfflineCheckIn(String ticketId) async {
    final participant = await _localDb.getParticipant(ticketId);
    if (participant == null) {
      _showError('Badge Not Found: No matching participant in offline cache.');
      return;
    }

    if (participant.isCheckedIn) {
      final timeStr = _formatTimestamp(participant.scannedAt);
      _showWarning(
        'Already Checked In (Offline)',
        {
          'name': participant.name,
          'organization': participant.organization,
          'details': timeStr.isNotEmpty ? 'Checked in at $timeStr' : 'Already marked as checked in',
        },
      );
    } else {
      final nowUtc = DateTime.now().toUtc().toIso8601String();
      // Record locally
      await _localDb.updateParticipant(
        Participant(
          participantId: participant.participantId,
          eventId: participant.eventId,
          name: participant.name,
          email: participant.email,
          mobileNumber: participant.mobileNumber,
          organization: participant.organization,
          isRegistered: participant.isRegistered,
          registeredAt: participant.registeredAt,
          scannedAt: nowUtc,
          scannedBy: _deviceId,
          dinnerStatus: participant.dinnerStatus,
          dinnerScannedAt: participant.dinnerScannedAt,
        ),
      );

      // Queue for background sync
      await _localDb.addToQueue('verify_and_checkin', {'p_id': ticketId});

      _showSuccess(
        'Check-in Verified (Offline)',
        {
          'name': participant.name,
          'organization': participant.organization,
          'details': 'Scan saved locally. Will sync when reconnected.',
        },
      );
    }
  }

  Future<void> _handleMealScan(String ticketId, bool isOnline) async {
    if (isOnline) {
      try {
        final res = await _supabaseService.verifyMealAccess(
          participantId: ticketId,
          sessionName: _selectedMealSession,
        );
        final status = (res['status'] ?? '').toString().toUpperCase();
        final name = (res['name'] ?? 'Attendee').toString();
        final org = (res['organization'] ?? '').toString();
        final scannedAt = res['scanned_at']?.toString();

        if (status == 'SUCCESS') {
          _showSuccess(
            'Meal Access Granted',
            {
              'name': name,
              'organization': org,
              'details': 'Session: $_selectedMealSession',
            },
          );
        } else if (status == 'ALREADY_USED') {
          final timeStr = _formatTimestamp(scannedAt);
          _showWarning(
            'Meal Already Redeemed',
            {
              'name': name,
              'organization': org,
              'details': timeStr.isNotEmpty
                  ? 'Claimed at $timeStr for $_selectedMealSession'
                  : 'Already claimed for this session',
            },
          );
        } else {
          final message = res['message']?.toString() ?? 'Invalid ticket or meal access expired.';
          _showError('Access Denied: $message');
        }
        return;
      } catch (err) {
        debugPrint('Online meal RPC failed, attempting offline fallback: $err');
      }
    }

    // Offline meal verification logic
    await _handleOfflineMeal(ticketId);
  }

  Future<void> _handleOfflineMeal(String ticketId) async {
    final participant = await _localDb.getParticipant(ticketId);
    if (participant == null) {
      _showError('Badge Not Found: No participant record found offline.');
      return;
    }

    final hasRedeemed = await _localDb.hasRedeemedMeal(ticketId, _selectedMealSession);
    if (hasRedeemed) {
      _showWarning(
        'Meal Already Redeemed (Offline)',
        {
          'name': participant.name,
          'organization': participant.organization,
          'details': 'Already marked as claimed for $_selectedMealSession',
        },
      );
    } else {
      final nowUtc = DateTime.now().toUtc().toIso8601String();
      await _localDb.addMealRedemption(
        nowUtc,
        ticketId,
        _selectedMealSession,
        _deviceId,
        scannedAt: nowUtc,
      );

      // Queue for background sync
      await _localDb.addToQueue('verify_meal_access', {
        'p_id': ticketId,
        'p_session': _selectedMealSession,
      });

      _showSuccess(
        'Meal Access Granted (Offline)',
        {
          'name': participant.name,
          'organization': participant.organization,
          'details': 'Session: $_selectedMealSession (Saved locally)',
        },
      );
    }
  }

  void _handleGeneralError(dynamic e, String rawId) {
    debugPrint('Scan error: $e');
    final errStr = e.toString().toLowerCase();

    if (errStr.contains('socketexception') || errStr.contains('network') || errStr.contains('timeout')) {
      _showError('Network connection failed. Device is attempting offline mode.');
    } else if (errStr.contains('not configured')) {
      _showError('Supabase is not configured. Please supply keys in .env.');
    } else {
      _showError('Unable to process scan. Please verify attendee badge manually.');
    }
  }

  void _showSuccess(String title, [Map<String, dynamic>? data]) {
    _audioService.playSuccess();
    HapticsService.success();
    setState(() => _lastResult = ScanResultData.success(title, data ?? {}));
  }

  void _showWarning(String title, [Map<String, dynamic>? data]) {
    _audioService.playWarning();
    HapticsService.warning();
    setState(() => _lastResult = ScanResultData.warning(title, data));
  }

  void _showError(String title) {
    _audioService.playError();
    HapticsService.error();
    setState(() => _lastResult = ScanResultData.error(title));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _mode == 'registration' ? 'Registration Desk Scanner' : 'Meal Gate Scanner',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            if (_deviceId.isNotEmpty)
              Text(
                'Device ID: $_deviceId',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
          ],
        ),
        backgroundColor: AppColors.surface,
        actions: [
          IconButton(
            tooltip: 'Toggle Flashlight',
            icon: const Icon(Icons.flash_on, color: Colors.amber),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Station Mode Segmented Control
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppColors.surface,
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'registration',
                        icon: Icon(Icons.person_pin_outlined),
                        label: Text('Check-in'),
                      ),
                      ButtonSegment(
                        value: 'meal',
                        icon: Icon(Icons.restaurant_outlined),
                        label: Text('Meals'),
                      ),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() {
                        _mode = newSelection.first;
                        _lastResult = null;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          // Meal Session Picker (Shown only in meal mode)
          if (_mode == 'meal')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.surface,
              child: DropdownButtonFormField<String>(
                initialValue: _selectedMealSession,
                decoration: const InputDecoration(
                  labelText: 'Active Meal Session',
                  prefixIcon: Icon(Icons.fastfood, color: AppColors.ieeeBlue),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                items: MealSessions.sessions.map((session) {
                  return DropdownMenuItem(
                    value: session,
                    child: Text(
                      session.replaceAll('_', ' '),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedMealSession = val;
                      _lastResult = null;
                    });
                  }
                },
              ),
            ),

          // Scanner Feed Viewfinder
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _handleScan,
                ),
                ScanHudOverlay(
                  isProcessing: _isProcessing,
                  scanResult: _lastResult,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
