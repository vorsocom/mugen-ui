import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';

String serviceProfileReadiness({
  required AcpRow profile,
  required List<AcpRow> assignments,
  required Map<String, AcpRow> bindings,
  required bool statusAvailable,
}) {
  final status = _text(profile['Status']).toLowerCase();
  if (status == 'draft') {
    return 'Draft profile';
  }
  if (status == 'disabled') {
    return 'Disabled';
  }
  if (!statusAvailable) {
    return 'Status unavailable';
  }
  if (assignments.isEmpty) {
    return 'Missing active ingress';
  }
  if (assignments.any((assignment) {
    if (assignment['IsActive'] != true) {
      return false;
    }
    final bindingId = _text(assignment['IngressBindingId']);
    return bindings[bindingId]?['IsActive'] == true;
  })) {
    return 'Active and routable';
  }
  return 'Inactive ingress assignment';
}

String serviceProfileSubscriptionAccessState({
  required AcpRow assignment,
  required AcpRow? subscription,
  DateTime? now,
}) {
  final assignmentStatus = _text(assignment['Status']).toLowerCase();
  if (assignmentStatus == 'disabled') {
    return 'Disabled';
  }
  if (subscription == null) {
    return 'Status unavailable';
  }
  final account = _map(subscription['Account']);
  final assignmentTenant = _text(assignment['TenantId']);
  final subscriptionTenant = _text(subscription['TenantId']);
  final accountTenant = _text(account?['TenantId']);
  if (account == null ||
      (assignmentTenant.isNotEmpty &&
          subscriptionTenant.isNotEmpty &&
          assignmentTenant != subscriptionTenant) ||
      (assignmentTenant.isNotEmpty &&
          accountTenant.isNotEmpty &&
          assignmentTenant != accountTenant)) {
    return 'Billing Account mismatch';
  }
  final price = _map(subscription['Price']);
  if (price == null) {
    return 'Missing Price';
  }
  final product = _map(price['Product']);
  if (product == null) {
    return 'Missing Product';
  }
  final assignedProduct = _text(assignment['ProductCode']).toLowerCase();
  final currentProduct = _text(product['Code']).toLowerCase();
  if (assignedProduct.isNotEmpty &&
      currentProduct.isNotEmpty &&
      assignedProduct != currentProduct) {
    return 'Product catalog drift';
  }
  final subscriptionStatus = _text(subscription['Status']).toLowerCase();
  if (const <String>{
    'paused',
    'cancelled',
    'canceled',
  }.contains(subscriptionStatus)) {
    return 'Subscription paused or cancelled';
  }
  final effectiveNow = now ?? DateTime.now().toUtc();
  final periodEnd = DateTime.tryParse(_text(subscription['CurrentPeriodEnd']));
  final endedAt = DateTime.tryParse(_text(subscription['EndedAt']));
  if (subscriptionStatus == 'expired' ||
      (periodEnd != null && !periodEnd.toUtc().isAfter(effectiveNow)) ||
      (endedAt != null && !endedAt.toUtc().isAfter(effectiveNow))) {
    return 'Subscription expired';
  }
  if (assignmentStatus == 'draft') {
    return 'Draft assignment';
  }
  if (assignmentStatus == 'active') {
    return 'Active Product access';
  }
  return 'Status unavailable';
}

String serviceProfileIngressAssignmentState({
  required AcpRow assignment,
  required AcpRow? binding,
}) {
  if (assignment['IsActive'] != true) {
    return 'Inactive ingress assignment';
  }
  if (binding == null) {
    return 'Status unavailable';
  }
  return binding['IsActive'] == true
      ? 'Active endpoint assignment'
      : 'Inactive ingress assignment';
}

String serviceProfileCurrentPeriod(AcpRow? subscription) {
  if (subscription == null) {
    return 'Unavailable';
  }
  final start = _text(subscription['CurrentPeriodStart']);
  final end = _text(subscription['CurrentPeriodEnd']);
  if (start.isEmpty && end.isEmpty) {
    return 'Not set';
  }
  if (start.isEmpty) {
    return 'Until $end';
  }
  if (end.isEmpty) {
    return 'From $start';
  }
  return '$start — $end';
}

Map<String, dynamic>? _map(Object? value) {
  if (value is! Map) {
    return null;
  }
  return Map<String, dynamic>.from(value);
}

String _text(Object? value) => value?.toString().trim() ?? '';
