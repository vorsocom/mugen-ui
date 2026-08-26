import 'package:mugen_ui/features/core_provisioning/domain/entities/core_plugin_access.dart';
import 'package:mugen_ui/shared/domain/result.dart';

abstract class CorePluginRepository {
  Future<Result<CorePluginStatus>> fetchStatus(String token);
}
