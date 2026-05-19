import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_field_help.dart';

void main() {
  test('provider help distinguishes client profiles from key refs', () {
    expect(
      acpFieldHelpText(
        key: 'Provider',
        label: 'Provider',
        entitySet: 'MessagingClientProfiles',
      ),
      contains('transport-specific metadata'),
    );
    expect(
      acpFieldHelpText(
        key: 'Provider',
        label: 'Key Provider',
        entitySet: 'KeyRefs',
        actionName: 'rotate',
      ),
      contains('Key provider used for this KeyRef rotation'),
    );
  });

  test('repeated field keys use resource-specific backend meaning', () {
    expect(
      acpFieldHelpText(
        key: 'Category',
        label: 'Category',
        entitySet: 'RuntimeConfigProfiles',
      ),
      contains('Runtime configuration category'),
    );
    expect(
      acpFieldHelpText(
        key: 'Category',
        label: 'Category',
        entitySet: 'ContextSourceBindings',
      ),
      contains('context source allow rule'),
    );
    expect(
      acpFieldHelpText(
        key: 'TargetNamespace',
        label: 'Target Namespace',
        entitySet: 'SchemaBindings',
      ),
      contains('target entity set or action'),
    );
    expect(
      acpFieldHelpText(
        key: 'TargetNamespace',
        label: 'Target Namespace',
        entitySet: 'RoutingRules',
      ),
      contains('target service'),
    );
    expect(
      acpFieldHelpText(
        key: 'ProfileKey',
        label: 'Profile Key',
        entitySet: 'RuntimeConfigProfiles',
      ),
      contains('runtime configuration category'),
    );
    expect(
      acpFieldHelpText(
        key: 'ProfileKey',
        label: 'Profile Key',
        entitySet: 'ChannelProfiles',
      ),
      contains('paired with Channel Key'),
    );
  });
}
