import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceService {
  static const String _deviceIdKey = 'device_id';

  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_deviceIdKey);
    
    if (deviceId == null) {
      deviceId = _generateDeviceId();
      await prefs.setString(_deviceIdKey, deviceId);
    }
    
    return deviceId;
  }

  String _generateDeviceId() {
    final random = Random();
    int id = random.nextInt(900000) + 100000; // 6 digit number
    return id.toString();
  }
}
