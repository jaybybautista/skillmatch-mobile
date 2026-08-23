import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The bit of [TokenStorage] that actually touches the device, behind an
/// interface so tests can stand in for it.
abstract class TokenStore {
  Future<void> write(String token);
  Future<String?> read();
  Future<void> delete();
}

/// The real one: Android's Keystore / iOS's Keychain, via
/// flutter_secure_storage.
class SecureTokenStore implements TokenStore {
  const SecureTokenStore();

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'skillmatch_auth_token';

  @override
  Future<void> write(String token) =>
      _storage.write(key: _tokenKey, value: token);

  @override
  Future<String?> read() => _storage.read(key: _tokenKey);

  @override
  Future<void> delete() => _storage.delete(key: _tokenKey);
}

/// Holds the Sanctum bearer token for this session, and persists it across
/// app restarts.
///
/// The token is kept in memory as the source of truth for the running session,
/// and written to secure storage as a best-effort background step. That split
/// matters: the platform keystore can be slow, and on some devices it can hang
/// or throw outright. When saving the token was awaited before the session was
/// published, a keystore that never answered meant a login that had already
/// succeeded on the server never reached the UI — the app just sat there.
///
/// Losing the *persistence* costs one extra login next launch. Losing the
/// *session* costs the login you just did, which is much worse, so the two
/// are no longer tied together.
class TokenStorage {
  TokenStorage._();

  static final TokenStorage instance = TokenStorage._();

  TokenStore _store = const SecureTokenStore();

  String? _token;

  /// True once the device store has been consulted, so a null [_token] can be
  /// trusted to mean "no saved token" rather than "not looked yet".
  bool _loaded = false;

  /// Set when the last write to the device store failed, so a caller can tell
  /// the difference between "saved" and "held in memory only".
  Object? lastPersistError;

  /// Swaps in a different backing store. For tests.
  @visibleForTesting
  void useStore(TokenStore store) {
    _store = store;
    _token = null;
    _loaded = false;
    lastPersistError = null;
  }

  /// Records the token for this session and persists it in the background.
  ///
  /// Returns as soon as the token is usable, which is immediately. No timeout
  /// is needed precisely because nothing waits on the write: a keystore that
  /// never answers now costs the persistence, not the session.
  Future<void> saveToken(String token) async {
    _token = token;
    _loaded = true;
    lastPersistError = null;

    unawaited(
      _store.write(token).catchError((Object error, StackTrace _) {
        lastPersistError = error;
        // Worth saying out loud: the session works, but it won't survive
        // a restart, and that is confusing without an explanation.
        debugPrint(
          '[TokenStorage] could not persist the session token: $error',
        );
      }),
    );
  }

  /// The current token, reading the device store once if it hasn't been read.
  ///
  /// A store that fails or hangs yields null rather than throwing, which reads
  /// as "not signed in" — the same thing a missing token means.
  Future<String?> readToken() async {
    if (_loaded) return _token;

    try {
      _token = await _store.read();
    } catch (error) {
      debugPrint('[TokenStorage] could not read the saved token: $error');
      _token = null;
    }

    _loaded = true;
    return _token;
  }

  /// Forgets the token here and, best-effort, on the device.
  Future<void> clear() async {
    _token = null;
    _loaded = true;
    lastPersistError = null;

    try {
      await _store.delete();
    } catch (error) {
      debugPrint('[TokenStorage] could not clear the saved token: $error');
    }
  }
}
