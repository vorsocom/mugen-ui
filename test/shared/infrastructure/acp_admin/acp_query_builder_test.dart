import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';
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

  test('buildListQuery applies explicit soft-delete lifecycle views', () {
    expect(
      AcpQueryBuilder.buildListQuery(
        pageRequest: const PageRequest(page: 1, pageSize: 15),
        deletedView: AcpDeletedView.active,
      ).containsKey(r'$deleted'),
      isFalse,
    );
    expect(
      AcpQueryBuilder.buildListQuery(
        pageRequest: const PageRequest(page: 1, pageSize: 15),
        deletedView: AcpDeletedView.all,
      )[r'$deleted'],
      'all',
    );
    expect(
      AcpQueryBuilder.buildListQuery(
        pageRequest: const PageRequest(page: 1, pageSize: 15),
        deletedView: AcpDeletedView.archived,
      )[r'$deleted'],
      'archived',
    );
  });

  test('serializes single and nested expansion expressions', () {
    final query = AcpQueryBuilder.buildListQuery(
      pageRequest: const PageRequest(page: 1, pageSize: 15),
      expansions: const <AcpExpandDescriptor>[
        AcpExpandDescriptor(
          navigation: 'Account',
          selectFields: <String>['DisplayName', 'Code'],
        ),
        AcpExpandDescriptor(
          navigation: 'Subscription',
          selectFields: <String>['Status'],
          expands: <AcpExpandDescriptor>[
            AcpExpandDescriptor(
              navigation: 'Price',
              expands: <AcpExpandDescriptor>[
                AcpExpandDescriptor(
                  navigation: 'Product',
                  selectFields: <String>['Name'],
                ),
              ],
            ),
          ],
        ),
      ],
    );

    expect(
      query[r'$expand'],
      r'Account($select=DisplayName,Code),Subscription($select=Status;$expand=Price($expand=Product($select=Name)))',
    );
  });

  test('buildReferenceBatchQuery selects and filters unique IDs', () {
    final query = AcpQueryBuilder.buildReferenceBatchQuery(
      ids: const <String>['one', 'one', "o'neal", ' '],
      selectFields: const <String>['Name', 'Name', ' '],
      deletedView: AcpDeletedView.all,
      expansions: const <AcpExpandDescriptor>[
        AcpExpandDescriptor(navigation: 'Parent'),
      ],
    );

    expect(query[r'$top'], 2);
    expect(query[r'$select'], 'Id,Name');
    expect(query[r'$filter'], "Id in ('one','o''neal')");
    expect(query[r'$deleted'], 'all');
    expect(query[r'$expand'], 'Parent');
  });

  test('reference queries handle empty inputs and archived views', () {
    expect(
      AcpQueryBuilder.buildReferenceBatchQuery(
        ids: const <String>[],
        selectFields: const <String>[],
      ),
      isEmpty,
    );
    expect(
      AcpQueryBuilder.buildReferenceBatchQuery(
        ids: const <String>[' ', ''],
        selectFields: const <String>[],
      ),
      isEmpty,
    );
    expect(
      AcpQueryBuilder.buildReferenceBatchQuery(
        ids: const <String>['id'],
        selectFields: const <String>[],
        deletedView: AcpDeletedView.archived,
      )[r'$deleted'],
      'archived',
    );
    expect(
      AcpQueryBuilder.buildEntityReferenceQuery(
        expansions: const <AcpExpandDescriptor>[],
      ),
      isEmpty,
    );
    expect(
      AcpQueryBuilder.buildEntityReferenceQuery(
        expansions: const <AcpExpandDescriptor>[
          AcpExpandDescriptor(navigation: 'Account'),
        ],
      ),
      <String, dynamic>{r'$select': 'Id', r'$expand': 'Account'},
    );
  });

  test('expansion serialization omits blank metadata', () {
    expect(
      AcpQueryBuilder.serializeExpansions(const <AcpExpandDescriptor>[
        AcpExpandDescriptor(navigation: ' '),
        AcpExpandDescriptor(
          navigation: 'Account',
          selectFields: <String>[' ', 'Code', 'Code'],
          expands: <AcpExpandDescriptor>[AcpExpandDescriptor(navigation: ' ')],
        ),
      ]),
      r'Account($select=Code)',
    );
  });
}
