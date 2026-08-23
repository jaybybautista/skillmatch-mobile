import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:skillmatch/core/token_storage.dart';

/// A store that never answers — what a wedged platform keystore looks like.
class _HangingStore implements TokenStore {
  @override
  Future<void> write(String token) => Completer<void>().future;

  @override
  Future<String?> read() => Completer<String?>().future;

  @override
  Future<void> delete() => Completer<void>().future;
}

class _ThrowingStore implements TokenStore {
  @override
  Future<void> write(String token) async => throw Exception('keystore refused');

  @override
  Future<String?> read() async => throw Exception('keystore refused');

  @override
  Future<void> delete() async => throw Exception('keystore refused');
}

class _WorkingStore implements TokenStore {
  String? saved;
  int writes = 0;

  @override
  Future<void> write(String token) async {
    writes++;
    saved = token;
  }

  @override
  Future<String?> read() async => saved;

  @override
  Future<void> delete() async => saved = null;
}

void main() {
  final storage = TokenStorage.instance;

  tearDown(() => storage.useStore(_WorkingStore()));

  test('a saved token is readable straight away', () async {
    final store = _WorkingStore();
    storage.useStore(store);

    await storage.saveToken('abc123');

    expect(await storage.readToken(), 'abc123');
    expect(store.saved, 'abc123', reason: 'and it reached the device');
  });

  test('saving does not wait for a store that never answers', () async {
    // The bug this guards: login succeeded on the server, then sat here
    // forever, so the session never reached the UI and nothing happened.
    storage.useStore(_HangingStore());

    await storage
        .saveToken('abc123')
        .timeout(
          const Duration(seconds: 2),
          onTimeout: () => fail('saveToken blocked on the device store'),
        );

    expect(
      await storage.readToken(),
      'abc123',
      reason:
          'the session still has its token even though the device store '
          'never answered',
    );
  });

  test('a store that refuses still leaves the session usable', () async {
    storage.useStore(_ThrowingStore());

    await storage.saveToken('abc123');
    await Future<void>.delayed(Duration.zero);

    expect(await storage.readToken(), 'abc123');
    expect(
      storage.lastPersistError,
      isNotNull,
      reason: 'the failure is recorded rather than passed over',
    );
  });

  test(
    'reading through a broken store reports no token, not an error',
    () async {
      storage.useStore(_ThrowingStore());

      expect(await storage.readToken(), isNull);
    },
  );

  test('clearing forgets the token even when the device store fails', () async {
    storage.useStore(_WorkingStore());
    await storage.saveToken('abc123');

    storage.useStore(_ThrowingStore());
    await storage.saveToken('abc123');
    await storage.clear();

    expect(await storage.readToken(), isNull);
  });
}
