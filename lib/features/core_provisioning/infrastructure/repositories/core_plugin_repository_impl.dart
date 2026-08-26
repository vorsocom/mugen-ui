import 'dart:convert';

import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/features/core_provisioning/domain/entities/core_plugin_access.dart';
import 'package:mugen_ui/features/core_provisioning/domain/repositories/core_plugin_repository.dart';
import 'package:mugen_ui/shared/application/api_error_message.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/infrastructure/http/acp_http_client.dart';
import 'package:mugen_ui/shared/infrastructure/http/authenticated_http_client.dart';
import 'package:mugen_ui/shared/infrastructure/http/http_transport.dart';

class CorePluginRepositoryImpl implements CorePluginRepository {
  CorePluginRepositoryImpl({
    required this.appConfig,
    required this.authenticatedHttpClient,
  });

  final AppConfig appConfig;
  final AuthenticatedHttpClient authenticatedHttpClient;

  @override
  Future<Result<CorePluginStatus>> fetchStatus(String token) async {
    try {
      final response = await authenticatedHttpClient.send(
        AcpRequest(
          method: HttpMethod.get,
          path: '${appConfig.api.endpoints.runtimeExtensions}/$token',
        ),
      );
      if (response.sessionExpired) {
        return const Result<CorePluginStatus>.failure(SessionExpiredFailure());
      }
      if (response.response.statusCode == 401) {
        return const Result<CorePluginStatus>.failure(UnauthorizedFailure());
      }
      if (!response.response.isSuccess) {
        return Result<CorePluginStatus>.failure(
          ApiFailure(
            response.response.statusCode,
            normalizeApiErrorMessage(response.response.body),
          ),
        );
      }

      final decoded = jsonDecode(response.response.body);
      if (decoded is! Map) {
        return const Result<CorePluginStatus>.failure(
          UnexpectedFailure('Unexpected runtime extension response.'),
        );
      }
      final body = Map<String, dynamic>.from(decoded);
      return Result<CorePluginStatus>.success(
        CorePluginStatus(
          token: body['token']?.toString() ?? token,
          available: _asBool(body['available']),
          status: body['status']?.toString() ?? '',
          reason: body['reason']?.toString(),
        ),
      );
    } on FormatException {
      return const Result<CorePluginStatus>.failure(
        UnexpectedFailure('Unexpected runtime extension response.'),
      );
    } catch (_) {
      return const Result<CorePluginStatus>.failure(
        NetworkFailure('Network request failed.'),
      );
    }
  }

  bool _asBool(Object? value) {
    if (value is bool) {
      return value;
    }
    final normalized = value?.toString().trim().toLowerCase();
    return normalized == 'true' || normalized == '1';
  }
}
