import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/fuel/repositories/outbox_repo.dart';
import 'auth_service.dart';

class CloudSessionRequiredException implements Exception {
  final String message;
  CloudSessionRequiredException([this.message = 'Sign in to the cloud to send data.']);
  @override
  String toString() => message;
}

class SyncResult {
  final int recordsSynced;
  final int recordsFailed;
  final String? lastError;

  SyncResult({required this.recordsSynced, required this.recordsFailed, this.lastError});

  bool get hasFailures => recordsFailed > 0;
}

class SyncService with ChangeNotifier {
  final OutboxRepo outboxRepo;
  final AuthService authService;
  final SupabaseClient _client = Supabase.instance.client;

  SyncService({required this.outboxRepo, required this.authService});

  bool _syncing = false;
  bool get isSyncing => _syncing;

  bool get hasSupabaseSession => _client.auth.currentSession != null;

  Future<SyncResult> syncAll() async {
    if (!hasSupabaseSession) {
      throw CloudSessionRequiredException();
    }

    final stationId = await authService.resolveStationId();
    if (stationId == null) {
      throw CloudSessionRequiredException(
        'Could not determine this account\'s station. Try signing in to the cloud again.',
      );
    }

    _syncing = true;
    notifyListeners();

    final unsynced = await outboxRepo.fetchUnsynced();
    int succeeded = 0;
    int failed = 0;
    String? lastError;

    for (final record in unsynced) {
      try {
        await _pushRecord(record, stationId);
        await outboxRepo.markSynced(record.id);
        succeeded++;
      } catch (e) {
        failed++;
        lastError = e.toString();
      }
    }

    _syncing = false;
    notifyListeners();

    return SyncResult(recordsSynced: succeeded, recordsFailed: failed, lastError: lastError);
  }

  Future<void> _pushRecord(dynamic record, String stationId) async {
    final payload = jsonDecode(record.payloadJson) as Map<String, dynamic>;
    final businessDate = payload['businessDate'] as String;

    final sales = (payload['sales'] as List? ?? []);
    if (sales.isNotEmpty) {
      await _client.from('sales').upsert(sales.map((s) => {
            'id': s['id'],
            'station_id': stationId,
            'business_date': businessDate,
            'pump_no': s['pumpNo'],
            'fuel_type': s['fuelType'],
            'opening': s['opening'],
            'closing': s['closing'],
            'liters': s['liters'],
            'unit_price': s['unitPrice'],
            'total_amount': s['totalAmount'],
          }).toList());
    }

    final deliveries = (payload['deliveries'] as List? ?? []);
    if (deliveries.isNotEmpty) {
      await _client.from('deliveries').upsert(deliveries.map((d) => {
            'id': d['id'],
            'station_id': stationId,
            'business_date': businessDate,
            'supplier': d['supplier'],
            'fuel_type': d['fuelType'],
            'liters': d['liters'],
            'total_cost': d['totalCost'],
            'amount_paid': d['amountPaid'],
            'sales_paid': d['salesPaid'],
            'external_paid': d['externalPaid'],
            'credit_used': d['creditUsed'],
            'debt': d['debt'],
            'credit': d['credit'],
            'source': d['source'],
          }).toList());
    }

    final tankDips = (payload['tankDipReadings'] as List? ?? []);
    if (tankDips.isNotEmpty) {
      await _client.from('tank_dips').upsert(tankDips.map((t) => {
            'id': t['id'],
            'station_id': stationId,
            'business_date': businessDate,
            'fuel_type': t['fuelType'],
            'opening_level': t['openingLevel'],
            'closing_level': t['closingLevel'],
            'notes': t['notes'],
          }).toList());
    }

    final expenses = (payload['expenses'] as List? ?? []);
    if (expenses.isNotEmpty) {
      await _client.from('expenses').upsert(expenses.map((e) => {
            'id': e['id'],
            'station_id': stationId,
            'business_date': businessDate,
            'amount': e['amount'],
            'category': e['category'],
            'comment': e['comment'],
            'source': e['source'],
            'ref_id': e['refId'],
          }).toList());
    }

    final settlements = (payload['settlements'] as List? ?? []);
    if (settlements.isNotEmpty) {
      await _client.from('settlements').upsert(settlements.map((s) => {
            'id': s['id'],
            'station_id': stationId,
            'business_date': businessDate,
            'supplier': s['supplier'],
            'fuel_type': s['fuelType'],
            'paid_amount': s['paidAmount'],
            'sales_paid': s['salesPaid'],
            'external_paid': s['externalPaid'],
            'remaining_debt': s['remainingDebt'],
            'credit': s['credit'],
            'source': s['source'],
          }).toList());
    }

    final debts = (payload['debts'] as List? ?? []);
    if (debts.isNotEmpty) {
      await _client.from('debts').upsert(debts.map((d) => {
            'id': d['id'],
            'station_id': stationId,
            'business_date': businessDate,
            'supplier': d['supplier'],
            'fuel_type': d['fuelType'],
            'amount': d['amount'],
            'settled': (d['settled'] as int? ?? 0) == 1,
          }).toList());
    }

    final externalPayments = (payload['externalPayments'] as List? ?? []);
    if (externalPayments.isNotEmpty) {
      await _client.from('external_payments').upsert(externalPayments.map((e) => {
            'id': e['id'],
            'station_id': stationId,
            'business_date': businessDate,
            'supplier': e['supplier'],
            'fuel_type': e['fuelType'],
            'kind': e['kind'],
            'amount': e['amount'],
          }).toList());
    }

    final tankSnapshot = (payload['tankSnapshot'] as List? ?? []);
    if (tankSnapshot.isNotEmpty) {
      await _client.from('tank_snapshots').upsert(tankSnapshot.map((t) => {
            'id': '${businessDate}_${t['fuelType']}',
            'station_id': stationId,
            'business_date': businessDate,
            'fuel_type': t['fuelType'],
            'capacity': t['capacity'],
            'current_level': t['currentLevel'],
            'percentage': t['percentage'],
          }).toList());
    }
  }
}