import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/app/app.dart';
import 'package:mugen_ui/extension/app_definition.dart';

void runMugenApp() {
  runApp(
    ProviderScope(
      overrides: appDefinition.providerOverrides,
      child: const MugenApp(),
    ),
  );
}
