import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:phone_state/phone_state.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'analyze_call_screen.dart';

class CallDetectionService {
  static final CallDetectionService _instance = CallDetectionService._internal();
  factory CallDetectionService() => _instance;
  CallDetectionService._internal();

  StreamSubscription? _subscription;
  static const String _checkNumberUrl = 'https://first-api-77id.onrender.com/check-number';

  void startListening(BuildContext context) {
    _subscription = PhoneState.stream.listen((PhoneState event) async {
      // phone_state 3.0.1+ uses status enum: NOTHING, CALL_INCOMING, CALL_STARTED, CALL_ENDED
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
      final response = await http.get(Uri.parse('$_checkNumberUrl?phone=$phoneNumber'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String riskLevel = data['risk_level'];
        
        if (riskLevel == 'High' || riskLevel == 'Medium') {
          _showSuspiciousPopup(context, phoneNumber, riskLevel);
        }
      }
    } catch (e) {
      debugPrint('Error checking number: $e');
    }
  }

  void _showSuspiciousPopup(BuildContext context, String phoneNumber, String riskLevel) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 10),
            Text('Suspicious Number'),
          ],
        ),
        content: Text(
          'Incoming call from $phoneNumber has been flagged as $riskLevel risk.\n\nSwitch to speaker so we can help protect you?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('No thanks'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToAnalysis(context, startRecording: true);
            },
            child: Text('Yes, Protect Me'),
          ),
        ],
      ),
    );
  }

  void _navigateToAnalysis(BuildContext context, {bool startRecording = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnalyzeCallScreen(autoStartRecording: startRecording),
      ),
    );
  }

  Future<bool> requestPermissions() async {
    final status = await [
      Permission.phone,
      Permission.microphone,
    ].request();
    
    return status[Permission.phone]!.isGranted && 
           status[Permission.microphone]!.isGranted;
  }
}
