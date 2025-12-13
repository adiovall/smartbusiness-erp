import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/* ===================== COLORS ===================== */

const panelBg = Color(0xFF0f172a);
const panelBorder = Color(0xFF1f2937);
const textPrimary = Color(0xFFE5E7EB);
const textSecondary = Color(0xFF9CA3AF);

class ExternalPaymentsTab extends StatelessWidget {
  const ExternalPaymentsTab({super.key});

  // 🔹 MOCK DATA (replace later with real source)
  List<Map<String, dynamic>> get payments => [
        {
          'source': 'Bank Transfer',
          'supplier': 'Onyis Fuel',
          'fuel': 'Diesel (AGO)',
          'amount': 250000.0,
          'date': DateTime.now().subtract(const Duration(days: 1)),
        },
        {
          'source': 'Cash',
          'supplier': 'Val Oil',
          'fuel': 'Gas (LPG)',
          'amount': 120000.0,
          'date': DateTime.now().subtract(const Duration(days: 2)),
        },
        {
          'source': 'POS',
          'supplier': 'NNPC Depot',
          'fuel': 'Petrol (PMS)',
          'amount': 500000.0,
          'date': DateTime.now().subtract(const Duration(days: 3)),
        },
      ];

  double get totalExternal =>
      payments.fold(0, (sum, p) => sum + p['amount']);

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
                'Total: ₦${NumberFormat('#,###').format(totalExternal)}',
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
                _summaryItem(
                  'Payments',
                  payments.length.toString(),
                  Icons.receipt_long,
                ),
                _divider(),
                _summaryItem(
                  'Suppliers',
                  payments
                      .map((e) => e['supplier'])
                      .toSet()
                      .length
                      .toString(),
                  Icons.factory,
                ),
                _divider(),
                _summaryItem(
                  'Sources',
                  payments
                      .map((e) => e['source'])
                      .toSet()
                      .length
                      .toString(),
                  Icons.account_balance_wallet,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          /* ===================== PAYMENTS LIST ===================== */
          Expanded(
            child: payments.isEmpty
                ? Center(
                    child: Text(
                      'No external payments recorded.',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: payments.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final p = payments[i];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: panelBorder),
                        ),
                        child: Row(
                          children: [
                            /* LEFT */
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p['supplier'],
                                    style: const TextStyle(
                                      color: textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${p['fuel']} • ${p['source']}',
                                    style: const TextStyle(
                                      color: textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            /* RIGHT */
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₦${NumberFormat('#,###').format(p['amount'])}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('dd MMM yyyy')
                                      .format(p['date']),
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
