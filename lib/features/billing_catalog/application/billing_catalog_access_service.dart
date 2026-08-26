import 'package:mugen_ui/features/billing_catalog/domain/repositories/billing_catalog_repository.dart';
import 'package:mugen_ui/shared/domain/failure.dart';

enum BillingCatalogAccessStatus {
  available,
  extensionUnavailable,
  permissionDenied,
  error,
}

class BillingCatalogAccessState {
  const BillingCatalogAccessState({
    required this.status,
    required this.message,
  });

  const BillingCatalogAccessState.available()
    : status = BillingCatalogAccessStatus.available,
      message = '';

  final BillingCatalogAccessStatus status;
  final String message;

  bool get isAvailable => status == BillingCatalogAccessStatus.available;
}

class BillingCatalogAccessService {
  BillingCatalogAccessService({
    required this.repository,
    required this.onSessionExpired,
  });

  final BillingCatalogRepository repository;
  final void Function() onSessionExpired;

  Future<BillingCatalogAccessState> resolve() async {
    final extensionResult = await repository.fetchBillingExtensionStatus();
    if (extensionResult.isFailure) {
      _handleSessionFailure(extensionResult.failure!);
      return BillingCatalogAccessState(
        status: BillingCatalogAccessStatus.error,
        message: extensionResult.failure!.message.trim().isEmpty
            ? 'Billing extension status could not be loaded.'
            : extensionResult.failure!.message,
      );
    }

    final extension = extensionResult.data!;
    if (!extension.isRegistered) {
      return BillingCatalogAccessState(
        status: BillingCatalogAccessStatus.extensionUnavailable,
        message: _extensionUnavailableMessage(extension.status),
      );
    }

    final permissionResult = await repository.verifyCatalogReadAccess();
    if (permissionResult.isSuccess) {
      return const BillingCatalogAccessState.available();
    }

    final failure = permissionResult.failure!;
    _handleSessionFailure(failure);
    if (failure is ApiFailure && failure.statusCode == 403) {
      return const BillingCatalogAccessState(
        status: BillingCatalogAccessStatus.permissionDenied,
        message: 'You do not have permission to view the Billing Catalog.',
      );
    }
    return BillingCatalogAccessState(
      status: BillingCatalogAccessStatus.error,
      message: failure.message.trim().isEmpty
          ? 'Billing Catalog access could not be verified.'
          : failure.message,
    );
  }

  void _handleSessionFailure(Failure failure) {
    if (failure is SessionExpiredFailure || failure is UnauthorizedFailure) {
      onSessionExpired();
    }
  }

  String _extensionUnavailableMessage(String status) {
    return switch (status) {
      'disabled' => 'Billing extension is disabled.',
      'failed' => 'Billing extension bootstrap failed.',
      'unsupported' => 'Billing extension is unavailable on this platform.',
      _ => 'Billing extension is unavailable.',
    };
  }
}
