import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/features/tenant_invite/domain/repositories/tenant_invitation_redeem_repository.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/infrastructure/auth/cookie_store.dart';
import 'package:mugen_ui/shared/infrastructure/http/acp_http_client.dart';
import 'package:mugen_ui/shared/infrastructure/http/authenticated_http_client.dart';
import 'package:mugen_ui/shared/infrastructure/http/http_transport.dart';

class TenantInvitationRedeemRepositoryImpl
    implements TenantInvitationRedeemRepository {
  TenantInvitationRedeemRepositoryImpl({
    required this.appConfig,
    required this.cookieStore,
    required this.authenticatedHttpClient,
  });

  final AppConfig appConfig;
  final CookieStore cookieStore;
  final AuthenticatedHttpClient authenticatedHttpClient;

  @override
  Future<Result<InviteRedeemResult>> redeemAuthenticated({
    required String tenantId,
    required String invitationId,
    required String token,
  }) async {
    final normalizedToken = token.trim();
    if (normalizedToken.isEmpty) {
      return const Result<InviteRedeemResult>.failure(
        ValidationFailure('Invite token is required.'),
      );
    }

    final path = appConfig.api.endpoints.authTenantInvitationRedeem
        .replaceAll('{tenant_id}', tenantId)
        .replaceAll('{invitation_id}', invitationId);

    try {
      final response = await authenticatedHttpClient.send(
        AcpRequest(
          method: HttpMethod.post,
          path: path,
          body: <String, dynamic>{'Token': normalizedToken},
        ),
      );

      if (response.sessionExpired) {
        cookieStore.removeCookie('auth', '/');
        return const Result<InviteRedeemResult>.failure(
          SessionExpiredFailure(),
        );
      }

      final statusCode = response.response.statusCode;
      switch (statusCode) {
        case 204:
          return const Result<InviteRedeemResult>.success(
            InviteRedeemResult(
              outcome: InviteRedeemOutcome.success,
              statusCode: 204,
            ),
          );
        case 403:
          return const Result<InviteRedeemResult>.success(
            InviteRedeemResult(
              outcome: InviteRedeemOutcome.forbidden,
              statusCode: 403,
            ),
          );
        case 404:
          return const Result<InviteRedeemResult>.success(
            InviteRedeemResult(
              outcome: InviteRedeemOutcome.notFound,
              statusCode: 404,
            ),
          );
        case 409:
          return const Result<InviteRedeemResult>.success(
            InviteRedeemResult(
              outcome: InviteRedeemOutcome.conflict,
              statusCode: 409,
            ),
          );
        default:
          return Result<InviteRedeemResult>.failure(
            ApiFailure(statusCode, 'API error.'),
          );
      }
    } catch (_) {
      return const Result<InviteRedeemResult>.failure(
        NetworkFailure('Network error.'),
      );
    }
  }
}
