import 'package:mugen_ui/features/core_provisioning/domain/entities/core_plugin_access.dart';
import 'package:mugen_ui/features/core_provisioning/domain/repositories/core_plugin_repository.dart';
import 'package:mugen_ui/shared/domain/failure.dart';

class CorePluginAccessService {
  CorePluginAccessService({
    required this.repository,
    required this.onSessionExpired,
  });

  final CorePluginRepository repository;
  final void Function() onSessionExpired;

  Future<CorePluginAccess> resolve(String token) async {
    final result = await repository.fetchStatus(token);
    if (result.isFailure) {
      final failure = result.failure!;
      if (failure is SessionExpiredFailure || failure is UnauthorizedFailure) {
        onSessionExpired();
      }
      return CorePluginAccess(
        status: CorePluginAccessStatus.error,
        message: failure.message.trim().isEmpty
            ? 'Plugin availability could not be verified.'
            : failure.message,
      );
    }

    final status = result.data!;
    if (status.isRegistered) {
      return const CorePluginAccess.available();
    }
    final reason = status.reason?.trim();
    return CorePluginAccess(
      status: CorePluginAccessStatus.unavailable,
      message: reason == null || reason.isEmpty
          ? 'Required Core plugin is unavailable (${status.status}).'
          : 'Required Core plugin is unavailable: $reason',
    );
  }
}
