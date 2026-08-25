import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/features/billing_catalog/application/dto/billing_catalog_inputs.dart';
import 'package:mugen_ui/features/billing_catalog/domain/entities/billing_catalog_entities.dart';
import 'package:mugen_ui/features/billing_catalog/infrastructure/repositories/billing_catalog_repository_impl.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/infrastructure/auth/cookie_store.dart';
import 'package:mugen_ui/shared/infrastructure/http/acp_http_client.dart';
import 'package:mugen_ui/shared/infrastructure/http/authenticated_http_client.dart';
import 'package:mugen_ui/shared/infrastructure/http/http_transport.dart';

void main() {
  group('BillingCatalogRepositoryImpl discovery and access', () {
    test('maps registered runtime extension status', () async {
      final fixture = _Fixture(<_AuthHandler>[
        (_) => _response(
          200,
          body: jsonEncode(<String, dynamic>{
            'token': 'core.fw.billing',
            'extension_type': 'fw',
            'configured': 'true',
            'enabled': true,
            'available': true,
            'status': 'registered',
            'reason': ' ',
          }),
        ),
      ]);

      final result = await fixture.repository.fetchBillingExtensionStatus();

      expect(result.isSuccess, isTrue);
      expect(result.data!.token, 'core.fw.billing');
      expect(result.data!.extensionType, 'fw');
      expect(result.data!.configured, isTrue);
      expect(result.data!.enabled, isTrue);
      expect(result.data!.available, isTrue);
      expect(result.data!.status, 'registered');
      expect(result.data!.reason, isNull);
      expect(result.data!.isRegistered, isTrue);
      expect(
        fixture.client.requests.single.path,
        'core/acp/v1/runtime/extensions/core.fw.billing',
      );
    });

    test('rejects malformed runtime extension responses', () async {
      final fixture = _Fixture(<_AuthHandler>[
        (_) => _response(200, body: '[]'),
      ]);

      final result = await fixture.repository.fetchBillingExtensionStatus();

      expect(result.failure, isA<UnexpectedFailure>());
      expect(result.failure!.message, 'Unexpected runtime extension response.');
    });

    test('verifies both global catalog collection reads', () async {
      final fixture = _Fixture(<_AuthHandler>[
        (_) => _response(200, body: '{}'),
        (_) => _response(200, body: '{}'),
      ]);

      final result = await fixture.repository.verifyCatalogReadAccess();

      expect(result.isSuccess, isTrue);
      expect(fixture.client.requests.map((request) => request.path), <String>[
        'core/acp/v1/BillingProducts',
        'core/acp/v1/BillingPrices',
      ]);
      for (final request in fixture.client.requests) {
        expect(request.path, isNot(contains('tenants/')));
        expect(request.queryParameters, <String, dynamic>{
          r'$top': 1,
          r'$count': true,
          r'$deleted': 'active',
        });
        expect(request.queryParameters.containsKey('TenantId'), isFalse);
      }
    });

    test('stops access probing after the first failure', () async {
      final fixture = _Fixture(<_AuthHandler>[
        (_) => _response(403, body: '{"message":"forbidden"}'),
      ]);

      final result = await fixture.repository.verifyCatalogReadAccess();

      expect(
        result.failure,
        isA<ApiFailure>()
            .having((failure) => failure.statusCode, 'statusCode', 403)
            .having((failure) => failure.message, 'message', 'forbidden'),
      );
      expect(fixture.client.requests, hasLength(1));
    });
  });

  group('BillingCatalogRepositoryImpl global lists', () {
    test(
      'maps Products and composes pagination, lifecycle, and search',
      () async {
        final fixture = _Fixture(<_AuthHandler>[
          (_) => _response(
            200,
            body: jsonEncode(<String, dynamic>{
              '@count': '1',
              'value': <Map<String, dynamic>>[
                <String, dynamic>{
                  'Id': 'product-1',
                  'Code': 'PRO',
                  'Name': 'Pro',
                  'Description': 'Professional plan',
                  'Attributes': <String, dynamic>{'tier': 2},
                  'CreatedAt': '2026-08-01T10:00:00-04:00',
                  'UpdatedAt': '2026-08-02T14:00:00Z',
                  'DeletedAt': '2026-08-03T00:00:00Z',
                  'RowVersion': '7',
                  'IsArchived': false,
                },
              ],
            }),
          ),
        ]);

        final result = await fixture.repository.fetchProducts(
          const BillingCatalogListQuery(
            pageRequest: PageRequest(page: 3, pageSize: 20),
            lifecycleView: BillingCatalogLifecycleView.all,
            searchTerm: " pro' ",
          ),
        );

        expect(result.isSuccess, isTrue);
        expect(result.data!.total, 1);
        expect(result.data!.page, 3);
        expect(result.data!.pageSize, 20);
        final product = result.data!.items.single;
        expect(product.id, 'product-1');
        expect(product.code, 'PRO');
        expect(product.name, 'Pro');
        expect(product.description, 'Professional plan');
        expect(product.attributes, <String, dynamic>{'tier': 2});
        expect(product.createdAt, DateTime.utc(2026, 8, 1, 14));
        expect(product.updatedAt, DateTime.utc(2026, 8, 2, 14));
        expect(product.deletedAt, DateTime.utc(2026, 8, 3));
        expect(product.rowVersion, 7);
        expect(product.isArchived, isTrue);
        expect(product.selectorLabel, 'PRO — Pro');

        final request = fixture.client.requests.single;
        expect(request.path, 'core/acp/v1/BillingProducts');
        expect(request.queryParameters[r'$skip'], 40);
        expect(request.queryParameters[r'$top'], 20);
        expect(request.queryParameters[r'$orderby'], 'Code asc');
        expect(request.queryParameters[r'$deleted'], 'all');
        expect(
          request.queryParameters[r'$filter'],
          "(contains(Code,'pro''') or contains(Name,'pro''') or contains(Description,'pro'''))",
        );
        expect(request.body, isNull);
        expect(request.path, isNot(contains('tenant')));
      },
    );

    test('maps Prices and combines Product and text filters', () async {
      final fixture = _Fixture(<_AuthHandler>[
        (_) => _response(
          200,
          body: jsonEncode(<String, dynamic>{
            'value': <Map<String, dynamic>>[
              <String, dynamic>{
                'Id': 'price-1',
                'ProductId': 'product-1',
                'Code': 'MONTHLY',
                'PriceType': 'recurring',
                'Currency': 'USD',
                'UnitAmount': '1999',
                'IntervalUnit': 'month',
                'IntervalCount': 2,
                'TrialPeriodDays': '14',
                'UsageUnit': 'requests',
                'MeterCode': 'api_calls',
                'Attributes': '{"popular":true}',
                'CreatedAt': null,
                'UpdatedAt': 'invalid',
                'DeletedAt': null,
                'RowVersion': 4,
                'IsArchived': 'true',
              },
            ],
          }),
        ),
      ]);

      final result = await fixture.repository.fetchPrices(
        const BillingCatalogListQuery(
          pageRequest: PageRequest(page: 1, pageSize: 15),
          lifecycleView: BillingCatalogLifecycleView.archived,
          searchTerm: 'usd',
          productId: ' product-1 ',
        ),
      );

      expect(result.data!.total, 1);
      final price = result.data!.items.single;
      expect(price.id, 'price-1');
      expect(price.productId, 'product-1');
      expect(price.unitAmount, 1999);
      expect(price.intervalCount, 2);
      expect(price.trialPeriodDays, 14);
      expect(price.attributes, '{"popular":true}');
      expect(price.createdAt, isNull);
      expect(price.updatedAt, isNull);
      expect(price.isArchived, isTrue);
      expect(price.billingInterval, '2 month');

      final request = fixture.client.requests.single;
      expect(request.path, 'core/acp/v1/BillingPrices');
      expect(request.queryParameters[r'$deleted'], 'archived');
      expect(
        request.queryParameters[r'$filter'],
        allOf(
          contains("ProductId eq guid'product-1'"),
          contains("contains(Currency,'usd')"),
        ),
      );
      expect(request.queryParameters.toString(), isNot(contains('TenantId')));
    });

    test('omits empty Product and short search filters', () async {
      final fixture = _Fixture(<_AuthHandler>[
        (_) => _response(200, body: '{"@count":"bad","value":[]}'),
      ]);

      final result = await fixture.repository.fetchPrices(
        const BillingCatalogListQuery(
          pageRequest: PageRequest(page: 1, pageSize: 10),
          lifecycleView: BillingCatalogLifecycleView.active,
          searchTerm: 'x',
          productId: ' ',
        ),
      );

      expect(result.data!.total, 0);
      expect(
        fixture.client.requests.single.queryParameters[r'$filter'],
        isNull,
      );
    });

    test('handles a non-list value and malformed list response', () async {
      final fixture = _Fixture(<_AuthHandler>[
        (_) => _response(200, body: '{"value":{}}'),
        (_) => _response(200, body: 'not-json'),
      ]);
      const query = BillingCatalogListQuery(
        pageRequest: PageRequest(page: 1, pageSize: 10),
        lifecycleView: BillingCatalogLifecycleView.active,
      );

      final empty = await fixture.repository.fetchProducts(query);
      final malformed = await fixture.repository.fetchProducts(query);

      expect(empty.data!.items, isEmpty);
      expect(empty.data!.total, 0);
      expect(malformed.failure, isA<UnexpectedFailure>());
    });
  });

  group('BillingCatalogRepositoryImpl mutations', () {
    test(
      'uses global routes, normalized payloads, and RowVersion actions',
      () async {
        final fixture = _Fixture(
          List<_AuthHandler>.filled(8, (_) => _response(204)),
        );

        await fixture.repository.createProduct(
          const BillingProductCreateInput(
            code: ' pro ',
            name: ' Pro Plan ',
            description: ' ',
            attributes: <String, dynamic>{'tier': 'pro'},
          ),
        );
        await fixture.repository.updateProduct(
          const BillingProductUpdateInput(
            id: 'product-1',
            rowVersion: 3,
            code: ' pro ',
            name: ' Pro Plan ',
            description: ' Updated ',
          ),
        );
        await fixture.repository.archiveProduct(
          const BillingCatalogLifecycleInput(id: 'product-1', rowVersion: 4),
        );
        await fixture.repository.restoreProduct(
          const BillingCatalogLifecycleInput(id: 'product-1', rowVersion: 5),
        );
        const price = BillingPriceCreateInput(
          productId: ' product-1 ',
          code: ' monthly ',
          priceType: ' RECURRING ',
          currency: ' usd ',
          unitAmount: 2500,
          intervalUnit: ' MONTH ',
          intervalCount: 1,
          trialPeriodDays: 7,
          usageUnit: ' seats ',
          meterCode: ' ',
          attributes: <String, dynamic>{'public': true},
        );
        await fixture.repository.createPrice(price);
        await fixture.repository.updatePrice(
          const BillingPriceUpdateInput(
            id: 'price-1',
            rowVersion: 9,
            productId: ' product-1 ',
            code: ' monthly ',
            priceType: ' RECURRING ',
            currency: ' usd ',
            unitAmount: 2500,
            intervalUnit: ' MONTH ',
            intervalCount: 1,
            trialPeriodDays: 7,
            usageUnit: ' seats ',
            meterCode: ' ',
            attributes: <String, dynamic>{'public': true},
          ),
        );
        await fixture.repository.archivePrice(
          const BillingCatalogLifecycleInput(id: 'price-1', rowVersion: 10),
        );
        await fixture.repository.restorePrice(
          const BillingCatalogLifecycleInput(id: 'price-1', rowVersion: 11),
        );

        final requests = fixture.client.requests;
        expect(requests.map((request) => request.path), <String>[
          'core/acp/v1/BillingProducts',
          'core/acp/v1/BillingProducts/product-1',
          r'core/acp/v1/BillingProducts/product-1/$action/archive',
          r'core/acp/v1/BillingProducts/product-1/$restore',
          'core/acp/v1/BillingPrices',
          'core/acp/v1/BillingPrices/price-1',
          r'core/acp/v1/BillingPrices/price-1/$action/archive',
          r'core/acp/v1/BillingPrices/price-1/$restore',
        ]);
        expect(requests.map((request) => request.method), <HttpMethod>[
          HttpMethod.post,
          HttpMethod.patch,
          HttpMethod.post,
          HttpMethod.post,
          HttpMethod.post,
          HttpMethod.patch,
          HttpMethod.post,
          HttpMethod.post,
        ]);
        expect(requests[0].body, <String, dynamic>{
          'Code': 'pro',
          'Name': 'Pro Plan',
          'Description': null,
          'Attributes': <String, dynamic>{'tier': 'pro'},
        });
        expect((requests[1].body! as Map)['Description'], 'Updated');
        expect((requests[1].body! as Map)['RowVersion'], 3);
        expect(requests[2].body, <String, dynamic>{'RowVersion': 4});
        expect(requests[3].body, <String, dynamic>{'RowVersion': 5});
        expect(requests[4].body, <String, dynamic>{
          'ProductId': 'product-1',
          'Code': 'monthly',
          'PriceType': 'recurring',
          'Currency': 'USD',
          'UnitAmount': 2500,
          'IntervalUnit': 'month',
          'IntervalCount': 1,
          'TrialPeriodDays': 7,
          'UsageUnit': 'seats',
          'MeterCode': null,
          'Attributes': <String, dynamic>{'public': true},
        });
        expect((requests[5].body! as Map)['RowVersion'], 9);
        expect(requests[6].body, <String, dynamic>{'RowVersion': 10});
        expect(requests[7].body, <String, dynamic>{'RowVersion': 11});
        for (final request in requests) {
          expect(request.path, isNot(contains('tenants/')));
          final body = request.body;
          expect(body is Map && body.containsKey('TenantId'), isFalse);
        }
      },
    );
  });

  group('BillingCatalogRepositoryImpl failures', () {
    test('maps session expiry and unauthorized responses', () async {
      final fixture = _Fixture(<_AuthHandler>[
        (_) => _response(401, sessionExpired: true),
        (_) => _response(401),
      ]);

      final expired = await fixture.repository.fetchBillingExtensionStatus();
      final unauthorized = await fixture.repository
          .fetchBillingExtensionStatus();

      expect(expired.failure, isA<SessionExpiredFailure>());
      expect(unauthorized.failure, isA<UnauthorizedFailure>());
    });

    test('extracts JSON, HTML, plain, and empty API errors', () async {
      final fixture = _Fixture(<_AuthHandler>[
        (_) => _response(409, body: '{"error":"json error"}'),
        (_) => _response(409, body: '<html><p><b>HTML</b> error</p></html>'),
        (_) => _response(409, body: 'plain error'),
        (_) => _response(409),
      ]);
      const input = BillingProductCreateInput(code: 'x', name: 'X');

      final jsonFailure = await fixture.repository.createProduct(input);
      final htmlFailure = await fixture.repository.createProduct(input);
      final plainFailure = await fixture.repository.createProduct(input);
      final emptyFailure = await fixture.repository.createProduct(input);

      expect(jsonFailure.failure!.message, 'json error');
      expect(htmlFailure.failure!.message, 'HTML error');
      expect(plainFailure.failure!.message, 'plain error');
      expect(emptyFailure.failure, isA<ApiFailure>());
      expect(emptyFailure.failure!.message, 'API request failed.');
    });

    test('maps thrown transport errors to NetworkFailure', () async {
      final fixture = _Fixture(<_AuthHandler>[
        (_) => throw StateError('offline'),
      ]);

      final result = await fixture.repository.fetchBillingExtensionStatus();

      expect(result.failure, isA<NetworkFailure>());
      expect(result.failure!.message, 'Network request failed.');
    });

    test('propagates list request failures', () async {
      final fixture = _Fixture(<_AuthHandler>[
        (_) => _response(500, body: '{"detail":"products failed"}'),
        (_) => _response(500, body: '{"message":"prices failed"}'),
      ]);
      const query = BillingCatalogListQuery(
        pageRequest: PageRequest(page: 1, pageSize: 10),
        lifecycleView: BillingCatalogLifecycleView.active,
      );

      final products = await fixture.repository.fetchProducts(query);
      final prices = await fixture.repository.fetchPrices(query);

      expect(products.failure!.message, 'products failed');
      expect(prices.failure!.message, 'prices failed');
    });
  });
}

class _Fixture {
  _Fixture(List<_AuthHandler> handlers)
    : client = _QueueAuthenticatedHttpClient(handlers) {
    repository = BillingCatalogRepositoryImpl(
      appConfig: AppConfig.defaults(),
      authenticatedHttpClient: client,
    );
  }

  final _QueueAuthenticatedHttpClient client;
  late final BillingCatalogRepositoryImpl repository;
}

typedef _AuthHandler = FutureOr<AuthenticatedResponse> Function(AcpRequest);

class _QueueAuthenticatedHttpClient extends AuthenticatedHttpClient {
  _QueueAuthenticatedHttpClient(List<_AuthHandler> handlers)
    : _handlers = Queue<_AuthHandler>.from(handlers),
      super(
        httpClient: AcpHttpClient(
          baseUrl: 'https://example.com/api',
          transport: _NoopHttpTransport(),
        ),
        cookieStore: _MemoryCookieStore(),
        refreshPath: 'core/acp/v1/auth/refresh',
      );

  final Queue<_AuthHandler> _handlers;
  final List<AcpRequest> requests = <AcpRequest>[];

  @override
  Future<AuthenticatedResponse> send(AcpRequest request) async {
    requests.add(request);
    return await _handlers.removeFirst()(request);
  }
}

class _MemoryCookieStore implements CookieStore {
  final Map<String, String> _cookies = <String, String>{};

  @override
  String? getCookie(String key) => _cookies[key];

  @override
  void removeCookie(String key, String path) {
    _cookies.remove(key);
  }

  @override
  void setCookie(String key, String value, int maxAge, String path) {
    _cookies[key] = value;
  }
}

class _NoopHttpTransport implements HttpTransport {
  @override
  void close() {}

  @override
  Future<HttpResponse> execute(HttpRequest request) {
    throw UnimplementedError();
  }
}

AuthenticatedResponse _response(
  int statusCode, {
  String body = '',
  bool sessionExpired = false,
}) {
  return AuthenticatedResponse(
    response: HttpResponse(
      statusCode: statusCode,
      body: body,
      headers: const <String, String>{},
    ),
    sessionExpired: sessionExpired,
  );
}
