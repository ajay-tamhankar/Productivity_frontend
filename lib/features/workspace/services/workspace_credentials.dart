import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../workspace_account.dart';

/// The username + password the user typed on the login form, held so the
/// launcher can sign them into a sibling app without asking twice.
@immutable
class WorkspaceCredentials {
  final String username;
  final String password;

  const WorkspaceCredentials({required this.username, required this.password});

  bool get isUsable => username.isNotEmpty && password.isNotEmpty;

  /// Never let a password reach a log line, a crash report or a `print`.
  @override
  String toString() => 'WorkspaceCredentials($username, ••••••••)';
}

/// Holds the live login credentials **in memory only**.
///
/// Deliberately not written to shared-preferences, localStorage, or any
/// other durable store: a password at rest in the browser is a much worse
/// exposure than one held for the lifetime of a tab. [clear] runs on
/// logout, and a hot restart or closed tab drops it too.
///
/// ## The page-refresh problem
///
/// The auth session is persisted (prefs), but this is not — so after a
/// browser refresh the user is still signed in while the password is
/// gone. [restoreIfKnown] papers over that for the portal account
/// specifically, because its password is already a client-side constant
/// in [VistarWorkspaceAccount], so re-deriving it leaks nothing new.
///
/// That trick does **not** generalise. Once the portal is a real
/// server-side account, a refresh must either re-prompt for the password
/// or — far better — hand off a server-signed token instead of
/// credentials, at which point this class disappears entirely.
class WorkspaceCredentialsStore extends Notifier<WorkspaceCredentials?> {
  @override
  WorkspaceCredentials? build() => null;

  void set(String username, String password) {
    state = WorkspaceCredentials(username: username, password: password);
  }

  void clear() {
    state = null;
  }

  /// Re-populates credentials for the locally-known portal account after a
  /// refresh wiped memory. Returns `true` if it could. Any other account
  /// returns `false` — the caller must then re-prompt.
  bool restoreIfKnown(String username) {
    if (username.trim().toLowerCase() != VistarWorkspaceAccount.username) {
      return false;
    }
    state = WorkspaceCredentials(
      username: VistarWorkspaceAccount.username,
      password: VistarWorkspaceAccount.knownPassword,
    );
    return true;
  }
}

final workspaceCredentialsProvider =
    NotifierProvider<WorkspaceCredentialsStore, WorkspaceCredentials?>(
      WorkspaceCredentialsStore.new,
    );
