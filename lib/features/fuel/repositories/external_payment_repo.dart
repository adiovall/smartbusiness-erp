import '../../../core/db/app_database.dart';
import '../../../core/models/external_payment_record.dart';

class ExternalPaymentRepo {
  Future<List<ExternalPaymentRecord>> fetchAll({bool includeDraftDeliveries = true}) async {
    final db = await AppDatabase.instance;

    final draftWhere = includeDraftDeliveries ? '' : 'AND d.isSubmitted = 1';

    final rows = await db.rawQuery('''
      SELECT 
        d.id as id,
        d.date as date,
        d.supplier as supplier,
        d.fuelType as fuelType,
        d.externalPaid as amount,
        'Delivery' as kind,
        COALESCE(d.source, '') as source,
        d.isSubmitted as isSubmitted
      FROM deliveries d
      WHERE d.externalPaid > 0
      $draftWhere

      UNION ALL

      SELECT
        s.id as id,
        s.date as date,
        s.supplier as supplier,
        s.fuelType as fuelType,
        s.externalPaid as amount,
        'Settlement' as kind,
        COALESCE(s.source, '') as source,
        1 as isSubmitted
      FROM settlements s
      WHERE s.externalPaid > 0

      ORDER BY date DESC
    ''');

    return rows.map((r) {
      return ExternalPaymentRecord(
        id: r['id'] as String,
        date: DateTime.parse(r['date'] as String),
        supplier: (r['supplier'] as String?) ?? '',
        fuelType: (r['fuelType'] as String?) ?? '',
        amount: (r['amount'] as num).toDouble(),
        kind: (r['kind'] as String?) ?? '',
        source: (r['source'] as String?) ?? '',
        isSubmitted: (r['isSubmitted'] as int?) ?? 1,
      );
    }).toList();
  }
}
