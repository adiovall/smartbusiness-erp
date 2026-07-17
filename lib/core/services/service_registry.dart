// lib/core/services/service_registry.dart

import 'tank_service.dart';
import 'sale_service.dart';
import 'delivery_service.dart';
import 'tank_dip_service.dart';
import 'debt_service.dart';
import 'settlement_service.dart';
import 'expense_service.dart';
import 'day_entry_service.dart';
import 'outbox_service.dart';
import 'analytics_service.dart';
import 'reconciliation_service.dart';
import 'csv_import_service.dart';
import 'auth_service.dart';
import 'pump_config_service.dart';
import 'sync_service.dart';


import '../../features/fuel/repositories/delivery_repo.dart';
import '../../features/fuel/repositories/debt_repo.dart';
import '../../features/fuel/repositories/sale_repo.dart';
import '../../features/fuel/repositories/tank_dip_repo.dart';
import '../../features/fuel/repositories/tank_repo.dart';
import '../../features/fuel/repositories/expense_repo.dart';
import '../../features/fuel/repositories/day_entry_repo.dart';
import '../../features/fuel/repositories/settlement_repo.dart';
import '../../features/fuel/repositories/external_payment_repo.dart';
import '../services/external_payment_service.dart';
import '../../features/fuel/repositories/outbox_repo.dart';
import '../../features/auth/repositories/user_repo.dart';
import '../../features/fuel/repositories/pump_config_repo.dart';



class Services {
  Services._();

  // =====================
  // REPOSITORIES
  // =====================
  static final tankRepo = TankRepo();
  static final debtRepo = DebtRepo();
  static final deliveryRepo = DeliveryRepo();
  static final saleRepo = SaleRepo();
  static final pumpConfigRepo = PumpConfigRepo();
  static final expenseRepo = ExpenseRepo();
  static final dayEntryRepo = DayEntryRepo();
  static final settlementRepo = SettlementRepo();
  static final outboxRepo = OutboxRepo();
  static final userRepo = UserRepo();

 

  // =====================
  // SERVICES
  // =====================
  static final auth = AuthService(repo: userRepo);
  static final sync = SyncService(outboxRepo: outboxRepo);
  static final tank = TankService(tankRepo);
  static final debt = DebtService(debtRepo);
  
  static final sale = SaleService(
    tankService: tank,
    saleRepo: saleRepo,
  );
  static final pumpConfig = PumpConfigService(repo: pumpConfigRepo);

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

  // ✅ dayEntry now needs all 5 services for correctBusinessDate()
  static final dayEntry = DayEntryService(
    repo: dayEntryRepo,
    saleService: sale,
    deliveryService: delivery,
    debtService: debt,
    expenseService: expense,
    settlementService: settlement,
  );

  static void _wireCallbacks() {
    expense.onLockedExpenseCreated = (businessDate) {
      dayEntry.markSubmitted(businessDate, 'Exp');
    };
  }

  
  static final analytics = AnalyticsService();
  static final reconciliation = ReconciliationService();
  static final csvImport = CsvImportService(outboxRepo: outboxRepo, tankService: tank);
  static final tankDip = TankDipService(repo: TankDipRepo());
  static final outbox = OutboxService(
    repo: outboxRepo,
    saleService: sale,
    deliveryService: delivery,
    debtService: debt,
    expenseService: expense,
    settlementService: settlement,
    tankService: tank,
    tankDipService: tankDip,
    externalPaymentRepo: ExternalPaymentRepo(),
  );

  static late ExternalPaymentService external;
  

  // =====================
  // INIT (APP START)
  // =====================
  static Future<void> init() async {
    _wireCallbacks();
    
    await tank.loadFromDb();
    await debt.loadFromDb();
    await delivery.loadFromDb();
    await expense.loadFromDb();
    await pumpConfig.loadFromDb();

    final today = DateTime.now();
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    await dayEntry.loadWeek(weekStart);
    final externalRepo = ExternalPaymentRepo();
    external = ExternalPaymentService(repo: externalRepo);
  }
}