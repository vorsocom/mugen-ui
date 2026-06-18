import 'dart:async';

import 'package:mugen_ui/shared/domain/value_objects/auth_session.dart';

class AuthSessionRefreshBus {
  AuthSessionRefreshBus()
    : _controller = StreamController<AuthSession>.broadcast(sync: true);

  final StreamController<AuthSession> _controller;

  Stream<AuthSession> get stream => _controller.stream;

  void publish(AuthSession session) {
    if (_controller.isClosed) {
      return;
    }

    _controller.add(session);
  }

  void close() {
    _controller.close();
  }
}
