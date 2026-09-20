import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SecurityRiskProbe {
  static Future<void> run() async => _invoke(<String, dynamic>{});

  static Future<void> reportSignal(
    String eventType, {
    String? screen,
    String? appVersion,
    String? details,
  }) async {
    final payload = <String, dynamic>{
      'event_type': eventType,
      if (screen != null && screen.trim().isNotEmpty) 'screen': screen.trim(),
      if (appVersion != null && appVersion.trim().isNotEmpty)
        'app_version': appVersion.trim(),
      if (details != null && details.trim().isNotEmpty)
        'details': details.trim(),
    };
    await _invoke(payload);
  }

  static Future<void> _invoke(Map<String, dynamic> body) async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;

    if (session == null) {
      debugPrint('SECURITY_RISK_PROBE: NO_SESSION');
      return;
    }

    try {
      final response = await client.functions.invoke(
        'security-risk',
        body: body,
      );

      debugPrint(
        'SECURITY_RISK_PROBE: status=${response.status} data=${response.data}',
      );
    } catch (e) {
      // Security telemetry is deliberately fail-open for the user experience:
      // a telemetry outage must never lock a valid session out of the app.
      debugPrint('SECURITY_RISK_PROBE: ERROR=$e');
    }
  }
}
