import 'package:get/get.dart';

enum ShellKind { seeker, stayOwner, taxiDriver }

/// Mirror of AuthController.shellKind for code that must not depend on AuthController (push routing).
abstract final class ShellState {
  static final current = ShellKind.seeker.obs;

  static bool get isOwner => current.value != ShellKind.seeker;
}
