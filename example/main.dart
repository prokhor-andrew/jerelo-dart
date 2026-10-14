import 'dart:async';

import 'package:jerelo/jerelo.dart';

// ---------------------------------------------------------------------------
// Domain models
// ---------------------------------------------------------------------------

final class UserProfile {
  final String id;
  final String name;
  final String email;

  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
  });

  UserProfile copyWith({String? name, String? email}) =>
      UserProfile(
        id: id,
        name: name ?? this.name,
        email: email ?? this.email,
      );

  @override
  String toString() =>
      'UserProfile(id: $id, name: $name, email: $email)';
}

final class AuthToken {
  final String accessToken;
  final String refreshToken;

  const AuthToken({
    required this.accessToken,
    required this.refreshToken,
  });

  @override
  String toString() =>
      'AuthToken(access: ${accessToken.substring(0, 8)}...)';
}

final class Session {
  final AuthToken token;
  final UserProfile profile;

  const Session({
    required this.token,
    required this.profile,
  });

  @override
  String toString() => 'Session(profile: $profile)';
}

// ---------------------------------------------------------------------------
// Mocked edge calls (simulating network latency with timers)
// ---------------------------------------------------------------------------

/// POST /auth/login – returns an auth token after 300ms.
Cont<void, String, AuthToken> loginRequest(
  String email,
  String password,
) {
  return Cont.fromRun((env, observer) {
    Timer(const Duration(milliseconds: 300), () {
      if (email == 'user@test.com' &&
          password == 'secret') {
        print('  [API] POST /auth/login -> 200 OK');
        observer.onThen(
          const AuthToken(
            accessToken: 'eyJhbGciOiJIUzI1NiJ9.access',
            refreshToken: 'eyJhbGciOiJIUzI1NiJ9.refresh',
          ),
        );
      } else {
        print(
          '  [API] POST /auth/login -> 401 Unauthorized',
        );
        observer.onElse('Invalid credentials');
      }
    });
    return () {};
  });
}

/// GET /users/me – returns the user profile after 200ms.
Cont<void, String, UserProfile> getUserProfile(
  String accessToken,
) {
  return Cont.fromRun((env, observer) {
    Timer(const Duration(milliseconds: 200), () {
      if (accessToken.isNotEmpty) {
        print('  [API] GET /users/me -> 200 OK');
        observer.onThen(
          const UserProfile(
            id: 'u_42',
            name: 'Alice',
            email: 'user@test.com',
          ),
        );
      } else {
        print('  [API] GET /users/me -> 403 Forbidden');
        observer.onElse('Missing token');
      }
    });
    return () {};
  });
}

/// PUT /users/me – updates the user profile after 250ms.
Cont<void, String, UserProfile> updateUserProfile(
  String accessToken,
  UserProfile updated,
) {
  return Cont.fromRun((env, observer) {
    Timer(const Duration(milliseconds: 250), () {
      print('  [API] PUT /users/me -> 200 OK');
      observer.onThen(updated);
    });
    return () {};
  });
}

/// POST /auth/logout – invalidates the session after 150ms.
Cont<void, String, void> logoutRequest(String accessToken) {
  return Cont.fromRun((env, observer) {
    Timer(const Duration(milliseconds: 150), () {
      print('  [API] POST /auth/logout -> 204 No Content');
      observer.onThen(null);
    });
    return () {};
  });
}

/// GET /users/me from a cache – immediate, but can fail.
Cont<void, String, UserProfile> getCachedProfile() {
  return Cont.fromRun((env, observer) {
    // Simulate cache miss
    print('  [CACHE] profile lookup -> miss');
    observer.onElse('Cache miss');
    return () {};
  });
}

// ---------------------------------------------------------------------------
// Composed flows using jerelo operators
// ---------------------------------------------------------------------------

/// GET /reports/latest – a slow download that takes 2s and can be
/// cancelled. Its canceller stops the timer and reports the cancellation on
/// the else channel.
Cont<void, String, String> downloadReport(
    String connection) {
  return Cont.fromRun((env, observer) {
    print('  [API] GET /reports/latest on $connection...');
    final timer = Timer(const Duration(seconds: 2), () {
      print('  [API] GET /reports/latest -> 200 OK');
      observer.onThen('report.pdf');
    });
    return () {
      timer.cancel();
      print('  [API] GET /reports/latest -> cancelled');
      observer.onElse('Download cancelled');
    };
  });
}

/// Opens a connection, downloads the report over it, and always closes the
/// connection. Uses `Cont.bracket`: a cancel reaches the download, and the
/// connection is closed once the download reports back.
Cont<void, String, String> downloadOverConnection() {
  return Cont.bracket<String, void, String, String>(
    acquire: Cont.fromRun((env, observer) {
      print('  [NET] Connection opened');
      observer.onThen('conn#1');
      return () {};
    }),
    release: (connection) => Cont.fromRun((env, observer) {
      print('  [NET] $connection closed');
      observer.onThen(());
      return () {};
    }),
    use: downloadReport,
  );
}

/// Full login flow: authenticate, then fetch the user profile, producing a
/// [Session]. Uses `thenDo` for sequential dependent operations.
Cont<void, String, Session> loginFlow(
  String email,
  String password,
) {
  return loginRequest(email, password).thenDo((token) {
    return getUserProfile(token.accessToken).thenMap((
      profile,
    ) {
      return Session(token: token, profile: profile);
    });
  });
}

/// Attempt to load the profile from cache first; if it misses, fall back to
/// the network call. Demonstrates `elseDo` for recovery.
Cont<void, String, UserProfile> loadProfileWithFallback(
  String accessToken,
) {
  return getCachedProfile().elseDo((cacheError) {
    print(
      '  [FLOW] Cache failed ($cacheError), fetching from network...',
    );
    return getUserProfile(accessToken);
  });
}

/// Fetch profile and update it in one go. Uses `Cont.both` with a quit-fast
/// policy to run fetch + validation in parallel; both must succeed.
Cont<void, String, UserProfile> fetchAndUpdateProfile(
  String accessToken, {
  required String newName,
}) {
  final fetchProfile = getUserProfile(accessToken);
  final validateName = Cont.fromRun<void, String, String>((
    env,
    observer,
  ) {
    Timer(const Duration(milliseconds: 100), () {
      if (newName.trim().isEmpty) {
        print('  [VALIDATION] name -> invalid');
        observer.onElse('Name cannot be empty');
      } else {
        print('  [VALIDATION] name -> ok');
        observer.onThen(newName.trim());
      }
    });
    return () {};
  });

  // Run fetch + validation in parallel; both must succeed.
  return Cont.both(
    fetchProfile,
    validateName,
    (profile, validatedName) =>
        profile.copyWith(name: validatedName),
    policy: OkPolicy.quitFast(),
  ).thenDo((mergedProfile) {
    return updateUserProfile(accessToken, mergedProfile);
  });
}

/// Try two different login strategies: normal credentials vs. a stored refresh
/// token. Uses `Cont.either` to race them sequentially.
Cont<void, String, AuthToken> loginWithFallbackStrategy() {
  final normalLogin = loginRequest(
    'wrong@test.com',
    'nope',
  );
  final refreshLogin =
      Cont.fromRun<void, String, AuthToken>((
    env,
    observer,
  ) {
    Timer(const Duration(milliseconds: 200), () {
      print('  [API] POST /auth/refresh -> 200 OK');
      observer.onThen(
        const AuthToken(
          accessToken: 'eyJhbGciOiJIUzI1NiJ9.refreshed',
          refreshToken: 'eyJhbGciOiJIUzI1NiJ9.refresh2',
        ),
      );
    });
    return () {};
  });

  // Try normal login first; if it fails, try refresh token.
  return Cont.either(
    normalLogin,
    refreshLogin,
    (e1, e2) => '$e1; $e2',
    policy: OkPolicy.sequence(),
  );
}

// ---------------------------------------------------------------------------
// Main – run every flow and print results
// ---------------------------------------------------------------------------

void main() {
  print('=== 1. Login flow (thenDo + thenMap) ===');
  loginFlow('user@test.com', 'secret')
      // thenMap: log the session and pass it on unchanged.
      .thenMap((session) {
    print(
      '  [LOG] Authenticated as ${session.profile.name}',
    );
    return session;
  }).run(
    null,
    onThen: (session) => print('  -> Success: $session\n'),
    onElse: (error) => print('  -> Failed: $error\n'),
  );

  print('=== 2. Profile with cache fallback (elseDo) ===');
  loadProfileWithFallback(
    'eyJhbGciOiJIUzI1NiJ9.access',
  ).run(
    null,
    onThen: (profile) => print('  -> Loaded: $profile\n'),
    onElse: (error) => print('  -> Failed: $error\n'),
  );

  print(
    '=== 3. Parallel fetch + validate, then update (Cont.both) ===',
  );
  fetchAndUpdateProfile(
    'eyJhbGciOiJIUzI1NiJ9.access',
    newName: 'Alice Wonderland',
  ).run(
    null,
    onThen: (profile) => print('  -> Updated: $profile\n'),
    onElse: (error) => print('  -> Failed: $error\n'),
  );

  print(
    '=== 4. Login with fallback strategy (Cont.either) ===',
  );
  loginWithFallbackStrategy().thenMap((token) {
    print('  [LOG] Got token via fallback: $token');
    return token;
  }).run(
    null,
    onThen: (token) => print('  -> Token: $token\n'),
    onElse: (error) =>
        print('  -> All strategies failed: $error\n'),
  );

  print(
    '=== 5. Full session lifecycle (login -> update -> logout) ===',
  );
  loginFlow('user@test.com', 'secret').thenMap((session) {
    print('  [LOG] Session started');
    return session;
  }).thenDo((session) {
    return fetchAndUpdateProfile(
      session.token.accessToken,
      newName: 'Alice Updated',
    ).thenMap((updatedProfile) {
      return Session(
        token: session.token,
        profile: updatedProfile,
      );
    });
  }).thenDo((session) {
    return logoutRequest(
      session.token.accessToken,
    ).thenMap((_) => session);
  }).thenMap((session) {
    print(
      '  [LOG] Session ended for ${session.profile.name}',
    );
    return session;
  }).run(
    null,
    onThen: (session) => print('  -> Final: $session\n'),
    onElse: (error) => print('  -> Failed: $error\n'),
  );

  print(
      '=== 6. Cancelling a download (bracket + cancel) ===');
  final token = downloadOverConnection().run(
    null,
    onThen: (report) => print('  -> Downloaded $report\n'),
    onElse: (error) => print('  -> $error\n'),
  );
  // the user gives up before the download finishes
  Timer(const Duration(milliseconds: 1500), token.cancel);
}
