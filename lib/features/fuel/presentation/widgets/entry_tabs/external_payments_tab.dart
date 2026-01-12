// lib/features/fuel/presentation/widgets/entry_tabs/external_payments_tab.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:temp_fuel_app/core/services/service_registry.dart';
import 'package:temp_fuel_app/core/models/external_payment_record.dart';

/* ===================== COLORS ===================== */
const panelBg = Color(0xFF0f172a);
const panelBorder = Color(0xFF1f2937);
const textPrimary = Color(0xFFE5E7EB);
const textSecondary = Color(0xFF9CA3AF);

class ExternalPaymentsTab extends StatefulWidget {
  const ExternalPaymentsTab({super.key});

  @override
  State<ExternalPaymentsTab> createState() => _ExternalPaymentsTabState();
}

class _ExternalPaymentsTabState extends State<ExternalPaymentsTab> {
  bool _loading = true;
  List<ExternalPaymentRecord> _payments = [];

  final money = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);

  double get totalExternal => _payments.fold(0.0, (sum, p) => sum + p.amount);

  int get supplierCount => _payments.map((e) => e.supplier).where((s) => s.trim().isNotEmpty).toSet().length;

  int get sourceCount => _payments.map((e) => e.source).where((s) => s.trim().isNotEmpty).toSet().length;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    // includeDraftDeliveries = true means you will see draft delivery externals too
    final rows = await Services.external.all(includeDraftDeliveries: true);

    if (!mounted) return;
    setState(() {
      _payments = rows;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /* ===================== HEADER ===================== */
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'External Payments',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
              Text(
                'Total: ${money.format(totalExternal)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          /* ===================== SUMMARY STRIP ===================== */
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: panelBorder),
            ),
            child: Row(
              children: [
                _summaryItem('Payments', _payments.length.toString(), Icons.receipt_long),
                _divider(),
                _summaryItem('Suppliers', supplierCount.toString(), Icons.factory),
                _divider(),
                _summaryItem('Sources', sourceCount.toString(), Icons.account_balance_wallet),
              ],
            ),
          ),

          const SizedBox(height: 20),

          /* ===================== LIST ===================== */
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _payments.isEmpty
                    ? const Center(
                        child: Text(
                          'No external payments recorded.',
                          style: TextStyle(color: textSecondary, fontSize: 14),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          itemCount: _payments.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final p = _payments[i];

                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: panelBorder),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.supplier.isEmpty ? '(No supplier)' : p.supplier,
                                          style: const TextStyle(
                                            color: textPrimary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${p.fuelType} • ${p.kind} • ${p.source}${p.isSubmitted == 0 ? " • Draft" : ""}',
                                          style: const TextStyle(
                                            color: textSecondary,
                                            fontSize: 12,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        money.format(p.amount),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        DateFormat('dd MMM yyyy').format(p.date),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  /* ===================== HELPERS ===================== */

  Widget _summaryItem(String label, String value, IconData icon) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: Colors.green, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 30,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        color: panelBorder,
      );
}
