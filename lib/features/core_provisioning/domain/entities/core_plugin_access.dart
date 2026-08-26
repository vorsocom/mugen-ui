class CorePluginStatus {
  const CorePluginStatus({
    required this.token,
    required this.available,
    required this.status,
    this.reason,
  });

  final String token;
  final bool available;
  final String status;
  final String? reason;

  bool get isRegistered => available && status == 'registered';
}

enum CorePluginAccessStatus { available, unavailable, error }

class CorePluginAccess {
  const CorePluginAccess({required this.status, required this.message});

  const CorePluginAccess.available()
    : status = CorePluginAccessStatus.available,
      message = '';

  final CorePluginAccessStatus status;
  final String message;

  bool get isAvailable => status == CorePluginAccessStatus.available;
}
