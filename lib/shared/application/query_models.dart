import 'package:mugen_ui/shared/application/pagination.dart';

class UserListQuery {
  const UserListQuery({
    required this.pageRequest,
    this.searchTerm,
    this.excludeUserName,
  });

  final PageRequest pageRequest;
  final String? searchTerm;
  final String? excludeUserName;
}
