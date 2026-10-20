import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/account.dart';

/// The Arke cloud: accounts, shares and streaming. It does not exist yet; the Studio's own seam
/// (`AccountService`, with `NoArkeCloud` behind it) answers that it is not available, and so does
/// this one. The real service goes in behind this interface when it arrives; everything that
/// needs no cloud — added files, the players, downloads of what is on the phone — ships first.
abstract interface class ArkeCloud {
  /// The account's state, now and as it changes.
  Stream<AccountState> get account;

  /// Hands sign-in to the system's browser (P2b). Never asks for a password in the Player.
  Future<void> signIn();

  Future<void> cancelSignIn();

  Future<void> signOut();

  /// The worlds shared with this account, ended shares included until they are removed.
  Future<List<SharedWorld>> sharedWorlds();

  /// Opens a share link (P2a): the world it names, or a one-clause refusal.
  Future<SharedWorld> openShareLink(Uri link);
}

/// The Arke cloud as it is today: not there.
class NoArkeCloud implements ArkeCloud {
  const NoArkeCloud();

  static const refusal = 'Arke cloud is not available yet';

  @override
  Stream<AccountState> get account => Stream.value(const SignedOut());

  @override
  Future<void> signIn() => Future.error(StateError(refusal));

  @override
  Future<void> cancelSignIn() async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<List<SharedWorld>> sharedWorlds() async => const [];

  @override
  Future<SharedWorld> openShareLink(Uri link) => Future.error(StateError(refusal));
}

final arkeCloudProvider = Provider<ArkeCloud>((ref) => const NoArkeCloud());
