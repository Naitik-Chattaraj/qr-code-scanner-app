import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/config.dart';
import '../models/participant.dart';
import 'device_service.dart';

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

    await Supabase.initialize(
      url: Config.supabaseUrl,
      publishableKey: Config.supabaseKey,
    );
  }

  Future<List<Participant>> fetchAllParticipants() async {
    if (!isConfigured) return [];
    final response = await client.from('event_participants').select();
    return (response as List).map((data) => Participant.fromJson(data)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchAllMealRedemptions() async {
    if (!isConfigured) return [];
    final response = await client.from('meal_redemptions').select();
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> registerAttendee(String participantId) async {
    if (!isConfigured) {
      throw Exception('Supabase is not configured. Provide SUPABASE_KEY in .env');
    }
    final deviceId = await _deviceService.getDeviceId();
    
    // Call RPC
    final response = await client.rpc('register_attendee', params: {
      'p_id': participantId,
      'scanner_id': deviceId,
    });
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> verifyMealAccess(String participantId, String sessionName) async {
    if (!isConfigured) {
      throw Exception('Supabase is not configured. Provide SUPABASE_KEY in .env');
    }
    final deviceId = await _deviceService.getDeviceId();
    
    // Call RPC
    final response = await client.rpc('verify_meal_access', params: {
      'p_id': participantId,
      'p_meal_session': sessionName,
      'scanner_id': deviceId,
    });
    return response as Map<String, dynamic>;
  }
}
