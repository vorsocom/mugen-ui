import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/features/audit_admin/application/dto/audit_admin_inputs.dart';
import 'package:mugen_ui/features/audit_admin/infrastructure/repositories/audit_admin_repository_impl.dart';
import 'package:mugen_ui/features/billing_catalog/application/dto/billing_catalog_inputs.dart';
import 'package:mugen_ui/features/billing_catalog/domain/entities/billing_catalog_entities.dart';
import 'package:mugen_ui/features/billing_catalog/infrastructure/repositories/billing_catalog_repository_impl.dart';
import 'package:mugen_ui/features/tenant_admin/application/dto/tenant_admin_inputs.dart';
import 'package:mugen_ui/features/tenant_admin/infrastructure/repositories/tenant_admin_repository_impl.dart';
import 'package:mugen_ui/features/user_admin/infrastructure/repositories/user_admin_repository_impl.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';
import 'package:mugen_ui/shared/application/admin_search_limits.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/application/query_models.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/infrastructure/acp_admin/acp_admin_repository_impl.dart';
import 'package:mugen_ui/shared/infrastructure/acp_admin/acp_search_validation.dart';
import 'package:mugen_ui/shared/infrastructure/auth/cookie_store.dart';
import 'package:mugen_ui/shared/infrastructure/http/acp_http_client.dart';
import 'package:mugen_ui/shared/infrastructure/http/authenticated_http_client.dart';
import 'package:mugen_ui/shared/infrastructure/http/http_transport.dart';

void main() {
  test(
    'search limit counts user-perceived characters including composed text',
    () {
      expect(AdminSearchLimits.validate(null), isNull);
      expect(AdminSearchLimits.validate(''), isNull);
      for (final unit in ['a', 'é', 'e\u0301', '👨‍👩‍👧‍👦', "'"]) {
        expect(AdminSearchLimits.validate(unit * 200), isNull);
        expect(
          AdminSearchLimits.validate(unit * 201)?.message,
          AdminSearchLimits.lengthMessage,
        );
      }
    },
  );

  test(
    'encoded query budget includes UTF-8 encoding and boundary overhead',
    () {
      expect(
        validateAcpSearchQuery(
          searchTerm: null,
          queryParameters: {'q': 'a' * 40000},
        ),
        isNull,
      );
      expect(
        validateAcpSearchQuery(
          searchTerm: ' ',
          queryParameters: {'q': 'a' * 40000},
        ),
        isNull,
      );
      expect(
        validateAcpSearchQuery(
          searchTerm: 'aa',
          queryParameters: {'q': 'a' * 29998},
        ),
        isNull,
      );
      expect(
        validateAcpSearchQuery(
          searchTerm: 'aa',
          queryParameters: {'q': 'a' * 29999},
        ),
        isA<ValidationFailure>(),
      );
      expect(
        validateAcpSearchQuery(
          searchTerm: 'éé',
          queryParameters: {'q': 'é' * 5000},
        ),
        isA<ValidationFailure>(),
      );
    },
  );

  for (final name in ['generic', 'users', 'tenants', 'audit', 'billing']) {
    test('$name rejects overlong searches before sending a request', () async {
      final fixture = _Fixture();
      final result = await fixture.search(name, 'a' * 201);
      expect(result.failure, isA<ValidationFailure>());
      expect(result.failure!.message, AdminSearchLimits.lengthMessage);
      expect(fixture.client.requests, isEmpty);
    });

    test(
      '$name accepts boundary searches and preserves escaped text',
      () async {
        final fixture = _Fixture();
        for (final unit in ['a', 'é', '😀', "'"]) {
          final term = unit * 200;
          final result = await fixture.search(name, term);
          expect(result.isSuccess, isTrue, reason: '$name: $unit');
          final filter =
              fixture.client.requests.last.queryParameters[r'$filter'];
          expect(filter, contains(term.replaceAll("'", "''")));
        }
        expect(fixture.client.requests, hasLength(4));
      },
    );

    test(
      '$name rejects excessive encoding even below the character limit',
      () async {
        final fixture = _Fixture();
        final term = 'e${'\u0301' * 6000}';
        expect(AdminSearchLimits.validate(term), isNull);
        final result = await fixture.search(name, term);
        expect(result.failure, isA<ValidationFailure>());
        expect(
          result.failure!.message,
          'Use a shorter search or fewer filters.',
        );
        expect(fixture.client.requests, isEmpty);
      },
    );
  }
}

class _Fixture {
  final config = AppConfig.defaults();
  final cookies = _Cookies();
  final client = _Client();
  static const page = PageRequest(page: 1, pageSize: 15);

  Future<Result<Object?>> search(String name, String term) {
    return switch (name) {
      'generic' =>
        AcpAdminRepositoryImpl(
          appConfig: config,
          authenticatedHttpClient: client,
        ).listRows(
          descriptor: const AcpResourceDescriptor(
            key: 'examples',
            title: 'Examples',
            entitySet: 'Examples',
            scopeMode: AcpScopeMode.none,
            columns: [],
            searchFields: ['Name', 'Description'],
          ),
          pageRequest: page,
          searchTerm: term,
        ),
      'users' => UserAdminRepositoryImpl(
        appConfig: config,
        cookieStore: cookies,
        authenticatedHttpClient: client,
      ).fetchUsers(UserListQuery(pageRequest: page, searchTerm: term)),
      'tenants' => TenantAdminRepositoryImpl(
        appConfig: config,
        cookieStore: cookies,
        authenticatedHttpClient: client,
      ).fetchTenants(TenantListQuery(pageRequest: page, searchTerm: term)),
      'audit' =>
        AuditAdminRepositoryImpl(
          appConfig: config,
          cookieStore: cookies,
          authenticatedHttpClient: client,
        ).fetchAuditEvents(
          AuditEventListQuery(
            pageRequest: page,
            scopeMode: AuditAdminScopeMode.global,
            searchTerm: term,
          ),
        ),
      _ =>
        BillingCatalogRepositoryImpl(
          appConfig: config,
          authenticatedHttpClient: client,
        ).fetchProducts(
          BillingCatalogListQuery(
            pageRequest: page,
            lifecycleView: BillingCatalogLifecycleView.active,
            searchTerm: term,
          ),
        ),
    };
  }
}

class _Client extends AuthenticatedHttpClient {
  _Client()
    : super(
        httpClient: AcpHttpClient(
          baseUrl: 'https://example.test',
          transport: _Transport(),
        ),
        cookieStore: _Cookies(),
        refreshPath: '/refresh',
      );
  final requests = <AcpRequest>[];

  @override
  Future<AuthenticatedResponse> send(AcpRequest request) async {
    requests.add(request);
    return const AuthenticatedResponse(
      response: HttpResponse(
        statusCode: 200,
        body: '{"value":[],"@count":0}',
        headers: {},
      ),
      sessionExpired: false,
    );
  }
}

class _Cookies implements CookieStore {
  @override
  String? getCookie(String key) => null;
  @override
  void removeCookie(String key, String path) {}
  @override
  void setCookie(String key, String value, int maxAge, String path) {}
}

class _Transport implements HttpTransport {
  @override
  void close() {}
  @override
  Future<HttpResponse> execute(HttpRequest request) =>
      throw UnimplementedError();
}
