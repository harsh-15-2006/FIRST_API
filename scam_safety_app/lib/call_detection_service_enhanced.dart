import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:phone_state/phone_state.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'analyze_call_screen.dart';

class CallDetectionServiceEnhanced {
  static final CallDetectionServiceEnhanced _instance =
      CallDetectionServiceEnhanced._internal();
  factory CallDetectionServiceEnhanced() => _instance;
  CallDetectionServiceEnhanced._internal();

  StreamSubscription<PhoneState>? _subscription;
  static const String _checkNumberUrl =
      'https://first-api-77id.onrender.com/check-number';

  /// Requests the permissions this service needs BEFORE listening starts.
  /// phone_state's own docs state READ_CALL_LOG is required to actually
  /// receive the caller's number — without it, event.number comes back null.
  Future<bool> requestPermissions() async {
    final statuses = await [
      Permission.phone,
      Permission.microphone,
      Permission.phone,
    ].request();

    return statuses[Permission.phone]!.isGranted &&
        statuses[Permission.microphone]!.isGranted;
  }

  /// Call requestPermissions() first and confirm it returns true before
  /// calling this — starting the stream without granted permissions means
  /// events may never fire or numbers may come back null.
  void startListening(BuildContext context) {
    _subscription = PhoneState.stream.listen((PhoneState event) async {
      if (event.status == PhoneStateStatus.CALL_INCOMING) {
        final String? phoneNumber = event.number;
        if (phoneNumber != null && phoneNumber.isNotEmpty) {
          await _checkScamRisk(context, phoneNumber);
        }
      }
    });
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  Future<void> _checkScamRisk(BuildContext context, String phoneNumber) async {
    try {
      final response = await http
          .get(Uri.parse('$_checkNumberUrl?phone=$phoneNumber'))
          .timeout(const Duration(seconds: 10));

      // The widget tree may have been disposed while this await was in
      // flight (e.g. user navigated away) — using a stale context throws.
      if (!context.mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final riskLevel = data['risk_level'];
        if (riskLevel == 'High' || riskLevel == 'Medium') {
          _showSuspiciousPopup(context, phoneNumber, riskLevel);
        }
      } else {
        debugPrint('check-number returned ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('check-number request failed: $e');
    }
  }

  void _showSuspiciousPopup(
    BuildContext context,
    String phoneNumber,
    String riskLevel,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Suspicious Number'),
        content: Text(
          'Call from $phoneNumber is flagged as $riskLevel risk. Switch to speaker and let us listen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              // NOTE: this navigates to the existing Analyze screen as-is.
              // It does NOT auto-start recording yet — AnalyzeCallScreen's
              // real constructor takes no parameters right now. If you want
              // recording to start automatically the moment this popup is
              // accepted, that requires an actual edit to
              // analyze_call_screen.dart to add and use an
              // autoStartRecording flag — ask for that change explicitly
              // and I'll make it, rather than assume it silently.
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AnalyzeCallScreen()),
              );
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }
}