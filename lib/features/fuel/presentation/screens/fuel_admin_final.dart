// lib/features/fuel/presentation/screens/fuel_admin_final.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/entry_tabs/sale_tab.dart';
import '../widgets/entry_tabs/delivery_tab.dart';
import '../widgets/entry_tabs/expense_tab.dart';
import '../widgets/entry_tabs/settlement_tab.dart';
import '../widgets/entry_tabs/external_payments_tab.dart';
import '../widgets/tank_levels_perfect.dart';
import '../widgets/weekly_summary_perfect.dart';

class FuelAdminFinal extends StatefulWidget {
  const FuelAdminFinal({super.key});
  @override
  State<FuelAdminFinal> createState() => _FuelAdminFinalState();
}

class _FuelAdminFinalState extends State<FuelAdminFinal> with SingleTickerProviderStateMixin {
  late TabController tabController;
  final DateTime today = DateTime.now();

  double todaysSales = 0.0;
  double todaysExpense = 0.0;
  double todaysDelivery = 0.0;

  final Map<String, Map<String, bool>> weeklyStatus = {};

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 5, vsync: this);
    _initWeekly();
  }

  void _initWeekly() {
    final start = today.subtract(Duration(days: today.weekday - 1));
    for (int i = 0; i < 7; i++) {
      final d = start.add(Duration(days: i));
      final key = DateFormat('EEE dd').format(d);
      weeklyStatus[key] = {'Sale': false, 'Del': false, 'Exp': false, 'Set': false};
    }
  }

  void _mark(String type) {
    final key = DateFormat('EEE dd').format(today);
    setState(() => weeklyStatus[key]![type] = true);
  }

  void _addSale(double v) => setState(() => todaysSales += v);
  void _addExpense(double v) => setState(() => todaysExpense += v);
  void _addDelivery(double v) => setState(() => todaysDelivery += v);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // COLUMN A — SIDEBAR
          Container(
  width: 70,
  color: const Color(0xFF020617),
  child: Column(
    children: [
      const SizedBox(height: 24),

      _sideIcon(Icons.local_gas_station, true), // Fuel
      _sideIcon(Icons.store_mall_directory),   // Mall
      _sideIcon(Icons.water_drop),              // Water
      _sideIcon(Icons.analytics),               // Analytics

      const Spacer(),

      _sideIcon(Icons.settings),
      const SizedBox(height: 24),
    ],
  ),
),


          // COLUMN B — MAIN VIEW
          Expanded(
            child: Column(
              children: [
                // ROW 1 — TITLE + DATE + SEND
                Container(
                  width: double.infinity, // 🔥 span full width
                  color: const Color(0xFF0f172a),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  child: Row(
                    children: [
                      // LEFT — Title
                      const Text(
                        'SmartBusiness ERP',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(width: 20),

                      const Text(
                        'Welcome admin',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),

                      const Spacer(),

                      // RIGHT — Date
                      Text(
                        DateFormat('EEEE, MMM d, yyyy').format(today),
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.white60,
                        ),
                      ),

                      const SizedBox(width: 20),

                      // SEND BUTTON
                      ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.send, size: 18),
                        label: const Text('Send Data'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1f2937), // neutral dark
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ROW 2 — TODAY'S SUMMARY CARDS
                Container(
                  color: const Color(0xFF111827),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: _summaryCard('Today\'s Sales', todaysSales, Colors.green),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: _summaryCard('Today\'s Expense', todaysExpense, Colors.red),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: _summaryCard('Today\'s Delivery', todaysDelivery, Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ),



                // ROW 3 — 3 COLUMNS: ENTRY + WEEKLY + TANK
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 3A — ENTRY TABS
                      Expanded(
                        flex: 3,
                        child: Column(
                          children: [
                            Container(
                              height: 50,
                              color: const Color(0xFF1e293b),
                              child: TabBar(
                                controller: tabController,
                                labelColor: Colors.green,
                                tabs: const [
                                  Tab(text: 'Sale'),
                                  Tab(text: 'Delivery'),
                                  Tab(text: 'Expense'),
                                  Tab(text: 'Settlement'),
                                  Tab(text: 'External'),
                                ],
                              ),
                            ),
                            Expanded(
                              child: TabBarView(
                                controller: tabController,
                                children: [
                                  SaleTab(onSaleRecorded: (a) { _addSale(a); _mark('Sale'); }),
                                  DeliveryTab(onSubmitted: () => _mark('Del')),
                                  ExpenseTab(onSubmitted: () => _mark('Exp')),
                                  SettlementTab(onSubmitted: () => _mark('Set')),
                                  const ExternalPaymentsTab(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 16),

                      // 3B — WEEKLY SUMMARY (TINY & PERFECT)
                      Expanded(
                        flex: 1,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 260),
                          child: WeeklySummaryPerfect(weeklyStatus: weeklyStatus),
                        ),
                      ),


                      const SizedBox(width: 16),

                      // 3C — TANK LEVELS (WITH CONTROLS)
                      Expanded(
                        flex: 2,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 360),
                          child: TankLevelsPerfect(),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(String title, double value, Color color) {
  return SizedBox(
    width: 280, // prevents squeeze on Wrap
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '₦${value.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
}

Widget _sideIcon(IconData icon, [bool active = false]) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Icon(
      icon,
      size: 28,
      color: active ? Colors.green : Colors.grey[600],
    ),
  );
}
