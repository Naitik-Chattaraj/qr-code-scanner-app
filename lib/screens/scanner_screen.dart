import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/meal_sessions.dart';
import '../core/models/scan_result.dart';
import '../core/models/participant.dart';
import '../core/services/audio_service.dart';
import '../core/services/haptics_service.dart';
import '../core/services/supabase_service.dart';
import '../core/services/sync_service.dart';
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

  String _mode = 'registration'; // 'registration' or 'meal'
  String _selectedMealSession = MealSessions.sessions.first;
  
  bool _isProcessing = false;
  ScanResultData? _lastResult;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleScan(BarcodeCapture capture) async {
    if (_isProcessing || capture.barcodes.isEmpty) return;
    
    final String? qrData = capture.barcodes.first.rawValue;
    if (qrData == null || qrData.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _lastResult = null;
    });

    try {
      final isOnline = await _syncService.isOnline();
      
      if (_mode == 'registration') {
        if (isOnline) {
          final res = await _supabaseService.registerAttendee(qrData);
          _processResponse(res);
        } else {
          // Offline Registration
          final participant = await _localDb.getParticipant(qrData);
          if (participant == null) {
            _showError('Participant not found offline.');
          } else if (participant.isCheckedIn) {
            _showWarning('Already checked in!', participant.toJson());
          } else {
            // Queue offline action
            await _localDb.addToQueue('register_attendee', {'p_id': qrData});
            // Update local DB to reflect checked in
            await _localDb.updateParticipant(
              Participant(
                id: participant.id, name: participant.name, email: participant.email,
                mobile: participant.mobile, organization: participant.organization,
                eventId: participant.eventId, regStatus: participant.regStatus,
                isCheckedIn: true, totalMealsTaken: participant.totalMealsTaken,
              )
            );
            _showSuccess('Checked in (Offline)', participant.toJson());
          }
        }
      } else {
        // Meal Mode
        if (isOnline) {
          final res = await _supabaseService.verifyMealAccess(qrData, _selectedMealSession);
          _processResponse(res);
        } else {
          // Offline Meal
          final participant = await _localDb.getParticipant(qrData);
          if (participant == null) {
            _showError('Participant not found offline.');
          } else {
            final hasRedeemed = await _localDb.hasRedeemedMeal(qrData, _selectedMealSession);
            if (hasRedeemed) {
              _showError('Meal already redeemed!');
            } else {
              // Queue offline action
              await _localDb.addToQueue('verify_meal_access', {'p_id': qrData, 'p_session': _selectedMealSession});
              // Update local DB
              await _localDb.addMealRedemption(DateTime.now().toIso8601String(), qrData, _selectedMealSession, 'offline');
              _showSuccess('Meal access granted (Offline)', participant.toJson());
            }
          }
        }
      }
    } catch (e) {
      _showError('Scan failed: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
      // Clear result after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _lastResult = null);
      });
    }
  }

  void _processResponse(Map<String, dynamic> res) {
    if (res['status'] == 'success') {
      _showSuccess(res['message'], res['data']);
    } else if (res['status'] == 'warning') {
      _showWarning(res['message'], res['data']);
    } else {
      _showError(res['message']);
    }
  }

  void _showSuccess(String message, [Map<String, dynamic>? data]) {
    _audioService.playSuccess();
    HapticsService.success();
    setState(() => _lastResult = ScanResultData.success(message, data ?? {}));
  }

  void _showWarning(String message, [Map<String, dynamic>? data]) {
    _audioService.playWarning();
    HapticsService.warning();
    setState(() => _lastResult = ScanResultData.warning(message, data));
  }

  void _showError(String message) {
    _audioService.playError();
    HapticsService.error();
    setState(() => _lastResult = ScanResultData.error(message));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner'),
        backgroundColor: AppColors.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on, color: Colors.yellow),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Mode Selector
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.surface,
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'registration', label: Text('Check-in')),
                      ButtonSegment(value: 'meal', label: Text('Meals')),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() {
                        _mode = newSelection.first;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          
          if (_mode == 'meal')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.surface,
              child: DropdownButtonFormField<String>(
                initialValue: _selectedMealSession,
                decoration: const InputDecoration(
                  labelText: 'Select Meal Session',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                items: MealSessions.sessions.map((session) {
                  return DropdownMenuItem(
                    value: session,
                    child: Text(session),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedMealSession = val);
                },
              ),
            ),

          // Scanner Area
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
