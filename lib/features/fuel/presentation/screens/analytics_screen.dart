// lib/features/fuel/presentation/screens/analytics_screen.dart

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/services/service_registry.dart';
import '../widgets/analytics/shared.dart';
import '../widgets/analytics/trends_view.dart';
import '../widgets/analytics/insight_view.dart';
import '../widgets/analytics/reconciliation_view.dart';

class AnalyticsScreen extends StatefulWidget {
  final VoidCallback onBack;

  const AnalyticsScreen({super.key, required this.onBack});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _viewIndex = 0;

  // Bumped whenever a CSV import completes, forcing each view widget
  // to rebuild fresh (via Key) and reload its own data from scratch.
  int _refreshKey = 0;

  Future<void> _importCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);
    final content = await file.readAsString();

    final importResult = await Services.csvImport.importCsv(content);

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF020617),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.white, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Import Complete',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text('Rows processed: ${importResult.rowsProcessed}',
                  style: const TextStyle(color: Colors.white70)),
              Text('Imported: ${importResult.rowsImported}',
                  style: const TextStyle(color: Colors.greenAccent)),
              Text('Skipped: ${importResult.rowsSkipped}',
                  style: const TextStyle(color: Colors.amber)),
              if (importResult.warnings.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Details:', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: importResult.warnings
                          .map((w) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text('• $w',
                                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
                              ))
                          .toList(),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Force every view widget to rebuild fresh and reload its own
    // data, now that new historical records exist.
    setState(() => _refreshKey++);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0b1220),
      body: Column(
        children: [
          _buildTopBar(),
          _buildToggle(),
          Expanded(
            child: IndexedStack(
              index: _viewIndex,
              children: [
                AnalyticsTrendsView(key: ValueKey('trends_$_refreshKey')),
                AnalyticsInsightView(key: ValueKey('insight_$_refreshKey')),
                AnalyticsReconciliationView(key: ValueKey('reconciliation_$_refreshKey')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      color: panelBg2,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        children: [
          IconButton(
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const SizedBox(width: 8),
          const Text(
            'Analytics',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: _importCsv,
            icon: const Icon(Icons.upload_file, size: 18),
            label: const Text('Import Historical Data'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange,
              side: const BorderSide(color: Colors.orange),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: _exportCsv,
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Download CSV'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.cyan,
              side: const BorderSide(color: Colors.cyan),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle() {
    return Container(
      color: const Color(0xFF1e293b),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        children: [
          _toggleButton('Trends', _viewIndex == 0, () => setState(() => _viewIndex = 0)),
          const SizedBox(width: 12),
          _toggleButton('Insight', _viewIndex == 1, () => setState(() => _viewIndex = 1)),
          const SizedBox(width: 12),
          _toggleButton('Reconciliation', _viewIndex == 2, () => setState(() => _viewIndex = 2)),
        ],
      ),
    );
  }

  Widget _toggleButton(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.orange.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? Colors.orange : panelBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.orange : textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _exportCsv() async {
    final csv = await Services.csvExport.exportAllAsCsv();

    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Historical Data',
      fileName: 'fuelflow-historical-${DateTime.now().toIso8601String().split("T").first}.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (path == null) return;

    await File(path).writeAsString(csv);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Historical data exported'), backgroundColor: Colors.green),
    );
  }
}