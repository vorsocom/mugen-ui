class HumanHandoffReferenceOptionEntity {
  const HumanHandoffReferenceOptionEntity({
    required this.id,
    required this.title,
    this.subtitle = '',
  });

  final String id;
  final String title;
  final String subtitle;

  String get searchText => '$title $subtitle $id';
}

class HumanHandoffFilterOptionsEntity {
  const HumanHandoffFilterOptionsEntity({
    required this.owners,
    required this.serviceRoutes,
  });

  final List<HumanHandoffReferenceOptionEntity> owners;
  final List<HumanHandoffReferenceOptionEntity> serviceRoutes;
}
