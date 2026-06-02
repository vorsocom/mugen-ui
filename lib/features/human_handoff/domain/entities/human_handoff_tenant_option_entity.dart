class HumanHandoffTenantOptionEntity {
  const HumanHandoffTenantOptionEntity({
    required this.id,
    required this.name,
    this.slug,
  });

  final String id;
  final String name;
  final String? slug;

  String get label {
    final trimmedSlug = slug?.trim();
    if (trimmedSlug == null || trimmedSlug.isEmpty) {
      return name;
    }
    return '$name ($trimmedSlug)';
  }
}
