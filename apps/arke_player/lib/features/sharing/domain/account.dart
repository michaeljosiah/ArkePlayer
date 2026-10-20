/// The person signed in to their Arke account, as the Studio names them (Studio turn 151).
class ArkePerson {
  const ArkePerson({required this.name, required this.email, this.pictureUrl});

  final String name;
  final String email;
  final String? pictureUrl;
}

/// The account's state. Mirrors `AccountStateSchema` in ArkeStudio's `packages/contracts/src/account.ts`:
/// signed out (with the refusal, if a sign-in was refused), signing in while the browser has
/// the hand-off, or signed in with a session that is ok, expired or offline.
sealed class AccountState {
  const AccountState();
}

class SignedOut extends AccountState {
  const SignedOut({this.refusal});

  /// One clause, as the sheet shows it — `Arke cloud is not available yet` today.
  final String? refusal;
}

/// Sign-in is the browser's: the Player shows `waiting for the browser` and `Cancel` (P2b).
class SigningIn extends AccountState {
  const SigningIn();
}

enum SessionState { ok, expired, offline }

class SignedIn extends AccountState {
  const SignedIn(this.person, {this.session = SessionState.ok});

  final ArkePerson person;
  final SessionState session;
}

/// A world shared with this account: the publications its owner chose, under the world's name,
/// key art and logline (P2 rule 3).
class SharedWorld {
  const SharedWorld({
    required this.id,
    required this.name,
    required this.sharedBy,
    required this.productionCount,
    this.logline,
    this.keyArtUrl,
    this.ended = false,
  });

  final String id;
  final String name;
  final String sharedBy;
  final int productionCount;
  final String? logline;
  final String? keyArtUrl;

  /// The owner stopped sharing: the world stays in Library greyed with Remove, nothing in it
  /// opens, and its downloads are deleted at the next sync (P2 rule 4).
  final bool ended;
}
