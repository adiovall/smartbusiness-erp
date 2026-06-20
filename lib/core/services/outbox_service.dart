// lib/core/services/outbox_service.dart

import 'dart:convert';
import '../models/outbox_record.dart';
import '../../features/fuel/repositories/outbox_repo.dart';
import 'sale_service.dart';
import 'delivery_service.dart';
import 'debt_service.dart';
import 'expense_service.dart';
import 'settlement_service.dart';
import 'tank_service.dart';

class OutboxService {
  final OutboxRepo repo;
  final SaleService saleService;
  final DeliveryService deliveryService;
  final DebtService debtService;
  final ExpenseService expenseService;
  final SettlementService settlementService;
  final TankService tankService;

  OutboxService({
    required this.repo,
    required this.saleService,
    required this.deliveryService,
    required this.debtService,
    required this.expenseService,
    required this.settlementService,
    required this.tankService,
  });

  Future<OutboxRecord> buildAndArchive(String businessDate) async {
    final sales = await saleService.allForBusinessDate(businessDate);
    final deliveries = await deliveryService.allForBusinessDate(businessDate);
    final debts = debtService.allForBusinessDate(businessDate); // sync, in-memory
    final settlements = await settlementService.allForBusinessDate(businessDate);
    final expenses = await expenseService.allForBusinessDate(businessDate);
    final tankSnapshot = tankService.snapshotAll(); // sync, in-memory

    final payload = {
      'businessDate': businessDate,
      'generatedAt': DateTime.now().toIso8601String(),
      'sales': sales.map((s) => s.toJson()).toList(),
      'deliveries': deliveries.map((d) => d.toJson()).toList(),
      'debts': debts.map((d) => d.toJson()).toList(),
      'settlements': settlements.map((s) => s.toJson()).toList(),
      'expenses': expenses.map((e) => e.toJson()).toList(),
      'tankSnapshot': tankSnapshot,
    };

    final record = OutboxRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      businessDate: businessDate,
      payloadJson: jsonEncode(payload),
      createdAt: DateTime.now(),
      synced: false,
    );

    await repo.insert(record);

    await saleService.archiveForBusinessDate(businessDate);
    await deliveryService.archiveForBusinessDate(businessDate);
    await expenseService.archiveForBusinessDate(businessDate);

    return record;
  }
}