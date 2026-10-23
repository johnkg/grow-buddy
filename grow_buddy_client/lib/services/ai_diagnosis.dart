import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Calls the Grow Buddy backend (grow_buddy_server), which holds the Claude API
/// key and talks to Claude. The app never sees the key.
class AiDiagnosis {
  static Future<String> diagnose({
    required String serverUrl,
    String appToken = '',
    required String plantName,
    required double afternoonSunHrs,
    required List<String> symptoms,
    required String notes,
    Uint8List? photoBytes,
    String photoMime = 'image/jpeg',
  }) async {
    final base = serverUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final body = <String, dynamic>{
      'plantName': plantName,
      'sunHrs': afternoonSunHrs,
      'symptoms': symptoms,
      'notes': notes.trim(),
      if (photoBytes != null) 'photoBase64': base64Encode(photoBytes),
      if (photoBytes != null) 'photoMime': photoMime,
    };

    final res = await http
        .post(
          Uri.parse('$base/api/diagnose'),
          headers: {
            'content-type': 'application/json',
            if (appToken.isNotEmpty) 'x-app-token': appToken,
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 45));

    Map<String, dynamic>? json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      json = null;
    }
    if (res.statusCode != 200) {
      final msg = json?['error'] ?? 'HTTP ${res.statusCode}';
      throw Exception('Diagnosis failed: $msg');
    }
    final text = json?['diagnosis'];
    if (text is! String || text.isEmpty) {
      throw Exception('Diagnosis failed: empty response');
    }
    return text;
  }
}
