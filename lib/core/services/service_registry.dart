// lib/core/services/service_registry.dart

import 'tank_service.dart';
import 'sale_service.dart';
import 'delivery_service.dart';
import 'debt_service.dart';
import 'settlement_service.dart';
import 'expense_service.dart';

import '../../features/fuel/repositories/delivery_repo.dart';
import '../../features/fuel/repositories/debt_repo.dart';
import '../../features/fuel/repositories/sale_repo.dart';
import '../../features/fuel/repositories/tank_repo.dart';
import '../../features/fuel/repositories/expense_repo.dart';


class Services {
  Services._();

  static final deliveryRepo = DeliveryRepo();
  static final debtRepo = DebtRepo();
  static final saleRepo = SaleRepo();
  static final tankRepo = TankRepo();
  static final expenseRepo = ExpenseRepo();

  static final tank = TankService(tankRepo);
  static final debt = DebtService(debtRepo);

  static final delivery = DeliveryService(
    tankService: tank,
    debtService: debt,
    deliveryRepo: deliveryRepo,
  );

  static final sale = SaleService(
    tankService: tank,
    saleRepo: saleRepo,
  );

  static final settlement = SettlementService(
    debtService: debt,
    deliveryService: delivery,
  );

  static final expense = ExpenseService(expenseRepo);

  /// 🔑 Call once on app start
  static Future<void> init() async {
    await tank.loadFromDb();
    await debt.loadFromDb();
    await expense.loadFromDb(); // ✅ ADD THIS
  }
}
