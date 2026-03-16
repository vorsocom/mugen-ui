import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/infrastructure/acp_admin/acp_query_builder.dart';

void main() {
  test(
    'buildListQuery includes paging, ordering, filters, and escaped search',
    () {
      final query = AcpQueryBuilder.buildListQuery(
        pageRequest: const PageRequest(page: 2, pageSize: 5),
        orderBy: 'Name asc',
        searchTerm: "o'neal",
        searchFields: const <String>['Name', 'Description'],
        extraFilters: const <String>['IsActive eq true', '   '],
      );

      expect(query[r'$count'], isTrue);
      expect(query[r'$orderby'], 'Name asc');
      expect(query[r'$skip'], 5);
      expect(query[r'$top'], 5);
      expect(
        query[r'$filter'],
        "IsActive eq true and (contains(Name,'o''neal') or contains(Description,'o''neal'))",
      );
    },
  );

  test('buildListQuery omits paging and ignores short search terms', () {
    final query = AcpQueryBuilder.buildListQuery(
      pageRequest: const PageRequest(page: 1, pageSize: 0),
      searchTerm: 'a',
      searchFields: const <String>['Name'],
    );

    expect(query, <String, dynamic>{r'$count': true});
  });
}
