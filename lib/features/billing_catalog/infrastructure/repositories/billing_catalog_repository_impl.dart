import 'dart:convert';

import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/features/billing_catalog/application/dto/billing_catalog_inputs.dart';
import 'package:mugen_ui/features/billing_catalog/domain/entities/billing_catalog_entities.dart';
import 'package:mugen_ui/features/billing_catalog/domain/repositories/billing_catalog_repository.dart';
import 'package:mugen_ui/shared/application/api_error_message.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/infrastructure/http/acp_http_client.dart';
import 'package:mugen_ui/shared/infrastructure/http/authenticated_http_client.dart';
import 'package:mugen_ui/shared/infrastructure/http/http_transport.dart';

class BillingCatalogRepositoryImpl implements BillingCatalogRepository {
  BillingCatalogRepositoryImpl({
    required this.appConfig,
    required this.authenticatedHttpClient,
  });

  static const String _billingExtensionToken = 'core.fw.billing';
  static const String _productsEntitySet = 'BillingProducts';
  static const String _pricesEntitySet = 'BillingPrices';

  final AppConfig appConfig;
  final AuthenticatedHttpClient authenticatedHttpClient;

  @override
  Future<Result<BillingExtensionStatusEntity>>
  fetchBillingExtensionStatus() async {
    final response = await _send(
      AcpRequest(
        method: HttpMethod.get,
        path:
            '${appConfig.api.endpoints.runtimeExtensions}/$_billingExtensionToken',
      ),
    );
    if (response.isFailure) {
      return Result<BillingExtensionStatusEntity>.failure(response.failure!);
    }

    final body = _decodeMap(response.data!.response.body);
    if (body == null) {
      return const Result<BillingExtensionStatusEntity>.failure(
        UnexpectedFailure('Unexpected runtime extension response.'),
      );
    }

    return Result<BillingExtensionStatusEntity>.success(
      BillingExtensionStatusEntity(
        token: _asString(body['token']),
        extensionType: _asString(body['extension_type']),
        configured: _asBool(body['configured']),
        enabled: _asBool(body['enabled']),
        available: _asBool(body['available']),
        status: _asString(body['status']),
        reason: _asNullableString(body['reason']),
      ),
    );
  }

  @override
  Future<Result<void>> verifyCatalogReadAccess() async {
    for (final entitySet in const <String>[
      _productsEntitySet,
      _pricesEntitySet,
    ]) {
      final response = await _send(
        AcpRequest(
          method: HttpMethod.get,
          path: _collectionPath(entitySet),
          queryParameters: const <String, dynamic>{
            r'$top': 1,
            r'$count': true,
            r'$deleted': 'active',
          },
        ),
      );
      if (response.isFailure) {
        return Result<void>.failure(response.failure!);
      }
    }
    return const Result<void>.success(null);
  }

  @override
  Future<Result<PageResult<BillingProductEntity>>> fetchProducts(
    BillingCatalogListQuery query,
  ) async {
    final response = await _list(
      entitySet: _productsEntitySet,
      query: query,
      orderBy: 'Code asc',
      searchFields: const <String>['Code', 'Name', 'Description'],
    );
    if (response.isFailure) {
      return Result<PageResult<BillingProductEntity>>.failure(
        response.failure!,
      );
    }

    final page = response.data!;
    return Result<PageResult<BillingProductEntity>>.success(
      PageResult<BillingProductEntity>(
        items: page.items.map(_mapProduct).toList(growable: false),
        total: page.total,
        page: page.page,
        pageSize: page.pageSize,
      ),
    );
  }

  @override
  Future<Result<PageResult<BillingPriceEntity>>> fetchPrices(
    BillingCatalogListQuery query,
  ) async {
    final response = await _list(
      entitySet: _pricesEntitySet,
      query: query,
      orderBy: 'Code asc',
      searchFields: const <String>[
        'Code',
        'PriceType',
        'Currency',
        'UsageUnit',
        'MeterCode',
      ],
    );
    if (response.isFailure) {
      return Result<PageResult<BillingPriceEntity>>.failure(response.failure!);
    }

    final page = response.data!;
    return Result<PageResult<BillingPriceEntity>>.success(
      PageResult<BillingPriceEntity>(
        items: page.items.map(_mapPrice).toList(growable: false),
        total: page.total,
        page: page.page,
        pageSize: page.pageSize,
      ),
    );
  }

  @override
  Future<Result<void>> createProduct(BillingProductCreateInput input) {
    return _mutate(
      method: HttpMethod.post,
      path: _collectionPath(_productsEntitySet),
      body: _productBody(input),
    );
  }

  @override
  Future<Result<void>> updateProduct(BillingProductUpdateInput input) {
    return _mutate(
      method: HttpMethod.patch,
      path: '${_collectionPath(_productsEntitySet)}/${input.id}',
      body: <String, dynamic>{
        ..._productBody(input),
        'RowVersion': input.rowVersion,
      },
    );
  }

  @override
  Future<Result<void>> archiveProduct(BillingCatalogLifecycleInput input) {
    return _archive(_productsEntitySet, input);
  }

  @override
  Future<Result<void>> restoreProduct(BillingCatalogLifecycleInput input) {
    return _restore(_productsEntitySet, input);
  }

  @override
  Future<Result<void>> createPrice(BillingPriceCreateInput input) {
    return _mutate(
      method: HttpMethod.post,
      path: _collectionPath(_pricesEntitySet),
      body: _priceBody(input),
    );
  }

  @override
  Future<Result<void>> updatePrice(BillingPriceUpdateInput input) {
    return _mutate(
      method: HttpMethod.patch,
      path: '${_collectionPath(_pricesEntitySet)}/${input.id}',
      body: <String, dynamic>{
        ..._priceBody(input),
        'RowVersion': input.rowVersion,
      },
    );
  }

  @override
  Future<Result<void>> archivePrice(BillingCatalogLifecycleInput input) {
    return _archive(_pricesEntitySet, input);
  }

  @override
  Future<Result<void>> restorePrice(BillingCatalogLifecycleInput input) {
    return _restore(_pricesEntitySet, input);
  }

  Future<Result<_RawPage>> _list({
    required String entitySet,
    required BillingCatalogListQuery query,
    required String orderBy,
    required List<String> searchFields,
  }) async {
    final filters = <String>[];
    final productId = query.productId?.trim();
    if (productId != null && productId.isNotEmpty) {
      filters.add("ProductId eq guid'$productId'");
    }
    final searchTerm = query.searchTerm?.trim();
    if (searchTerm != null && searchTerm.length >= 2) {
      final escaped = searchTerm.replaceAll("'", "''");
      filters.add(
        '(${searchFields.map((field) => "contains($field,'$escaped')").join(' or ')})',
      );
    }

    final queryParameters = <String, dynamic>{
      r'$count': true,
      r'$skip': query.pageRequest.skip,
      r'$top': query.pageRequest.pageSize,
      r'$orderby': orderBy,
      r'$deleted': query.lifecycleView.name,
      if (filters.isNotEmpty) r'$filter': filters.join(' and '),
    };
    final response = await _send(
      AcpRequest(
        method: HttpMethod.get,
        path: _collectionPath(entitySet),
        queryParameters: queryParameters,
      ),
    );
    if (response.isFailure) {
      return Result<_RawPage>.failure(response.failure!);
    }

    final body = _decodeMap(response.data!.response.body);
    if (body == null) {
      return const Result<_RawPage>.failure(
        UnexpectedFailure('Unexpected Billing catalog response.'),
      );
    }
    final rawItems = body['value'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList(growable: false)
        : const <Map<String, dynamic>>[];
    final total = _asInt(body['@count']) ?? items.length;
    return Result<_RawPage>.success(
      _RawPage(
        items: items,
        total: total,
        page: query.pageRequest.page,
        pageSize: query.pageRequest.pageSize,
      ),
    );
  }

  Future<Result<void>> _archive(
    String entitySet,
    BillingCatalogLifecycleInput input,
  ) {
    return _mutate(
      method: HttpMethod.post,
      path: '${_collectionPath(entitySet)}/${input.id}/\$action/archive',
      body: <String, dynamic>{'RowVersion': input.rowVersion},
    );
  }

  Future<Result<void>> _restore(
    String entitySet,
    BillingCatalogLifecycleInput input,
  ) {
    return _mutate(
      method: HttpMethod.post,
      path: '${_collectionPath(entitySet)}/${input.id}/\$restore',
      body: <String, dynamic>{'RowVersion': input.rowVersion},
    );
  }

  Future<Result<void>> _mutate({
    required HttpMethod method,
    required String path,
    required Map<String, dynamic> body,
  }) async {
    final response = await _send(
      AcpRequest(method: method, path: path, body: body),
    );
    if (response.isFailure) {
      return Result<void>.failure(response.failure!);
    }
    return const Result<void>.success(null);
  }

  Future<Result<AuthenticatedResponse>> _send(AcpRequest request) async {
    try {
      final response = await authenticatedHttpClient.send(request);
      if (response.sessionExpired) {
        return const Result<AuthenticatedResponse>.failure(
          SessionExpiredFailure(),
        );
      }
      if (response.response.statusCode == 401) {
        return const Result<AuthenticatedResponse>.failure(
          UnauthorizedFailure(),
        );
      }
      if (!response.response.isSuccess) {
        return Result<AuthenticatedResponse>.failure(
          ApiFailure(
            response.response.statusCode,
            normalizeApiErrorMessage(response.response.body),
          ),
        );
      }
      return Result<AuthenticatedResponse>.success(response);
    } catch (_) {
      return const Result<AuthenticatedResponse>.failure(
        NetworkFailure('Network request failed.'),
      );
    }
  }

  String _collectionPath(String entitySet) {
    return '${appConfig.api.endpoints.acpBase}/$entitySet';
  }

  Map<String, dynamic> _productBody(BillingProductCreateInput input) {
    return <String, dynamic>{
      'Code': input.code.trim(),
      'Name': input.name.trim(),
      'Description': _trimmedOrNull(input.description),
      'Attributes': input.attributes,
    };
  }

  Map<String, dynamic> _priceBody(BillingPriceCreateInput input) {
    return <String, dynamic>{
      'ProductId': input.productId.trim(),
      'Code': input.code.trim(),
      'PriceType': input.priceType.trim().toLowerCase(),
      'Currency': input.currency.trim().toUpperCase(),
      'UnitAmount': input.unitAmount,
      'IntervalUnit': _trimmedOrNull(input.intervalUnit)?.toLowerCase(),
      'IntervalCount': input.intervalCount,
      'TrialPeriodDays': input.trialPeriodDays,
      'UsageUnit': _trimmedOrNull(input.usageUnit),
      'MeterCode': _trimmedOrNull(input.meterCode),
      'Attributes': input.attributes,
    };
  }

  BillingProductEntity _mapProduct(Map<String, dynamic> row) {
    final deletedAt = _asDateTime(row['DeletedAt']);
    return BillingProductEntity(
      id: _asString(row['Id']),
      code: _asString(row['Code']),
      name: _asString(row['Name']),
      description: _asNullableString(row['Description']),
      attributes: row['Attributes'],
      createdAt: _asDateTime(row['CreatedAt']),
      updatedAt: _asDateTime(row['UpdatedAt']),
      deletedAt: deletedAt,
      rowVersion: _asInt(row['RowVersion']) ?? 0,
      isArchived: _asBool(row['IsArchived']) || deletedAt != null,
    );
  }

  BillingPriceEntity _mapPrice(Map<String, dynamic> row) {
    final deletedAt = _asDateTime(row['DeletedAt']);
    return BillingPriceEntity(
      id: _asString(row['Id']),
      productId: _asString(row['ProductId']),
      code: _asString(row['Code']),
      priceType: _asString(row['PriceType']),
      currency: _asString(row['Currency']),
      unitAmount: _asInt(row['UnitAmount']),
      intervalUnit: _asNullableString(row['IntervalUnit']),
      intervalCount: _asInt(row['IntervalCount']),
      trialPeriodDays: _asInt(row['TrialPeriodDays']),
      usageUnit: _asNullableString(row['UsageUnit']),
      meterCode: _asNullableString(row['MeterCode']),
      attributes: row['Attributes'],
      createdAt: _asDateTime(row['CreatedAt']),
      updatedAt: _asDateTime(row['UpdatedAt']),
      deletedAt: deletedAt,
      rowVersion: _asInt(row['RowVersion']) ?? 0,
      isArchived: _asBool(row['IsArchived']) || deletedAt != null,
    );
  }

  Map<String, dynamic>? _decodeMap(String raw) {
    final decoded = _decodeJson(raw);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
  }

  Object? _decodeJson(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    try {
      return jsonDecode(trimmed);
    } catch (_) {
      return trimmed;
    }
  }

  String _asString(Object? value) => value?.toString().trim() ?? '';

  String? _asNullableString(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  bool _asBool(Object? value) {
    if (value is bool) {
      return value;
    }
    return value?.toString().trim().toLowerCase() == 'true';
  }

  int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '');
  }

  DateTime? _asDateTime(Object? value) {
    final text = _asNullableString(value);
    return text == null ? null : DateTime.tryParse(text)?.toUtc();
  }

  String? _trimmedOrNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

class _RawPage {
  const _RawPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  final List<Map<String, dynamic>> items;
  final int total;
  final int page;
  final int pageSize;
}
