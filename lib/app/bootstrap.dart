import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/app/app.dart';
import 'package:mugen_ui/extension/provider_overrides.dart';

void runMugenApp() {
  runApp(ProviderScope(overrides: providerOverrides, child: const MugenApp()));
}
