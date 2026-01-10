// lib/core/services/service_registry.dart

import 'tank_service.dart';
import 'sale_service.dart';
import 'delivery_service.dart';
import 'debt_service.dart';
import 'settlement_service.dart';
import 'expense_service.dart';
import 'day_entry_service.dart';

import '../../features/fuel/repositories/delivery_repo.dart';
import '../../features/fuel/repositories/debt_repo.dart';
import '../../features/fuel/repositories/sale_repo.dart';
import '../../features/fuel/repositories/tank_repo.dart';
import '../../features/fuel/repositories/expense_repo.dart';
import '../../features/fuel/repositories/day_entry_repo.dart';
import '../../features/fuel/repositories/settlement_repo.dart';

class Services {
  Services._();

  // =====================
  // REPOSITORIES
  // =====================
  static final tankRepo = TankRepo();
  static final debtRepo = DebtRepo();
  static final deliveryRepo = DeliveryRepo();
  static final saleRepo = SaleRepo();
  static final expenseRepo = ExpenseRepo();
  static final dayEntryRepo = DayEntryRepo();
  static final settlementRepo = SettlementRepo();

  // =====================
  // SERVICES
  // =====================
  static final tank = TankService(tankRepo);
  static final debt = DebtService(debtRepo);

  // ✅ SALE SERVICE (THIS IS WHAT YOU WERE MISSING)
  static final sale = SaleService(
    tankService: tank,
    saleRepo: saleRepo,
  );

  // ✅ create expense BEFORE delivery (delivery depends on it)
  static final expense = ExpenseService(expenseRepo);

  static final delivery = DeliveryService(
    tankService: tank,
    debtService: debt,
    expenseService: expense,
    deliveryRepo: deliveryRepo,
  );

  static final settlement = SettlementService(
    debtService: debt,
    deliveryService: delivery,
    settlementRepo: settlementRepo,
    expenseService: expense,
  );

  static final dayEntry = DayEntryService(dayEntryRepo);

  // =====================
  // INIT (APP START)
  // =====================
  static Future<void> init() async {
    await tank.loadFromDb();
    await debt.loadFromDb();
    await delivery.loadFromDb();
    await expense.loadFromDb();

    final today = DateTime.now();
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    await dayEntry.loadWeek(weekStart);
  }
}