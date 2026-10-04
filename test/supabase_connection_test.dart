import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrcode_scanner/core/constants/config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _AllowRealHttp extends HttpOverrides {}

void main() {
  test('Supabase live connection test with Config credentials', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = _AllowRealHttp();
    SharedPreferences.setMockInitialValues({});
    expect(Config.supabaseUrl.isNotEmpty, true);
    expect(Config.supabaseKey.isNotEmpty, true);

    await Supabase.initialize(
      url: Config.supabaseUrl,
      publishableKey: Config.supabaseKey,
    );

    final client = Supabase.instance.client;
    final response = await client
        .from('event_participants')
        .select('participant_id')
        .limit(5);

    expect(response.isNotEmpty, true);
    debugPrint('Successfully connected to Supabase! Fetched ${response.length} sample records.');
  });
}
