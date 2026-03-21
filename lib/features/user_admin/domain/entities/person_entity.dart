class PersonEntity {
  const PersonEntity({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.dateCreated,
    required this.dateLastModified,
    required this.deleted,
    required this.seedData,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String fullName;
  final DateTime dateCreated;
  final DateTime dateLastModified;
  final bool deleted;
  final bool seedData;
}
