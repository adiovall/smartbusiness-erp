// lib/core/services/external_payment_service.dart

import '../../features/fuel/repositories/external_payment_repo.dart';
import '../models/external_payment_record.dart';

class ExternalPaymentService {
  final ExternalPaymentRepo repo;
  ExternalPaymentService({required this.repo});

  Future<List<ExternalPaymentRecord>> all({bool includeDraftDeliveries = true}) {
    return repo.fetchAll(includeDraftDeliveries: includeDraftDeliveries);
  }
}

