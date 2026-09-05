import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_repository.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';

const ingressMessagingChannels = <String>[
  'line',
  'matrix',
  'signal',
  'telegram',
  'wechat',
  'whatsapp',
];

const ingressClientIdentifierFields = <String, String>{
  'path_token': 'PathToken',
  'phone_number_id': 'PhoneNumberId',
  'recipient_user_id': 'RecipientUserId',
  'account_number': 'AccountNumber',
};

List<String> ingressIdentifierOptions(AcpRow values) =>
    ingressMessagingChannels.contains(_text(values, 'ChannelKey').toLowerCase())
    ? const <String>[]
    : const <String>['tenant_slug'];

String? validateIngressBindingFields(AcpRow values) {
  if (<String>[
    'ChannelKey',
    'IdentifierType',
    'IdentifierValue',
  ].any((key) => _text(values, key).isEmpty)) {
    return 'Channel, Identifier Type and Identifier Value are required.';
  }
  if (!ingressMessagingChannels.contains(
    _text(values, 'ChannelKey').toLowerCase(),
  )) {
    return null;
  }
  if (_text(values, 'ChannelProfileId').isEmpty) {
    return 'Select an active channel profile in this tenant for messaging ingress.';
  }
  if (!ingressClientIdentifierFields.containsKey(
    _text(values, 'IdentifierType').toLowerCase(),
  )) {
    return 'Messaging ingress requires a client path token, phone number ID, recipient user ID or account number.';
  }
  return null;
}

Future<Result<void>> validateIngressBindingOwnership({
  required AcpAdminRepository repository,
  required AcpRow values,
  required String? tenantId,
}) async {
  final fieldError = validateIngressBindingFields(values);
  if (fieldError != null) {
    return Result<void>.failure(ValidationFailure(fieldError));
  }
  final channel = _text(values, 'ChannelKey').toLowerCase();
  final profileId = _text(values, 'ChannelProfileId');
  if (profileId.isEmpty) {
    return const Result<void>.success(null);
  }
  final profileResult = await repository.fetchRow(
    descriptor: _referenceDescriptor('ChannelProfiles'),
    rowId: profileId,
    tenantId: tenantId,
  );
  if (profileResult.isFailure) {
    return Result<void>.failure(profileResult.failure!);
  }
  final profile = profileResult.data!;
  if (profile['IsActive'] != true ||
      profile['TenantId'] != tenantId ||
      _text(profile, 'ChannelKey').toLowerCase() != channel) {
    return const Result<void>.failure(
      ValidationFailure(
        'Select an active channel profile owned by this tenant and matching the binding channel.',
      ),
    );
  }
  if (!ingressMessagingChannels.contains(channel)) {
    return const Result<void>.success(null);
  }
  final clientId = _text(profile, 'ClientProfileId');
  if (clientId.isEmpty) {
    return const Result<void>.failure(
      ValidationFailure(
        'The channel profile needs an active messaging client profile in this tenant. Update the channel profile first.',
      ),
    );
  }
  final clientResult = await repository.fetchRow(
    descriptor: _referenceDescriptor('MessagingClientProfiles'),
    rowId: clientId,
    tenantId: tenantId,
  );
  if (clientResult.isFailure) {
    return Result<void>.failure(clientResult.failure!);
  }
  final client = clientResult.data!;
  if (client['IsActive'] != true ||
      client['TenantId'] != tenantId ||
      _text(client, 'PlatformKey').toLowerCase() != channel) {
    return const Result<void>.failure(
      ValidationFailure(
        'The channel profile must use an active messaging client owned by this tenant and matching the channel.',
      ),
    );
  }
  final clientField =
      ingressClientIdentifierFields[_text(
        values,
        'IdentifierType',
      ).toLowerCase()]!;
  if (_text(client, clientField).toLowerCase() !=
      _text(values, 'IdentifierValue').toLowerCase()) {
    return Result<void>.failure(
      ValidationFailure(
        'Identifier Value must match $clientField on the channel\'s messaging client profile. Check that client profile and retry.',
      ),
    );
  }
  return const Result<void>.success(null);
}

AcpResourceDescriptor _referenceDescriptor(String entitySet) =>
    AcpResourceDescriptor(
      key: 'ingress-ownership-$entitySet',
      title: entitySet,
      entitySet: entitySet,
      scopeMode: AcpScopeMode.required,
      keyLiteralType: AcpFilterLiteralType.guid,
      columns: const <AcpColumnDescriptor>[],
    );

String _text(AcpRow row, String key) => row[key]?.toString().trim() ?? '';
