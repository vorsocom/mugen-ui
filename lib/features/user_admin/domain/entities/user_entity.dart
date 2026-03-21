import 'package:mugen_ui/features/user_admin/domain/entities/person_entity.dart';

class UserEntity {
  const UserEntity({
    required this.id,
    required this.userName,
    required this.email,
    required this.personRef,
    required this.dateCreated,
    required this.dateLastModified,
    required this.deleted,
    required this.isLocked,
    required this.rowVersion,
    required this.seedData,
    required this.person,
    required this.roles,
  });

  final String id;
  final String userName;
  final String email;
  final String personRef;
  final DateTime dateCreated;
  final DateTime dateLastModified;
  final bool deleted;
  final bool isLocked;
  final int rowVersion;
  final bool seedData;
  final PersonEntity person;
  final List<String> roles;
}
