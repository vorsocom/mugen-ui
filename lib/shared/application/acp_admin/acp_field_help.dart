// coverage:ignore-file

import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';

String acpFieldHelpText({
  required String key,
  required String label,
  AcpFieldKind kind = AcpFieldKind.text,
  String? resourceKey,
  String? entitySet,
  String? actionName,
}) {
  final normalizedKey = key.trim().toLowerCase();
  final normalizedLabel = label.trim().toLowerCase();
  final contextKeys = <String>[
    _contextKey(entitySet, actionName, normalizedKey),
    _contextKey(entitySet, null, normalizedKey),
    _contextKey(resourceKey, actionName, normalizedKey),
    _contextKey(resourceKey, null, normalizedKey),
  ];

  for (final contextKey in contextKeys) {
    final help = _fieldHelpByContext[contextKey];
    if (help != null) {
      return help;
    }
  }

  return _fieldHelpByKey[normalizedKey] ??
      _fieldHelpByLabel[normalizedLabel] ??
      _fallbackHelp(label: label, kind: kind);
}

String _contextKey(String? owner, String? actionName, String fieldKey) {
  final normalizedOwner = owner?.trim().toLowerCase();
  if (normalizedOwner == null || normalizedOwner.isEmpty) {
    return '';
  }

  final normalizedAction = actionName?.trim().toLowerCase();
  if (normalizedAction == null || normalizedAction.isEmpty) {
    return '$normalizedOwner::$fieldKey';
  }

  return '$normalizedOwner::$normalizedAction::$fieldKey';
}

const Map<String, String> _fieldHelpByContext = <String, String>{
  'messagingclientprofiles::provider':
      'Messaging platform provider discriminator for this client profile. This is transport-specific metadata used by adapters such as WeChat; it is not the same as a KeyRef provider. Leave it blank unless the selected platform requires a provider value.',
  'messaging-client-profiles::provider':
      'Messaging platform provider discriminator for this client profile. This is transport-specific metadata used by adapters such as WeChat; it is not the same as a KeyRef provider. Leave it blank unless the selected platform requires a provider value.',
  'messagingclientprofiles::profilekey':
      'Stable client-profile key within the selected tenant and messaging platform. Use lowercase key-style values such as "default" or "wa-global-default"; downstream channel profiles may reference this profile.',
  'messaging-client-profiles::profilekey':
      'Stable client-profile key within the selected tenant and messaging platform. Use lowercase key-style values such as "default" or "wa-global-default"; downstream channel profiles may reference this profile.',
  'runtimeconfigprofiles::category':
      'Runtime configuration category. Examples include "messaging.platform_defaults" for platform overlays and "ops_connector.defaults" for connector defaults.',
  'runtime-config-profiles::category':
      'Runtime configuration category. Examples include "messaging.platform_defaults" for platform overlays and "ops_connector.defaults" for connector defaults.',
  'runtimeconfigprofiles::profilekey':
      'Profile key within the runtime configuration category. For messaging platform defaults this is often the platform key such as "whatsapp"; for connector defaults, use a stable key such as "default".',
  'runtime-config-profiles::profilekey':
      'Profile key within the runtime configuration category. For messaging platform defaults this is often the platform key such as "whatsapp"; for connector defaults, use a stable key such as "default".',
  'keyrefs::rotate::provider':
      'Key provider used for this KeyRef rotation. Prefer "managed" for tenant-owned secrets and reserve "local" for bootstrap or emergency operator-managed keys.',
  'key-refs::rotate::provider':
      'Key provider used for this KeyRef rotation. Prefer "managed" for tenant-owned secrets and reserve "local" for bootstrap or emergency operator-managed keys.',
  'channelprofiles::profilekey':
      'Stable channel-profile key paired with Channel Key. Use a business-readable key such as "default", "support", or "wa-global-default"; changing it can break operator references and downstream configuration.',
  'channel-profiles::profilekey':
      'Stable channel-profile key paired with Channel Key. Use a business-readable key such as "default", "support", or "wa-global-default"; changing it can break operator references and downstream configuration.',
  'contextsourcebindings::category':
      'Optional source category filter emitted into the context source allow rule. Use stable category keys such as "refunds" or "policy" when context selection should narrow source material by topic.',
  'context-source-bindings::category':
      'Optional source category filter emitted into the context source allow rule. Use stable category keys such as "refunds" or "policy" when context selection should narrow source material by topic.',
  'schemabindings::targetnamespace':
      'ACP namespace that owns the target entity set or action being bound to this schema. Use the backend namespace for that resource, for example "com.vorsocomputing.mugen.acp".',
  'schema-bindings::targetnamespace':
      'ACP namespace that owns the target entity set or action being bound to this schema. Use the backend namespace for that resource, for example "com.vorsocomputing.mugen.acp".',
  'routingrules::targetnamespace':
      'Optional namespace for the target service. Use it when service keys may collide across plugins or modules.',
  'routing-rules::targetnamespace':
      'Optional namespace for the target service. Use it when service keys may collide across plugins or modules.',
  'schemas::status':
      'Schema definition lifecycle status. Use "draft" while editing, "active" when the schema version should be used, and "inactive" when retiring it without deleting audit history.',
  'deduprecords::status':
      'Idempotency ledger status. Use "in_progress" for a claimed operation, then commit actions move it to "succeeded" or "failed"; avoid editing completed records by hand.',
  'dedup-records::status':
      'Idempotency ledger status. Use "in_progress" for a claimed operation, then commit actions move it to "succeeded" or "failed"; avoid editing completed records by hand.',
  'conversationstates::status':
      'Conversation orchestration status. The backend defaults new rows to "open" and actions may set states such as "awaiting_route", "routed", "fallback", "escalated", "throttled", or "blocked".',
  'conversation-states::status':
      'Conversation orchestration status. The backend defaults new rows to "open" and actions may set states such as "awaiting_route", "routed", "fallback", "escalated", "throttled", or "blocked".',
};

const Map<String, String> _fieldHelpByLabel = <String, String>{
  'first name':
      'The user-facing given name stored on the person profile. Use the legal or business-preferred spelling where possible, for example "Ada".',
  'last name':
      'The user-facing family name stored on the person profile. Keep this aligned with identity records where possible, for example "Lovelace".',
  'username':
      'The local login name. Use a stable, unique, lowercase account identifier such as "ada.lovelace"; avoid email addresses when usernames are managed separately.',
  'email':
      'The contact and recovery email address. Use a reachable mailbox because invitations, password resets, and account notices may depend on it.',
  'password':
      'The initial password for this local account. Use a strong temporary value and require the user to rotate it through the normal account flow.',
  'new password':
      'The replacement password for the selected local account. Use a strong temporary value and communicate it through an approved secure channel.',
  'confirm new password':
      'Repeat the new password exactly to prevent accidental account lockout from a typo.',
  'slug':
      'The tenant slug used in URLs and routing-friendly identifiers. Prefer lowercase letters, numbers, and hyphens, for example "car-rentals".',
  'domain':
      'A verified tenant-owned domain used to identify tenant traffic or membership. Enter the hostname without a scheme, for example "example.com".',
  'primary domain':
      'Marks the preferred tenant domain for display and default matching. Keep only one primary domain per tenant when possible.',
  'role in tenant':
      'The tenant-scoped role assigned to the invited or selected user. Use a known tenant role such as "member" or an administrator-approved custom role.',
  'role':
      'The role receiving this permission or membership assignment. Select the narrowest role that needs the access.',
};

const Map<String, String> _fieldHelpByKey = <String, String>{
  'namespace':
      'ACP namespace that owns the role, permission object, or permission type. Use a stable reverse-DNS style namespace, for example "com.vorsocomputing.mugen.acp".',
  'name':
      'Stable human-readable identifier for this row. Use a short descriptive value that operators can recognize later, for example "default" or "weekday-support".',
  'platformkey':
      'Messaging platform key used by runtime profile resolution. Use one of the configured adapters, for example "whatsapp", "telegram", "matrix", "signal", "line", "wechat", or "web".',
  'platform':
      'Optional platform selector used to narrow profile, contributor, source, or routing behavior. Leave blank only when the row intentionally applies across platforms.',
  'profilekey':
      'Stable profile identifier within this backend resource. Prefer lowercase key-style values such as "default" or "wa-global-default"; changing it can break downstream references.',
  'displayname':
      'Operator-friendly name shown in admin lists and selectors. Use a concise description such as "WhatsApp Global Default".',
  'firstname':
      'The user-facing given name stored on the person profile. Use the legal or business-preferred spelling where possible, for example "Ada".',
  'lastname':
      'The user-facing family name stored on the person profile. Keep this aligned with identity records where possible, for example "Lovelace".',
  'username':
      'The local login name. Use a stable, unique, lowercase account identifier such as "ada.lovelace"; avoid email addresses when usernames are managed separately.',
  'email':
      'The contact and recovery email address. Use a reachable mailbox because invitations, password resets, and account notices may depend on it.',
  'password':
      'The initial password for this local account. Use a strong temporary value and require the user to rotate it through the normal account flow.',
  'newpassword':
      'The replacement password for the selected local account. Use a strong temporary value and communicate it through an approved secure channel.',
  'confirmnewpassword':
      'Repeat the new password exactly to prevent accidental account lockout from a typo.',
  'slug':
      'The tenant slug used in URLs and routing-friendly identifiers. Prefer lowercase letters, numbers, and hyphens, for example "car-rentals".',
  'domain':
      'A verified tenant-owned domain used to identify tenant traffic or membership. Enter the hostname without a scheme, for example "example.com".',
  'isprimary':
      'Marks the preferred tenant domain for display and default matching. Keep only one primary domain per tenant when possible.',
  'roleintenant':
      'The tenant-scoped role assigned to the invited or selected user. Use a known tenant role such as "member" or an administrator-approved custom role.',
  'user':
      'Local user account being added to this tenant. Search by username, name, or email and avoid adding duplicate memberships.',
  'role':
      'Role receiving the assignment. Select the narrowest role that needs the access.',
  'permissionobject':
      'Protected object type the permission applies to. Use the backend permission object for the resource being guarded, for example an ACP entity set.',
  'permissiontype':
      'Action allowed or denied on the permission object. Examples include "read", "create", "update", "delete", or a backend-defined action.',
  'permitted':
      'Whether this grant allows the role to perform the permission. Disable only when the backend uses explicit deny entries for policy overrides.',
  'isactive':
      'Controls whether the backend should consider this row during runtime resolution. Keep inactive rows for staged or retired configuration instead of deleting audit-relevant records.',
  'settings':
      'Non-secret platform settings for a messaging client profile. Store only runtime-safe JSON, for example access-mode settings; put credentials in Secret References.',
  'settingsjson':
      'Non-secret runtime configuration overlay. Use JSON objects for named settings, for example {"retry": {"max_attempts": 3}}.',
  'secretrefs':
      'JSON object mapping secret purposes to KeyRefs in the same tenant. Best practice is to reference managed KeyRefs and never paste secret material here.',
  'pathtoken':
      'Webhook path selector used by LINE, Telegram, WeChat, and WhatsApp adapters. Use a high-entropy opaque token and avoid tenant names or guessable values.',
  'recipientuserid':
      'Matrix recipient user identifier used to select a messaging client profile. Use the exact Matrix user ID expected by the adapter.',
  'accountnumber':
      'Signal account number used to select the transport account. Store only the routing identifier, not authentication material.',
  'phonenumberid':
      'WhatsApp phone number ID used by Graph API webhook and send operations. This is a routing/account identifier, not the access token.',
  'provider':
      'Provider discriminator used by the backend for this resource. Use only values documented for the specific screen; do not assume it has the same meaning as Key Provider unless the field is explicitly labeled that way.',
  'category':
      'Backend category key for this row. Use stable documented values and keep category names consistent so runtime filters and operators can find related records.',
  'purpose':
      'Secret purpose key used by runtime components, for example "graphapi_access_token", "app_secret", or "webhook_verification_token". Keep purpose names stable because profiles reference them.',
  'keyid':
      'Provider-specific key identifier within the selected purpose. Use a stable key ID that lets operators distinguish rotations, for example "default" or "2026-q2".',
  'secretvalue':
      'Secret material to rotate into the KeyRef. Paste the raw value only in the rotate action; it is write-only and should not be stored in profile JSON.',
  'reason':
      'Operational reason recorded with the action for audit review. Include the business reason, ticket number, or incident reference when available.',
  'channelkey':
      'Tenant channel identifier used by orchestration and context selection. Keep it stable and business-readable, for example "whatsapp" or "support".',
  'clientprofileid':
      'MessagingClientProfiles row used as the tenant transport account. Backend validation is same-tenant and same-platform; select an active profile whenever possible.',
  'serviceroutedefaultkey':
      'Default tenant business surface or workflow family for this channel profile. Use a stable route key such as "support" or leave blank to let downstream rules decide.',
  'routedefaultkey':
      'Legacy or compatibility default route key. Prefer Service Route Default Key for new channel profile routing unless the backend contract requires this field.',
  'policyid':
      'Optional policy row identifier that overrides default policy resolution. Leave blank to let the backend choose the active default policy for the tenant.',
  'channelprofileid':
      'ChannelProfiles row that scopes this rule or action. Select an active profile in the same tenant when the behavior is channel-specific.',
  'identifiertype':
      'Ingress identifier type emitted by the adapter. Examples: "path_token", "phone_number_id", "recipient_user_id", "account_number", or "tenant_slug".',
  'identifiervalue':
      'Ingress identifier value matched before orchestration begins. Use the exact token, phone-number ID, account number, or tenant slug received from the adapter.',
  'serviceroutekey':
      'Tenant business surface or workflow-family selector used by context and orchestration. Examples include "support", "sales", or "post-rental".',
  'bindingkey':
      'Stable contributor binding key. Use a descriptive key such as "knowledge-pack-default" and avoid changing it after downstream references exist.',
  'contributorkey':
      'Context contributor implementation key. Use the backend-registered contributor name, for example "channel_orchestration" or "audit".',
  'sourcekind':
      'Type of context source this binding allows, such as "knowledge_pack", "channel", "case", or another backend-registered source kind.',
  'sourcekey':
      'Optional source identifier within Source Kind. Leave blank to allow all sources of that kind, or set a stable key to narrow selection.',
  'locale':
      'Optional locale filter for source selection. Use BCP-47 style values such as "en" or "en-US" when content should be locale-specific.',
  'priority':
      'Lower numbers run earlier or win over lower-priority rows, depending on the resource. Leave gaps such as 10, 20, 30 to make future inserts easier.',
  'isenabled':
      'Controls whether this binding contributes to runtime resolution. Disable rows to stage or pause behavior without deleting audit history.',
  'budgetjson':
      'Context budget policy JSON. Use explicit limits such as token, item, or lane budgets so the context engine can bound selection predictably.',
  'redactionjson':
      'Context redaction policy JSON. Declare what should be removed or masked before context is rendered; keep PII rules explicit and auditable.',
  'retentionjson':
      'Context retention policy JSON. Define how long context state or artifacts can be kept; prefer explicit durations over open-ended retention.',
  'contributorallow':
      'JSON array of contributor keys allowed by this policy. Use an empty array to avoid narrowing, or list exact contributors to fail closed.',
  'contributordeny':
      'JSON array of contributor keys denied by this policy. Use this for explicit exclusions when broad allow rules would otherwise match.',
  'sourceallow':
      'JSON array of allowed source rules. Prefer structured entries using source kind/key fields rather than ad hoc metadata.',
  'sourcedeny':
      'JSON array of denied source rules. Use this to block specific source kinds or keys when contributor allow rules are broad.',
  'traceenabled':
      'Enables context trace capture for debugging and audit. Keep enabled for sensitive rollout periods; disable only when retention or volume policies require it.',
  'cacheenabled':
      'Allows the context engine to use cache entries when resolving context. Disable for rows that must always compute fresh state.',
  'persona':
      'Assistant persona instructions selected by this context profile. Keep this operational and scoped; avoid secrets and volatile runtime data.',
  'isdefault':
      'Marks this row as the default choice within its scope. Keep defaults active and avoid creating competing defaults unless the backend resolver supports clear precedence.',
  'captureprepare':
      'Captures prepare-phase context details in traces. Useful for debugging selection and budget behavior before a response is generated.',
  'capturecommit':
      'Captures commit-phase context details in traces. Useful for verifying what state or artifacts were persisted after a turn.',
  'captureselecteditems':
      'Includes selected context items in trace output. Enable when debugging ranking or source selection; consider retention impact for sensitive data.',
  'capturedroppeditems':
      'Includes dropped context items in trace output. Helpful for budget debugging, but can increase trace volume substantially.',
  'matchkind':
      'Type of intake signal to match, for example "keyword", "menu", or "intent". Keep values aligned with adapter payloads.',
  'matchvalue':
      'Value matched by the intake rule. Examples include a keyword, menu option ID, or intent name.',
  'routekey':
      'Operational route key selected by intake or routing rules. Use stable queue or workflow keys such as "support-default".',
  'targetqueuename':
      'Queue name assigned when this routing rule matches. Use a backend-known queue identifier rather than display copy.',
  'owneruserid':
      'Optional local user ID to assign as owner. Prefer queue assignment unless a specific owner is required by policy.',
  'targetservicekey':
      'Service key invoked by the routing rule. Use a backend-registered service identifier.',
  'targetnamespace':
      'Backend namespace for the target being referenced. Use stable namespace values from the target resource or service contract.',
  'code':
      'Stable code for this policy or rule. Use lowercase key-style values such as "default" or "sender-rapid-fire".',
  'hoursmode':
      'Hours policy mode. Example "always_on" keeps routing available continuously; use documented backend modes for business-hours behavior.',
  'escalationmode':
      'Escalation policy mode. Example "manual" requires explicit escalation; use documented backend modes for automatic escalation.',
  'fallbackpolicy':
      'Fallback policy name used when routing cannot resolve normally. Example "default_route" delegates to the default route.',
  'fallbacktarget':
      'Target used by fallback handling, such as a route key, queue, or service depending on fallback mode.',
  'escalationtarget':
      'Target used when escalation is triggered, such as a queue, owner, or service key.',
  'escalationafterseconds':
      'Delay before automatic escalation is considered. Enter whole seconds; for example, 900 represents 15 minutes.',
  'senderscope':
      'Throttle scope selector. Example "sender" limits by sender identity; use broader scopes only when the policy intentionally applies across senders.',
  'windowseconds':
      'Throttle measurement window in seconds. Example 60 checks activity over one minute.',
  'maxmessages':
      'Maximum messages allowed in the throttle window before a violation is recorded.',
  'blockonviolation':
      'When enabled, a throttle violation also creates or refreshes a blocklist entry.',
  'blockdurationseconds':
      'How long auto-blocking should last after a throttle violation. Leave blank for policy defaults.',
  'senderkey':
      'External sender identifier used by channel orchestration. Use the stable adapter sender key, not a display name.',
  'expiresat':
      'Expiration timestamp in ISO-8601 format. Include timezone information, for example "2026-05-19T12:00:00Z".',
  'externalconversationref':
      'External platform conversation reference. Use the stable conversation or thread ID supplied by the adapter.',
  'status':
      'Backend status value for this record. Use documented lifecycle values for the specific resource and prefer action buttons when status transitions are action-managed.',
  'assignedqueuename':
      'Queue currently assigned to this conversation. Use the backend queue identifier rather than display text.',
  'assignedowneruserid':
      'Local user ID currently assigned as owner for this conversation. Leave blank when queue ownership should drive work distribution.',
  'assignedservicekey':
      'Service key currently assigned to handle this conversation. Use a backend-registered service identifier.',
  'fallbackmode':
      'Fallback mode applied to the conversation when normal routing is unavailable. Use documented backend modes.',
  'fallbackreason':
      'Human-readable explanation for activating fallback handling. Include policy, incident, or operator context.',
  'keyword':
      'Keyword signal to use when evaluating intake rules for this conversation.',
  'menuoption':
      'Menu option signal to use when evaluating intake rules for this conversation.',
  'intent':
      'Intent signal to use when evaluating intake rules. Use the backend or NLU intent key, not display text.',
  'queuename':
      'Queue override used when routing this conversation. Leave blank to let routing rules resolve it.',
  'servicekey':
      'Service override used when routing this conversation. Leave blank to let routing rules resolve it.',
  'escalationlevel':
      'Numeric escalation level to apply. Use increasing whole numbers for higher urgency or broader visibility.',
  'incrementcount':
      'Amount to add to the throttle counter. Use 1 for a single message event unless replaying or reconciling batched activity.',
  'traceid':
      'Correlation trace ID for channel, audit, or ACP processing. Use an existing trace when linking records; otherwise use a generated opaque ID.',
  'source':
      'Origin of this work item or event, such as the channel adapter or plugin key. Keep values stable for filtering and replay.',
  'participants':
      'JSON array describing people, accounts, or endpoints participating in the work item. Prefer explicit IDs and roles over display-only text.',
  'content':
      'JSON object containing normalized message or work-item content. Keep raw payloads in evidence storage when they are large or sensitive.',
  'attachments':
      'JSON array of attachment metadata. Store references, hashes, and content types rather than embedding large binary payloads.',
  'attributes':
      'JSON extension metadata for this row. Store small, non-secret operational annotations that the backend or operators can safely inspect; keep large payloads in dedicated content fields.',
  'signals':
      'JSON array of extracted routing or classification signals such as keywords, menu choices, and intents.',
  'extractions':
      'JSON array of structured extraction results. Include provenance where possible so downstream automation can audit the source.',
  'linkedcaseid':
      'Optional case identifier linked to this work item. Use the canonical case ID from the operations system.',
  'linkedworkflowinstanceid':
      'Optional workflow instance linked to this work item. Use the canonical workflow instance ID from the workflow engine.',
  'note':
      'Operator note recorded with the action. Include concise context, ticket references, or replay rationale.',
  'includemetadata':
      'Controls whether replay includes metadata in addition to the canonical payload. Include metadata for debugging; omit it for minimal reprocessing.',
  'key':
      'Stable schema key. Use a reverse-DNS or product-scoped key where useful, for example "com.example.work_item".',
  'version':
      'Schema version number. Increment it for breaking contract changes and keep older versions available until consumers migrate.',
  'title':
      'Human-readable title for operators and schema consumers. Keep it concise and aligned with the schema key.',
  'schemakind':
      'Schema format discriminator. Use "json_schema" unless the backend documents another supported schema kind.',
  'schemajson':
      'JSON schema definition used for validation and coercion. Keep it deterministic and include required fields explicitly.',
  'activatedat':
      'Activation timestamp in ISO-8601 format. Set this when a schema version or key becomes live.',
  'activatedbyuserid':
      'Local user ID of the operator or automation that activated the schema version.',
  'checksumsha256':
      'SHA-256 checksum for the schema content. Use this to detect accidental drift between reviewed and deployed schema JSON.',
  'schemadefinitionid':
      'Schema row ID to validate, coerce, or bind. Prefer this exact ID over key/version when the caller already has it.',
  'payload':
      'JSON payload to validate or coerce against the selected schema. Use representative production-shaped data when testing schema behavior.',
  'targetentityset':
      'ACP entity set the schema binding applies to, for example "MessagingClientProfiles" or "Schemas".',
  'targetaction':
      'Optional ACP action name the schema binding applies to. Leave blank when the binding applies to create or update payloads.',
  'bindingkind':
      'Binding kind that tells the backend when to enforce this schema. Use documented values such as request or response binding kinds.',
  'isrequired':
      'Marks whether the schema binding must pass for the operation to continue. Keep required bindings active for safety-critical contracts.',
  'pluginkey':
      'Plugin key receiving capabilities. Use the backend-registered plugin key, not a display name.',
  'capabilities':
      'JSON array of capabilities granted to the plugin. Grant the smallest set needed, for example ["http.outbound"].',
  'scope':
      'Idempotency scope that partitions duplicate detection. Use a stable operation scope such as "tenant:create" or an ACP request scope.',
  'idempotencykey':
      'Client-supplied key used to make create/action requests retry-safe. Reuse it for retries of the same logical operation only.',
  'requesthash':
      'Hash of the original request payload used to detect conflicting retries under the same idempotency key.',
  'resultref':
      'Optional reference to the stored result for an idempotent operation. Use this when the full response is stored elsewhere.',
  'responsecode':
      'HTTP-like response code recorded for an idempotent operation, for example 200 for success or 500 for failure.',
  'responsepayload':
      'JSON response body recorded for an idempotent operation. Keep it compact and avoid storing secrets.',
  'errorcode':
      'Machine-readable failure code for an idempotent operation. Use stable codes that automation can match.',
  'errormessage':
      'Human-readable failure summary for an idempotent operation. Avoid secrets and include enough context for operators.',
  'ownerinstance':
      'Worker or service instance holding the idempotency lease. Use a stable process or deployment instance identifier.',
  'leaseexpiresat':
      'Timestamp when the in-progress lease expires. Use ISO-8601 with timezone so another worker can safely recover stale work.',
  'ttlseconds':
      'Time-to-live in seconds for idempotency records or committed results. Use a value long enough for expected client retry windows.',
  'leaseseconds':
      'Lease duration in seconds while a worker owns an in-progress idempotency record.',
  'batchsize':
      'Maximum rows to process in one backend action. Use moderate values to keep requests bounded and retryable.',
  'sourceplugin':
      'Plugin that produced the evidence or trace event. Use the backend plugin key so audit filters remain stable.',
  'subjectnamespace':
      'Namespace for the evidence subject. Use a stable resource namespace that identifies what the subject ID belongs to.',
  'subjectid':
      'Identifier of the subject this evidence describes, such as a case ID, work item ID, or ACP row ID.',
  'storageuri':
      'Immutable storage URI for evidence content. Store the object reference, not the content itself.',
  'contenthash':
      'Hash of the evidence content used for verification. Compute it before registration and keep it unchanged.',
  'hashalg':
      'Hash algorithm used for Content Hash. Use "sha256" unless the backend documents another accepted algorithm.',
  'contentlength':
      'Content length in bytes for the evidence blob. Use the exact object size when available.',
  'immutability':
      'Immutability policy for the evidence object. Use "immutable" for evidence that must not be overwritten.',
  'retentionuntil':
      'Timestamp until which evidence must be retained. Use ISO-8601 with timezone and align it with retention policy.',
  'redactiondueat':
      'Timestamp when evidence should be reviewed or processed for redaction. Use ISO-8601 with timezone.',
  'meta':
      'JSON metadata for the evidence blob. Store searchable context such as content type, source IDs, and provenance; avoid secrets.',
  'observedhash':
      'Hash observed during verification. It should match Content Hash when the evidence object is intact.',
  'observedhashalg':
      'Algorithm used for Observed Hash. Keep it aligned with Hash Algorithm, usually "sha256".',
  'legalholduntil':
      'Optional timestamp until which legal hold remains active. Leave blank for indefinite hold when policy allows.',
  'purgeafterdays':
      'Number of days to wait before purging tombstoned evidence. Use whole days and follow retention policy.',
  'correlationid':
      'Correlation ID used to connect related ACP or business-trace operations. Use the existing ID when investigating a request chain.',
  'requestid':
      'Request ID emitted by the API layer. Use this to inspect one exact HTTP request through audit traces.',
  'maxrows':
      'Maximum number of trace rows to return. Use small values for interactive inspection and raise only when investigating broad incidents.',
  'stage':
      'Trace stage filter, such as request, handler, validation, or persistence. Leave blank to inspect all stages.',
};

String _fallbackHelp({required String label, required AcpFieldKind kind}) {
  switch (kind) {
    case AcpFieldKind.boolean:
      return 'Controls whether "$label" is enabled for this backend operation. Prefer explicit values so runtime behavior is clear during audit review.';
    case AcpFieldKind.integer:
      return 'Whole-number value for "$label". Use documented backend limits and avoid negative values unless the backend contract explicitly allows them.';
    case AcpFieldKind.json:
      return 'JSON value for "$label". Use valid JSON, prefer objects for named settings and arrays for ordered lists, and avoid storing secrets unless this field is explicitly designed for secret material.';
    case AcpFieldKind.dateTime:
      return 'Timestamp for "$label". Use ISO-8601 with timezone, for example "2026-05-19T12:00:00Z".';
    case AcpFieldKind.multiline:
      return 'Free-text value for "$label". Keep it concise, audit-safe, and free of secrets.';
    case AcpFieldKind.text:
      return 'Backend field "$label". Use stable, documented values and avoid display-only text when downstream systems reference this value.';
  }
}
