abstract class Failure {
  const Failure(this.message);

  final String message;
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

class ApiFailure extends Failure {
  const ApiFailure(this.statusCode, super.message);

  final int statusCode;
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([super.message = 'Unauthorized request.']);
}

class SessionExpiredFailure extends Failure {
  const SessionExpiredFailure([super.message = 'Session expired.']);
}

class UnexpectedFailure extends Failure {
  const UnexpectedFailure(super.message);
}
