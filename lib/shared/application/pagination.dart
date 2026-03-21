class PageRequest {
  const PageRequest({required this.page, required this.pageSize});

  final int page;
  final int pageSize;

  int get skip {
    if (page <= 1) {
      return 0;
    }

    return (page - 1) * pageSize;
  }
}

class PageResult<T> {
  const PageResult({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  final List<T> items;
  final int total;
  final int page;
  final int pageSize;

  int get pages {
    if (pageSize <= 0) {
      return 1;
    }

    return (total / pageSize).ceil();
  }
}
