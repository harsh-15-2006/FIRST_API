import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'app_theme.dart';

enum _InputMode { text, audio }

class AnalyzeCallScreen extends StatefulWidget {
  final bool autoStartRecording;
  const AnalyzeCallScreen({super.key, this.autoStartRecording = false});

  @override
  State<AnalyzeCallScreen> createState() => _AnalyzeCallScreenState();
}

class _AnalyzeCallScreenState extends State<AnalyzeCallScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.autoStartRecording) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _mode = _InputMode.audio;
        });
        _startRecording();
      });
    }
  }
  final TextEditingController _transcriptController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  // Response fields from the real backend (shared by both text and audio flows)
  String? _riskLevel;
  List<dynamic> _flags = [];
  List<dynamic> _flaggedPhrases = [];
  String? _explanation;
  String? _transcriptFromAudio; // only populated when using the audio flow

  static const String _textApiUrl =
      'https://first-api-77id.onrender.com/analyze-call';
  static const String _audioApiUrl =
      'https://first-api-77id.onrender.com/analyze-call-audio';

  // ---- Input mode toggle (Type vs Record) ----
  _InputMode _mode = _InputMode.text;

  // ---- Audio recording state ----
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _recordedFilePath;

  // ---- Text-to-speech ----
  final FlutterTts _tts = FlutterTts();

  void _resetResults() {
    _errorMessage = null;
    _riskLevel = null;
    _flags = [];
    _flaggedPhrases = [];
    _explanation = null;
    _transcriptFromAudio = null;
  }

  // ================= TEXT FLOW (existing, unchanged) =================

  Future<void> _analyzeCall() async {
    final transcript = _transcriptController.text.trim();
    if (transcript.isEmpty) {
      setState(() {
        _resetResults();
        _errorMessage = 'Please paste or type a call transcript first.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _resetResults();
    });

    try {
      final response = await http
          .post(
            Uri.parse(_textApiUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'transcript': transcript}),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _riskLevel = data['risk_level'];
          _flags = data['flags'] ?? [];
          _flaggedPhrases = data['flagged_phrases'] ?? [];
          _explanation = data['explanation'];
        });
      } else {
        setState(() {
          _errorMessage = _extractErrorDetail(response);
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = _networkErrorMessage;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ================= AUDIO FLOW (new) =================

  Future<void> _startRecording() async {
    setState(() {
      _errorMessage = null;
    });

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      setState(() {
        _errorMessage =
            'Microphone permission is needed to record a call. Please allow it in your phone settings.';
      });
      return;
    }

    final dir = await getTemporaryDirectory();
    final filePath =
        '${dir.path}/call_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: filePath,
    );

    setState(() {
      _isRecording = true;
      _recordedFilePath = null;
      _resetResults();
    });
  }

  Future<void> _stopRecording() async {
    final path = await _recorder.stop();
    setState(() {
      _isRecording = false;
      _recordedFilePath = path;
    });
  }

  Future<void> _analyzeRecordedAudio() async {
    if (_recordedFilePath == null) {
      setState(() {
        _errorMessage = 'Please record something first.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _resetResults();
    });

    try {
      final request = http.MultipartRequest('POST', Uri.parse(_audioApiUrl));
      request.files.add(
        await http.MultipartFile.fromPath(
          'audio',
          _recordedFilePath!,
          contentType: MediaType('audio', 'm4a'),
        ),
      );

      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _transcriptFromAudio = data['transcript'];
          _riskLevel = data['risk_level'];
          _flags = data['flags'] ?? [];
          _flaggedPhrases = data['flagged_phrases'] ?? [];
          _explanation = data['explanation'];
        });
      } else {
        setState(() {
          _errorMessage = _extractErrorDetail(response);
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = _networkErrorMessage;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ================= Shared helpers =================

  String _extractErrorDetail(http.Response response) {
    String detail = 'Server error (${response.statusCode}).';
    try {
      final errorBody = jsonDecode(response.body);
      if (errorBody['detail'] != null) {
        detail = errorBody['detail'].toString();
      }
    } catch (_) {
      // response wasn't JSON, keep the generic message
    }
    return detail;
  }

  String get _networkErrorMessage =>
      'Could not reach the server. Check your internet connection, or the backend may be waking up (can take up to a minute on first request).';

  Future<void> _speakExplanation() async {
    if (_explanation == null) return;
    final riskWord = _riskLevel ?? '';
    await _tts.setSpeechRate(0.45); // slower, easier to follow
    await _tts.speak('Risk level: $riskWord. $_explanation');
  }

  @override
  void dispose() {
    _transcriptController.dispose();
    _recorder.dispose();
    _tts.stop();
    super.dispose();
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    final bool isHighRisk = _riskLevel == 'High';
    
    return Scaffold(
      backgroundColor: isHighRisk ? Colors.red.shade900 : null,
      appBar: AppBar(
        title: const Text('Analyze a Call'),
        backgroundColor: isHighRisk ? Colors.red.shade900 : null,
        foregroundColor: isHighRisk ? Colors.white : null,
      ),
      body: Container(
        color: isHighRisk ? Colors.red.shade900 : null,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isHighRisk) _buildHighRiskWarning(),
                _buildModeToggle(),
                const SizedBox(height: 16),
                if (_mode == _InputMode.text)
                  _buildTextInput()
                else
                  _buildAudioInput(),
                const SizedBox(height: 24),
                if (_errorMessage != null) _buildErrorBox(),
                if (_riskLevel != null) _buildResultBlock(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHighRiskWarning() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          const Icon(Icons.gpp_maybe_rounded, color: Colors.red, size: 60),
          const SizedBox(height: 12),
          const Text(
            'SCAM DETECTED',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This looks like a scam — please end the call immediately. We have alerted your family.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildModeToggle() {
    return SegmentedButton<_InputMode>(
      segments: const [
        ButtonSegment(
          value: _InputMode.text,
          label: Text('Type / Paste'),
          icon: Icon(Icons.edit_note),
        ),
        ButtonSegment(
          value: _InputMode.audio,
          label: Text('Record Call'),
          icon: Icon(Icons.mic),
        ),
      ],
      selected: {_mode},
      onSelectionChanged: _isLoading || _isRecording
          ? null
          : (selection) {
              setState(() {
                _mode = selection.first;
                _resetResults();
              });
            },
    );
  }

  Widget _buildTextInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Paste the call transcript below:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _transcriptController,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText:
                'e.g. "This is the police. Your grandson is in custody, you must pay immediately..."',
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _isLoading ? null : _analyzeCall,
          child: _isLoading ? _loadingRow('Analyzing transcript...') : const Text('Analyze Call'),
        ),
      ],
    );
  }

  Widget _buildAudioInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Record the suspicious call or voicemail:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Center(
          child: GestureDetector(
            onTap: _isLoading
                ? null
                : (_isRecording ? _stopRecording : _startRecording),
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRecording ? Colors.red : Theme.of(context).primaryColor,
              ),
              child: Icon(
                _isRecording ? Icons.stop : Icons.mic,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            _isRecording
                ? 'Recording... tap to stop'
                : (_recordedFilePath != null
                    ? 'Recording ready'
                    : 'Tap to start recording'),
            style: const TextStyle(color: Colors.grey),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: (_isLoading || _isRecording || _recordedFilePath == null)
              ? null
              : _analyzeRecordedAudio,
          child: _isLoading
              ? _loadingRow('Analyzing recording...')
              : const Text('Analyze Recording'),
        ),
      ],
    );
  }

  Widget _loadingRow(String label) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          height: 18,
          width: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Text(label),
      ],
    );
  }

  Widget _buildErrorBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildResultBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_transcriptFromAudio != null) ...[
          const Text('Transcript:', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(_transcriptFromAudio!),
          const SizedBox(height: 16),
        ],
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.riskColor(_riskLevel).withOpacity(0.10),
            border: Border.all(color: AppTheme.riskColor(_riskLevel)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    AppTheme.riskIcon(_riskLevel),
                    color: AppTheme.riskColor(_riskLevel),
                    size: 26,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Risk Level: $_riskLevel',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.riskColor(_riskLevel),
                      ),
                    ),
                  ),
                  // Read-aloud button — key for illiterate users
                  IconButton(
                    icon: const Icon(Icons.volume_up),
                    tooltip: 'Read result aloud',
                    onPressed: _speakExplanation,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_explanation != null) Text(_explanation!),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_flags.isNotEmpty) ...[
          const Text('Flags detected:', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _flags
                .map((f) => Chip(
                      label: Text(f.toString()),
                      backgroundColor: AppTheme.riskColor(_riskLevel).withOpacity(0.12),
                      side: BorderSide(color: AppTheme.riskColor(_riskLevel).withOpacity(0.4)),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
        ],
        if (_flaggedPhrases.isNotEmpty) ...[
          const Text('Flagged phrases:', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          ..._flaggedPhrases.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• $p'),
              )),
        ],
      ],
    );
  }
}