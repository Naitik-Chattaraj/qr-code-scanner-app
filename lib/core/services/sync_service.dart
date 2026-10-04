import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../database/local_database.dart';
import 'supabase_service.dart';

class SyncService {
  final LocalDatabase _localDb = LocalDatabase.instance;
  final SupabaseService _supabaseService = SupabaseService();
  final Connectivity _connectivity = Connectivity();
  
  bool _isSyncing = false;
  Timer? _periodicSyncTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  Future<void> initialize() async {
    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (results.any((r) => r != ConnectivityResult.none)) {
        syncData();
      }
    });
    
    // Initial sync
    await syncData();
    
    // Periodic sync every 5 minutes
    _periodicSyncTimer = Timer.periodic(const Duration(minutes: 5), (_) => syncData());
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _periodicSyncTimer?.cancel();
  }

  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  Future<void> syncData() async {
    if (_isSyncing) return;
    if (!SupabaseService.isConfigured) return;
    if (!(await isOnline())) return;

    _isSyncing = true;
    try {
      // 1. Push pending actions from queue
      final queue = await _localDb.getQueue();
      for (var item in queue) {
        final action = item['action'] as String;
        final payloadStr = item['payload'] as String;
        final id = item['id'] as int;

        try {
          final payload = jsonDecode(payloadStr) as Map<String, dynamic>;
          if (action == 'register_attendee') {
            await _supabaseService.registerAttendee(payload['p_id'] as String);
          } else if (action == 'verify_meal_access') {
            await _supabaseService.verifyMealAccess(
              payload['p_id'] as String,
              payload['p_session'] as String,
            );
          }
          await _localDb.removeFromQueue(id);
        } catch (queueErr) {
          debugPrint('Error syncing queue item $id: $queueErr');
        }
      }

      // 2. Pull down fresh data from Supabase
      final participants = await _supabaseService.fetchAllParticipants();
      if (participants.isNotEmpty) {
        await _localDb.insertParticipants(participants);
      }
      
      final redemptions = await _supabaseService.fetchAllMealRedemptions();
      if (redemptions.isNotEmpty) {
         await _localDb.insertMealRedemptions(redemptions);
      }
      
      // Update last sync time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_sync', DateTime.now().toIso8601String());
      
    } catch (e) {
      debugPrint('Sync failed: $e');
    } finally {
      _isSyncing = false;
    }
  }
}
