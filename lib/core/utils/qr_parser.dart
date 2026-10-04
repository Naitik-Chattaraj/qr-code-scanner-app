import 'dart:convert';

class QrPayload {
  final String participantId;
  final String? eventId;
  final String? name;
  final String? email;
  final String? mobileNumber;
  final String? organization;

  QrPayload({
    required this.participantId,
    this.eventId,
    this.name,
    this.email,
    this.mobileNumber,
    this.organization,
  });
}

class QrParser {
  /// Extracts full QRPayload from raw QR scan data.
  /// Handles:
  /// - Plain ticket ID: "6aa97b607979825c5e83ce26"
  /// - JSON payloads with full attendee details
  /// - URLs
  static QrPayload parsePayload(String raw) {
    String trimmed = raw.trim();
    if (trimmed.isEmpty) return QrPayload(participantId: '');

    // 1. Try parsing as JSON
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) {
          // Extract ID
          String? id;
          for (final key in ['participantId', 'participant_id', 'id', 'ticketId', 'ticket_id', 'uid', 'ticket']) {
            if (decoded.containsKey(key) && decoded[key] != null) {
              final val = decoded[key].toString().trim();
              if (val.isNotEmpty) {
                id = val;
                break;
              }
            }
          }

          if (id != null) {
            String? extract(List<String> keys) {
              for (final k in keys) {
                if (decoded.containsKey(k) && decoded[k] != null) {
                  final v = decoded[k].toString().trim();
                  if (v.isNotEmpty) return v;
                }
              }
              return null;
            }

            return QrPayload(
              participantId: id,
              eventId: extract(['eventId', 'event_id', 'event']),
              name: extract(['name', 'fullName', 'full_name', 'attendeeName', 'attendee_name']),
              email: extract(['email', 'emailAddress', 'email_address']),
              mobileNumber: extract(['mobileNumber', 'mobile_number', 'mobile', 'phone', 'phoneNumber', 'phone_number']),
              organization: extract(['organization', 'org', 'company', 'affiliation', 'institution']),
            );
          }
        }
      } catch (_) {
        // Not valid JSON, continue
      }
    }

    // 2. Try parsing as URL
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      try {
        final uri = Uri.parse(trimmed);
        for (final param in ['id', 'participant_id', 'ticket', 'uid']) {
          final queryVal = uri.queryParameters[param]?.trim();
          if (queryVal != null && queryVal.isNotEmpty) {
            return QrPayload(participantId: queryVal);
          }
        }
        if (uri.pathSegments.isNotEmpty) {
          final last = uri.pathSegments.last.trim();
          if (last.isNotEmpty && last != 'ticket' && last != 'scan') {
            return QrPayload(participantId: last);
          }
        }
      } catch (_) {
        // Continue to fallback
      }
    }

    // 3. Fallback: plain text
    return QrPayload(participantId: trimmed);
  }
}
