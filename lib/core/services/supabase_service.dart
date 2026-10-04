import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/config.dart';
import '../models/participant.dart';
import 'device_service.dart';

class ConnectionTestResult {
  final bool isConnected;
  final int latencyMs;
  final int participantCount;
  final String? errorMessage;

  ConnectionTestResult({
    required this.isConnected,
    required this.latencyMs,
    required this.participantCount,
    this.errorMessage,
  });
}

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;
  final DeviceService _deviceService = DeviceService();

  static bool get isConfigured => Config.supabaseKey.isNotEmpty;

  static Future<void> initialize() async {
    if (!isConfigured) {
      debugPrint(
        'WARNING: Config.supabaseKey is empty. '
        'Provide credentials via --dart-define-from-file=.env to connect to live Supabase.',
      );
      return;
    }

    try {
      await Supabase.initialize(
        url: Config.supabaseUrl,
        publishableKey: Config.supabaseKey,
      );
      debugPrint('Supabase initialized successfully.');
    } catch (e) {
      debugPrint('Supabase initialization failed: $e');
    }
  }

  /// Live connection test returning latency and participant count
  Future<ConnectionTestResult> testConnection() async {
    if (!isConfigured) {
      return ConnectionTestResult(
        isConnected: false,
        latencyMs: 0,
        participantCount: 0,
        errorMessage: 'Supabase credentials are not configured in the app.',
      );
    }

    final stopwatch = Stopwatch()..start();
    try {
      final response = await client
          .from('event_participants')
          .select('participant_id')
          .limit(100);
      stopwatch.stop();

      final count = (response as List).length;
      return ConnectionTestResult(
        isConnected: true,
        latencyMs: stopwatch.elapsedMilliseconds,
        participantCount: count,
      );
    } catch (e) {
      stopwatch.stop();
      return ConnectionTestResult(
        isConnected: false,
        latencyMs: stopwatch.elapsedMilliseconds,
        participantCount: 0,
        errorMessage: e.toString(),
      );
    }
  }

  /// Fetch all event participants
  Future<List<Participant>> fetchAllParticipants() async {
    if (!isConfigured) return [];
    try {
      final response = await client.from('event_participants').select();
      return (response as List)
          .map((data) => Participant.fromJson(data as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('fetchAllParticipants error: $e');
      rethrow;
    }
  }

  /// Fetch all meal redemption records
  Future<List<Map<String, dynamic>>> fetchAllMealRedemptions() async {
    if (!isConfigured) return [];
    try {
      final response = await client.from('meal_redemptions').select();
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('fetchAllMealRedemptions error: $e');
      rethrow;
    }
  }

  /// Check-in attendee at registration desk
  /// Uses live Supabase RPC: verify_and_checkin(p_id, scanner_id)
  Future<Map<String, dynamic>> checkInAttendee(String participantId) async {
    if (!isConfigured) {
      throw Exception('Supabase is not configured.');
    }
    final deviceId = await _deviceService.getDeviceId();

    final response = await client.rpc(
      'verify_and_checkin',
      params: {
        'p_id': participantId,
        'scanner_id': deviceId,
      },
    );
    return Map<String, dynamic>.from(response as Map);
  }

  /// Register a new attendee
  /// Uses live Supabase RPC: register_attendee
  Future<Map<String, dynamic>> registerAttendee({
    required String participantId,
    String? name,
    String? email,
    String? mobile,
    String? organization,
    String? eventId,
  }) async {
    if (!isConfigured) {
      throw Exception('Supabase is not configured.');
    }
    final deviceId = await _deviceService.getDeviceId();

    final response = await client.rpc(
      'register_attendee',
      params: {
        'p_id': participantId,
        'p_name': name,
        'p_email': email,
        'p_mobile': mobile,
        'p_org': organization,
        'p_event_id': eventId,
        'p_scanner_id': deviceId,
      },
    );
    return Map<String, dynamic>.from(response as Map);
  }

  /// Verify and redeem meal access
  /// Uses live Supabase RPC: verify_meal_access(p_id, p_scanner_id, p_session)
  Future<Map<String, dynamic>> verifyMealAccess({
    required String participantId,
    required String sessionName,
  }) async {
    if (!isConfigured) {
      throw Exception('Supabase is not configured.');
    }
    final deviceId = await _deviceService.getDeviceId();

    final response = await client.rpc(
      'verify_meal_access',
      params: {
        'p_id': participantId,
        'p_scanner_id': deviceId,
        'p_session': sessionName,
      },
    );
    return Map<String, dynamic>.from(response as Map);
  }
}
