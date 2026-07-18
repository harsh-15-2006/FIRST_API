import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'app_theme.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const String _apiUrl =
      'https://first-api-77id.onrender.com/call-analyses';

  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _analyses = [];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response =
          await http.get(Uri.parse(_apiUrl)).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        setState(() {
          _analyses = jsonDecode(response.body);
        });
      } else {
        setState(() {
          _errorMessage = 'Server error (${response.statusCode}).';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not reach the server. Check your connection.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Past Checks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _isLoading ? null : _fetchHistory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _analyses.isEmpty
                  ? const Center(
                      child: Text(
                        'No calls analyzed yet.\nCheck a call to see it here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchHistory,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _analyses.length,
                        itemBuilder: (context, index) {
                          final item = _analyses[index];
                          final riskLevel = item['risk_level'] ?? 'Unknown';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    AppTheme.riskColor(riskLevel).withOpacity(0.15),
                                child: Icon(
                                  AppTheme.riskIcon(riskLevel),
                                  color: AppTheme.riskColor(riskLevel),
                                  size: 20,
                                ),
                              ),
                              title: Text('Risk: $riskLevel'),
                              subtitle: Text(
                                '${item['explanation'] ?? ''}\n${_formatDate(item['date_analyzed'] ?? '')}',
                              ),
                              isThreeLine: true,
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}