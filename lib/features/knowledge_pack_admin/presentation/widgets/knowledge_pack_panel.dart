import 'package:flutter/material.dart';

import 'package:mugen_ui/features/knowledge_pack_admin/presentation/providers/knowledge_pack_admin_providers.dart';
import 'package:mugen_ui/shared/presentation/acp_admin/acp_admin_panel.dart';

class KnowledgePackPanel extends StatelessWidget {
  const KnowledgePackPanel({super.key}); // coverage:ignore-line

  @override
  Widget build(BuildContext context) {
    return AcpAdminPanel<KnowledgePackAdminController>(
      controllerProvider: knowledgePackAdminControllerProvider,
      description:
          'Configure knowledge packs, versions, entries, revisions, approvals, and retrieval scopes.',
    );
  }
}
