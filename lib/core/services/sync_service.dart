import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../database/local_database.dart';
import 'supabase_service.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final LocalDatabase _localDb = LocalDatabase.instance;
  final SupabaseService _supabaseService = SupabaseService();
  final Connectivity _connectivity = Connectivity();

  bool _isSyncing = false;
  bool _isOnlineState = true; // Assume online until proven otherwise
  Timer? _periodicSyncTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  Future<void> initialize() async {
    // Initial check
    try {
      final results = await _connectivity.checkConnectivity();
      _isOnlineState = results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      _isOnlineState = false;
    }

    // Auto-init Supabase if not yet ready
    if (_isOnlineState && !SupabaseService.isConfigured) {
      await SupabaseService.initialize();
    }

    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) async {
      _isOnlineState = results.any((r) => r != ConnectivityResult.none);
      if (_isOnlineState) {
        if (!SupabaseService.isConfigured) {
          await SupabaseService.initialize();
        }
        syncData();
      }
    });

    // Initial sync
    await syncData();

    // Periodic sync every 2 minutes
    _periodicSyncTimer = Timer.periodic(const Duration(minutes: 2), (_) => syncData());
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _periodicSyncTimer?.cancel();
  }

  // Synchronous online check to reduce scan latency
  bool isOnlineSync() {
    return _isOnlineState && SupabaseService.isConfigured;
  }

  Future<bool> isOnline() async {
    if (!SupabaseService.isConfigured) {
      await SupabaseService.initialize();
    }
    return _isOnlineState && SupabaseService.isConfigured;
  }

  Future<void> syncData() async {
    if (_isSyncing) return;
    if (!SupabaseService.isConfigured) {
      await SupabaseService.initialize();
    }
    if (!SupabaseService.isConfigured) return;
    if (!(await isOnline())) return;

    _isSyncing = true;
    try {
      // 1. Push pending actions from offline queue
      final queue = await _localDb.getQueue();
      for (var item in queue) {
        final action = item['action'] as String;
        final payloadStr = item['payload'] as String;
        final id = item['id'] as int;

        try {
          final payload = jsonDecode(payloadStr) as Map<String, dynamic>;
          final pId = (payload['p_id'] ?? '').toString();
          if (pId.isEmpty) {
            await _localDb.removeFromQueue(id);
            continue;
          }

          if (action == 'verify_and_checkin' || action == 'check_in_attendee' || action == 'register_attendee') {
            await _supabaseService.registerAttendee(
              participantId: pId,
              name: payload['p_name'] as String?,
              email: payload['p_email'] as String?,
              mobile: payload['p_mobile'] as String?,
              organization: payload['p_org'] as String?,
              eventId: payload['p_event_id'] as String?,
            );
          } else if (action == 'verify_meal_access') {
            final session = (payload['p_session'] ?? 'OCT_08_DINNER').toString();
            await _supabaseService.verifyMealAccess(
              participantId: pId,
              sessionName: session,
            );
          }
          await _localDb.removeFromQueue(id);
        } catch (queueErr) {
          debugPrint('Error syncing queue item $id: $queueErr');
        }
      }

      // 2. Comprehensive Reconciliation: Push any local meal redemptions not yet in Supabase
      final remoteRedemptions = await _supabaseService.fetchAllMealRedemptions();
      final remoteRedemptionKeys = <String>{};
      for (var r in remoteRedemptions) {
        final pid = (r['participant_id'] ?? '').toString();
        final session = (r['meal_session'] ?? '').toString();
        if (pid.isNotEmpty && session.isNotEmpty) {
          remoteRedemptionKeys.add('${pid}_$session');
        }
      }

      final localRedemptions = await _localDb.getAllMealRedemptions();
      for (var loc in localRedemptions) {
        final pid = (loc['participant_id'] ?? '').toString();
        final session = (loc['meal_session'] ?? '').toString();
        if (pid.isNotEmpty && session.isNotEmpty) {
          final key = '${pid}_$session';
          if (!remoteRedemptionKeys.contains(key)) {
            // Local redemption missing from Supabase: push to Supabase!
            try {
              debugPrint('Reconciling missing meal redemption to Supabase: $key');
              await _supabaseService.verifyMealAccess(
                participantId: pid,
                sessionName: session,
              );
              remoteRedemptionKeys.add(key);
            } catch (e) {
              debugPrint('Failed to reconcile meal redemption $key to Supabase: $e');
            }
          }
        }
      }

      // 3. Comprehensive Reconciliation: Push any local check-ins not yet in Supabase
      final remoteParticipants = await _supabaseService.fetchAllParticipants();
      final remoteRegisteredMap = <String, bool>{};
      for (var p in remoteParticipants) {
        remoteRegisteredMap[p.participantId] = p.isRegistered;
      }

      final localParticipants = await _localDb.getAllParticipants();
      for (var lp in localParticipants) {
        if (lp.isRegistered) {
          final isRemoteRegistered = remoteRegisteredMap[lp.participantId] ?? false;
          if (!isRemoteRegistered) {
            try {
              debugPrint('Reconciling missing attendee registration to Supabase: ${lp.participantId}');
              await _supabaseService.registerAttendee(
                participantId: lp.participantId,
                name: lp.name,
                email: lp.email,
                mobile: lp.mobileNumber,
                organization: lp.organization,
                eventId: lp.eventId,
              );
            } catch (e) {
              debugPrint('Failed to reconcile attendee ${lp.participantId} to Supabase: $e');
            }
          }
        }
      }

      // 4. Pull fresh authoritative snapshot from Supabase and synchronize local tables
      final freshParticipants = await _supabaseService.fetchAllParticipants();
      if (freshParticipants.isNotEmpty) {
        await _localDb.insertParticipants(freshParticipants);
      }

      final freshRedemptions = await _supabaseService.fetchAllMealRedemptions();
      // Replace local meal redemptions with the clean, deduplicated authoritative records from Supabase!
      await _localDb.replaceMealRedemptions(freshRedemptions);

      // 5. Update last sync time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_sync', DateTime.now().toUtc().toIso8601String());
    } catch (e) {
      debugPrint('Sync failed: $e');
    } finally {
      _isSyncing = false;
    }
  }
}
