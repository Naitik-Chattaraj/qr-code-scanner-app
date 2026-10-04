import 'dart:convert';

class QrParser {
  /// Extracts a clean, normalized participant/ticket ID from raw QR scan data.
  /// Handles:
  /// - Plain ticket ID: "6aa97b607979825c5e83ce26"
  /// - JSON payloads: `{"participant_id": "...", ...}` or `{"id": "...", ...}`
  /// - URLs: `https://example.com/ticket?id=6aa97b607979825c5e83ce26`
  static String extractParticipantId(String raw) {
    String trimmed = raw.trim();
    if (trimmed.isEmpty) return '';

    // 1. Try parsing as JSON
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) {
          for (final key in [
            'participant_id',
            'id',
            'ticket_id',
            'event_id',
            'uid',
            'ticket'
          ]) {
            if (decoded.containsKey(key) && decoded[key] != null) {
              final val = decoded[key].toString().trim();
              if (val.isNotEmpty) return val;
            }
          }
        }
      } catch (_) {
        // Not valid JSON, continue to other checks
      }
    }

    // 2. Try parsing as URL
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      try {
        final uri = Uri.parse(trimmed);
        // Check query parameters
        for (final param in ['id', 'participant_id', 'ticket', 'uid']) {
          final queryVal = uri.queryParameters[param]?.trim();
          if (queryVal != null && queryVal.isNotEmpty) {
            return queryVal;
          }
        }
        // Check last path segment
        if (uri.pathSegments.isNotEmpty) {
          final last = uri.pathSegments.last.trim();
          if (last.isNotEmpty && last != 'ticket' && last != 'scan') {
            return last;
          }
        }
      } catch (_) {
        // Continue to fallback
      }
    }

    // 3. Fallback: return trimmed plain text
    return trimmed;
  }
}
