import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/shared/presentation/acp_admin/acp_json_editor_field.dart';

void main() {
  test('AcpJsonEditorField rejects blank field guidance', () {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    expect(
      () => AcpJsonEditorField(
        controller: controller,
        labelText: 'Attributes',
        helpText: '',
      ),
      throwsAssertionError,
    );
  });
}
