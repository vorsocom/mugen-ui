import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/app/routing/route_ids.dart';

final pendingInviteControllerProvider =
    StateNotifierProvider<PendingInviteController, InviteRouteMatch?>((ref) {
      return PendingInviteController();
    });

class PendingInviteController extends StateNotifier<InviteRouteMatch?> {
  PendingInviteController() : super(null);

  void setPending(InviteRouteMatch match) {
    state = match;
  }

  void clear() {
    state = null;
  }

  InviteRouteMatch? consume() {
    final pending = state;
    state = null;
    return pending;
  }

  InviteRouteMatch? consumeFor({
    required String tenantId,
    required String invitationId,
  }) {
    final pending = state;
    if (pending == null ||
        pending.tenantId != tenantId ||
        pending.invitationId != invitationId) {
      return null;
    }

    state = null;
    return pending;
  }
}
