import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:phone_state/phone_state.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'analyze_call_screen.dart';

class CallDetectionServiceEnhanced {
  static final CallDetectionServiceEnhanced _instance = CallDetectionServiceEnhanced._internal( );
  factory CallDetectionServiceEnhanced() => _instance;
  CallDetectionServiceEnhanced._internal();

  StreamSubscription? _subscription;
  static const String _checkNumberUrl = 'https://first-api-77id.onrender.com/check-number';

  void startListening(BuildContext context ) {
    _subscription = PhoneState.stream.listen((PhoneState event) async {
      if (event.status == PhoneStateStatus.CALL_INCOMING) {
        final String? phoneNumber = event.number;
        if (phoneNumber != null && phoneNumber.isNotEmpty) {
          _checkScamRisk(context, phoneNumber);
        }
      }
    });
  }

  void stopListening() {
    _subscription?.cancel();
  }

  Future<void> _checkScamRisk(BuildContext context, String phoneNumber) async {
    try {
      final response = await http.get(Uri.parse('$_checkNumberUrl?phone=$phoneNumber' ));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['risk_level'] == 'High' || data['risk_level'] == 'Medium') {
          _showSuspiciousPopup(context, phoneNumber, data['risk_level']);
        }
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  void _showSuspiciousPopup(BuildContext context, String phoneNumber, String riskLevel) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Suspicious Number'),
        content: Text('Call from $phoneNumber is flagged as $riskLevel risk. Switch to speaker?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('No')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => AnalyzeCallScreen(autoStartRecording: true)));
            },
            child: Text('Yes'),
          ),
        ],
      ),
    );
  }

  Future<bool> requestPermissions() async {
    final status = await [Permission.phone, Permission.microphone].request();
    return status[Permission.phone]!.isGranted && status[Permission.microphone]!.isGranted;
  }
}
