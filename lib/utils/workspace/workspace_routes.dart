import 'package:fluffychat/utils/workspace/workspace_models.dart';

abstract class WorkspaceRoutes {
  static const rooms = '/rooms';
  static const backup = '/backup';
}

String postLoginRouteForWorkspace(WorkspaceConfig? workspace) {
  return workspace?.shouldForceBackupAfterLogin == false
      ? WorkspaceRoutes.rooms
      : WorkspaceRoutes.backup;
}
