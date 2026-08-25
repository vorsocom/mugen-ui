import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/app/definition/app_definition.dart';
import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/billing_catalog/application/billing_catalog_access_service.dart';
import 'package:mugen_ui/features/billing_catalog/application/billing_catalog_controller.dart';
import 'package:mugen_ui/features/billing_catalog/domain/repositories/billing_catalog_repository.dart';
import 'package:mugen_ui/features/billing_catalog/infrastructure/repositories/billing_catalog_repository_impl.dart';

final billingCatalogRepositoryProvider = Provider<BillingCatalogRepository>((
  ref,
) {
  return BillingCatalogRepositoryImpl(
    appConfig: ref.watch(appConfigProvider),
    authenticatedHttpClient: ref.watch(authenticatedHttpClientProvider),
  );
});

final billingCatalogAccessProvider = FutureProvider<BillingCatalogAccessState>((
  ref,
) async {
  final sessionKey = ref.watch(
    authControllerProvider.select(
      (state) => (state.session?.userId, state.session?.accessToken),
    ),
  );
  if (sessionKey.$1 == null || sessionKey.$2 == null) {
    return const BillingCatalogAccessState(
      status: BillingCatalogAccessStatus.permissionDenied,
      message: 'Sign in to view the Billing Catalog.',
    );
  }
  return BillingCatalogAccessService(
    repository: ref.read(billingCatalogRepositoryProvider),
    onSessionExpired: () {
      ref.read(authControllerProvider.notifier).refreshSession();
    },
  ).resolve();
});

final billingCatalogShellAvailabilityProvider =
    Provider<ShellRouteAvailability>((ref) {
      final access = ref.watch(billingCatalogAccessProvider);
      return access.when(
        loading: () => const ShellRouteAvailability.pending(),
        error: (_, _) => const ShellRouteAvailability.unavailable(
          'Billing extension status could not be loaded.',
        ),
        data: (value) => value.isAvailable
            ? const ShellRouteAvailability.available()
            : ShellRouteAvailability.unavailable(value.message),
      );
    });

final billingCatalogControllerProvider =
    StateNotifierProvider<BillingCatalogController, BillingCatalogState>((ref) {
      return BillingCatalogController(
        repository: ref.read(billingCatalogRepositoryProvider),
        onSessionExpired: () {
          ref.read(authControllerProvider.notifier).refreshSession();
        },
      );
    });
