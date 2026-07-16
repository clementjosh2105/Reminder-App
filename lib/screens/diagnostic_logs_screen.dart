import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/notification_service.dart';

class DiagnosticLogsScreen extends StatefulWidget {
  const DiagnosticLogsScreen({super.key});

  @override
  State<DiagnosticLogsScreen> createState() => _DiagnosticLogsScreenState();
}

class _DiagnosticLogsScreenState extends State<DiagnosticLogsScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  bool _autoScroll = true;
  String _filterText = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    NotificationService.diagnosticLogs.addListener(_onLogsChanged);
  }

  @override
  void dispose() {
    NotificationService.diagnosticLogs.removeListener(_onLogsChanged);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onLogsChanged() {
    if (_autoScroll && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Color _colorForLog(String logItem) {
    final lower = logItem.toLowerCase();
    if (lower.contains('failed') ||
        lower.contains('error') ||
        lower.contains('crash') ||
        lower.contains('failure')) {
      return Colors.redAccent;
    }
    if (lower.contains('missing') || lower.contains('skipped')) {
      return Colors.orangeAccent;
    }
    if (lower.contains('success') || lower.contains('initialized')) {
      return Colors.cyanAccent;
    }
    if (logItem.contains('[Schedule]')) {
      return Colors.pinkAccent.shade100;
    }
    return Colors.lightGreenAccent;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F11),
      appBar: AppBar(
        title: const Text('Diagnostic Console'),
        backgroundColor: const Color(0xFF16161A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _autoScroll
                  ? Icons.gps_fixed_rounded
                  : Icons.gps_not_fixed_rounded,
            ),
            tooltip: 'Toggle auto-scroll',
            onPressed: () {
              setState(() => _autoScroll = !_autoScroll);
              if (_autoScroll) _scrollToBottom();
            },
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Copy all logs',
            onPressed: () {
              final logs = NotificationService.diagnosticLogs.value.join('\n');
              Clipboard.setData(ClipboardData(text: logs));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Logs copied to clipboard'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: 'Clear logs',
            onPressed: () {
              NotificationService.diagnosticLogs.value = [];
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Logs cleared'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Filter logs...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _filterText.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _filterText = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF16161A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 16,
                ),
              ),
              onChanged: (val) {
                setState(() => _filterText = val.trim().toLowerCase());
              },
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<List<String>>(
              valueListenable: NotificationService.diagnosticLogs,
              builder: (context, allLogs, _) {
                final filteredLogs = _filterText.isEmpty
                    ? allLogs
                    : allLogs
                          .where(
                            (log) => log.toLowerCase().contains(_filterText),
                          )
                          .toList();

                if (filteredLogs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No matching logs found.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return Container(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white10),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: filteredLogs.length,
                    itemBuilder: (context, index) {
                      final logItem = filteredLogs[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: SelectableText(
                          logItem,
                          style: TextStyle(
                            color: _colorForLog(logItem),
                            fontFamily: 'monospace',
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
