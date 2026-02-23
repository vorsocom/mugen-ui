import 'package:mugen_ui/shared/domain/result.dart';

enum InviteRedeemOutcome { success, forbidden, notFound, conflict }

class InviteRedeemResult {
  const InviteRedeemResult({required this.outcome, required this.statusCode});

  final InviteRedeemOutcome outcome;
  final int statusCode;
}

abstract class TenantInvitationRedeemRepository {
  Future<Result<InviteRedeemResult>> redeemAuthenticated({
    required String tenantId,
    required String invitationId,
    required String token,
  });
}
