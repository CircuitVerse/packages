// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: cascade_invocations, diagnostic_describe_all_properties

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/src/foundation/diagnostics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:go_router/src/go_route_match.dart';
import 'package:go_router/src/go_router_delegate.dart';
import 'package:go_router/src/go_router_error_page.dart';
import 'package:go_router/src/typedefs.dart';
import 'package:logging/logging.dart';

const bool enableLogs = true;
final Logger log = Logger('GoRouter tests');

void main() {
  if (enableLogs)
    Logger.root.onRecord.listen((LogRecord e) => debugPrint('$e'));

  group('path routes', () {
    testWidgets('match home route', (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
            path: '/',
            builder: (BuildContext context, GoRouterState state) =>
                const HomeScreen()),
      ];

      final GoRouter router = await _router(routes, tester);
      final List<GoRouteMatch> matches = router.routerDelegate.matches;
      expect(matches, hasLength(1));
      expect(matches.first.fullpath, '/');
      expect(router.screenFor(matches.first).runtimeType, HomeScreen);
    });

    testWidgets('If there is more than one route to match, use the first match',
        (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(path: '/', builder: _dummy),
        GoRoute(path: '/', builder: _dummy),
      ];

      final GoRouter router = await _router(routes, tester);
      router.go('/');
      final List<GoRouteMatch> matches = router.routerDelegate.matches;
      expect(matches, hasLength(1));
      expect(matches.first.fullpath, '/');
      expect(router.screenFor(matches.first).runtimeType, DummyScreen);
    });

    test('empty path', () {
      expect(() {
        GoRoute(path: '');
      }, throwsA(isAssertionError));
    });

    test('leading / on sub-route', () {
      expect(() {
        GoRoute(
          path: '/',
          builder: _dummy,
          routes: <GoRoute>[
            GoRoute(
              path: '/foo',
              builder: _dummy,
            ),
          ],
        );
      }, throwsA(isAssertionError));
    });

    test('trailing / on sub-route', () {
      expect(() {
        GoRoute(
          path: '/',
          builder: _dummy,
          routes: <GoRoute>[
            GoRoute(
              path: 'foo/',
              builder: _dummy,
            ),
          ],
        );
      }, throwsA(isAssertionError));
    });

    testWidgets('lack of leading / on top-level route',
        (WidgetTester tester) async {
      await expectLater(() async {
        final List<GoRoute> routes = <GoRoute>[
          GoRoute(path: 'foo', builder: _dummy),
        ];
        await _router(routes, tester);
      }, throwsA(isAssertionError));
    });

    testWidgets('match no routes', (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(path: '/', builder: _dummy),
      ];

      final GoRouter router = await _router(routes, tester);
      router.go('/foo');
      await tester.pumpAndSettle();
      final List<GoRouteMatch> matches = router.routerDelegate.matches;
      expect(matches, hasLength(1));
      expect(router.screenFor(matches.first).runtimeType, ErrorScreen);
    });

    testWidgets('match 2nd top level route', (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
            path: '/',
            builder: (BuildContext context, GoRouterState state) =>
                const HomeScreen()),
        GoRoute(
            path: '/login',
            builder: (BuildContext context, GoRouterState state) =>
                const LoginScreen()),
      ];

      final GoRouter router = await _router(routes, tester);
      router.go('/login');
      final List<GoRouteMatch> matches = router.routerDelegate.matches;
      expect(matches, hasLength(1));
      expect(matches.first.subloc, '/login');
      expect(router.screenFor(matches.first).runtimeType, LoginScreen);
    });

    testWidgets('match 2nd top level route with subroutes',
        (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
                path: 'page1',
                builder: (BuildContext context, GoRouterState state) =>
                    const Page1Screen())
          ],
        ),
        GoRoute(
            path: '/login',
            builder: (BuildContext context, GoRouterState state) =>
                const LoginScreen()),
      ];

      final GoRouter router = await _router(routes, tester);
      router.go('/login');
      final List<GoRouteMatch> matches = router.routerDelegate.matches;
      expect(matches, hasLength(1));
      expect(matches.first.subloc, '/login');
      expect(router.screenFor(matches.first).runtimeType, LoginScreen);
    });

    testWidgets('match top level route when location has trailing /',
        (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (BuildContext context, GoRouterState state) =>
              const LoginScreen(),
        ),
      ];

      final GoRouter router = await _router(routes, tester);
      router.go('/login/');
      final List<GoRouteMatch> matches = router.routerDelegate.matches;
      expect(matches, hasLength(1));
      expect(matches.first.subloc, '/login');
      expect(router.screenFor(matches.first).runtimeType, LoginScreen);
    });

    testWidgets('match top level route when location has trailing / (2)',
        (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(path: '/profile', redirect: (_) => '/profile/foo'),
        GoRoute(path: '/profile/:kind', builder: _dummy),
      ];

      final GoRouter router = await _router(routes, tester);
      router.go('/profile/');
      final List<GoRouteMatch> matches = router.routerDelegate.matches;
      expect(matches, hasLength(1));
      expect(matches.first.subloc, '/profile/foo');
      expect(router.screenFor(matches.first).runtimeType, DummyScreen);
    });

    testWidgets('match top level route when location has trailing / (3)',
        (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(path: '/profile', redirect: (_) => '/profile/foo'),
        GoRoute(path: '/profile/:kind', builder: _dummy),
      ];

      final GoRouter router = await _router(routes, tester);
      router.go('/profile/?bar=baz');
      final List<GoRouteMatch> matches = router.routerDelegate.matches;
      expect(matches, hasLength(1));
      expect(matches.first.subloc, '/profile/foo');
      expect(router.screenFor(matches.first).runtimeType, DummyScreen);
    });

    testWidgets('match sub-route', (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              path: 'login',
              builder: (BuildContext context, GoRouterState state) =>
                  const LoginScreen(),
            ),
          ],
        ),
      ];

      final GoRouter router = await _router(routes, tester);
      router.go('/login');
      final List<GoRouteMatch> matches = router.routerDelegate.matches;
      expect(matches.length, 2);
      expect(matches.first.subloc, '/');
      expect(router.screenFor(matches.first).runtimeType, HomeScreen);
      expect(matches[1].subloc, '/login');
      expect(router.screenFor(matches[1]).runtimeType, LoginScreen);
    });

    testWidgets('match sub-routes', (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              path: 'family/:fid',
              builder: (BuildContext context, GoRouterState state) =>
                  const FamilyScreen('dummy'),
              routes: <GoRoute>[
                GoRoute(
                  path: 'person/:pid',
                  builder: (BuildContext context, GoRouterState state) =>
                      const PersonScreen('dummy', 'dummy'),
                ),
              ],
            ),
            GoRoute(
              path: 'login',
              builder: (BuildContext context, GoRouterState state) =>
                  const LoginScreen(),
            ),
          ],
        ),
      ];

      final GoRouter router = await _router(routes, tester);
      {
        final List<GoRouteMatch> matches = router.routerDelegate.matches;
        expect(matches, hasLength(1));
        expect(matches.first.fullpath, '/');
        expect(router.screenFor(matches.first).runtimeType, HomeScreen);
      }

      router.go('/login');
      {
        final List<GoRouteMatch> matches = router.routerDelegate.matches;
        expect(matches.length, 2);
        expect(matches.first.subloc, '/');
        expect(router.screenFor(matches.first).runtimeType, HomeScreen);
        expect(matches[1].subloc, '/login');
        expect(router.screenFor(matches[1]).runtimeType, LoginScreen);
      }

      router.go('/family/f2');
      {
        final List<GoRouteMatch> matches = router.routerDelegate.matches;
        expect(matches.length, 2);
        expect(matches.first.subloc, '/');
        expect(router.screenFor(matches.first).runtimeType, HomeScreen);
        expect(matches[1].subloc, '/family/f2');
        expect(router.screenFor(matches[1]).runtimeType, FamilyScreen);
      }

      router.go('/family/f2/person/p1');
      {
        final List<GoRouteMatch> matches = router.routerDelegate.matches;
        expect(matches.length, 3);
        expect(matches.first.subloc, '/');
        expect(router.screenFor(matches.first).runtimeType, HomeScreen);
        expect(matches[1].subloc, '/family/f2');
        expect(router.screenFor(matches[1]).runtimeType, FamilyScreen);
        expect(matches[2].subloc, '/family/f2/person/p1');
        expect(router.screenFor(matches[2]).runtimeType, PersonScreen);
      }
    });

    testWidgets('return first matching route if too many subroutes',
        (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              path: 'foo/bar',
              builder: (BuildContext context, GoRouterState state) =>
                  const FamilyScreen(''),
            ),
            GoRoute(
              path: 'bar',
              builder: (BuildContext context, GoRouterState state) =>
                  const Page1Screen(),
            ),
            GoRoute(
              path: 'foo',
              builder: (BuildContext context, GoRouterState state) =>
                  const Page2Screen(),
              routes: <GoRoute>[
                GoRoute(
                  path: 'bar',
                  builder: (BuildContext context, GoRouterState state) =>
                      const LoginScreen(),
                ),
              ],
            ),
          ],
        ),
      ];

      final GoRouter router = await _router(routes, tester);
      router.go('/bar');
      List<GoRouteMatch> matches = router.routerDelegate.matches;
      expect(matches, hasLength(2));
      expect(router.screenFor(matches[1]).runtimeType, Page1Screen);

      router.go('/foo/bar');
      matches = router.routerDelegate.matches;
      expect(matches, hasLength(2));
      expect(router.screenFor(matches[1]).runtimeType, FamilyScreen);

      router.go('/foo');
      matches = router.routerDelegate.matches;
      expect(matches, hasLength(2));
      expect(router.screenFor(matches[1]).runtimeType, Page2Screen);
    });

    testWidgets('router state', (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          name: 'home',
          path: '/',
          builder: (BuildContext context, GoRouterState state) {
            expect(state.location, '/');
            expect(state.subloc, '/');
            expect(state.name, 'home');
            expect(state.path, '/');
            expect(state.fullpath, '/');
            expect(state.params, <String, String>{});
            expect(state.error, null);
            if (state.extra != null) {
              expect(state.extra! as int, 1);
            }
            return const HomeScreen();
          },
          routes: <GoRoute>[
            GoRoute(
              name: 'login',
              path: 'login',
              builder: (BuildContext context, GoRouterState state) {
                expect(state.location, '/login');
                expect(state.subloc, '/login');
                expect(state.name, 'login');
                expect(state.path, 'login');
                expect(state.fullpath, '/login');
                expect(state.params, <String, String>{});
                expect(state.error, null);
                expect(state.extra! as int, 2);
                return const LoginScreen();
              },
            ),
            GoRoute(
              name: 'family',
              path: 'family/:fid',
              builder: (BuildContext context, GoRouterState state) {
                expect(
                  state.location,
                  anyOf(<String>['/family/f2', '/family/f2/person/p1']),
                );
                expect(state.subloc, '/family/f2');
                expect(state.name, 'family');
                expect(state.path, 'family/:fid');
                expect(state.fullpath, '/family/:fid');
                expect(state.params, <String, String>{'fid': 'f2'});
                expect(state.error, null);
                expect(state.extra! as int, 3);
                return FamilyScreen(state.params['fid']!);
              },
              routes: <GoRoute>[
                GoRoute(
                  name: 'person',
                  path: 'person/:pid',
                  builder: (BuildContext context, GoRouterState state) {
                    expect(state.location, '/family/f2/person/p1');
                    expect(state.subloc, '/family/f2/person/p1');
                    expect(state.name, 'person');
                    expect(state.path, 'person/:pid');
                    expect(state.fullpath, '/family/:fid/person/:pid');
                    expect(
                      state.params,
                      <String, String>{'fid': 'f2', 'pid': 'p1'},
                    );
                    expect(state.error, null);
                    expect(state.extra! as int, 4);
                    return PersonScreen(
                        state.params['fid']!, state.params['pid']!);
                  },
                ),
              ],
            ),
          ],
        ),
      ];

      final GoRouter router = await _router(routes, tester);
      router.go('/', extra: 1);
      await tester.pump();
      router.push('/login', extra: 2);
      await tester.pump();
      router.push('/family/f2', extra: 3);
      await tester.pump();
      router.push('/family/f2/person/p1', extra: 4);
      await tester.pump();
    });

    testWidgets('match path case insensitively', (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
        ),
        GoRoute(
          path: '/family/:fid',
          builder: (BuildContext context, GoRouterState state) =>
              FamilyScreen(state.params['fid']!),
        ),
      ];

      final GoRouter router = await _router(routes, tester);
      const String loc = '/FaMiLy/f2';
      router.go(loc);
      final List<GoRouteMatch> matches = router.routerDelegate.matches;

      // NOTE: match the lower case, since subloc is canonicalized to match the
      // path case whereas the location can be any case; so long as the path
      // produces a match regardless of the location case, we win!
      expect(router.location.toLowerCase(), loc.toLowerCase());

      expect(matches, hasLength(1));
      expect(router.screenFor(matches.first).runtimeType, FamilyScreen);
    });

    testWidgets(
        'If there is more than one route to match, use the first match.',
        (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(path: '/', builder: _dummy),
        GoRoute(path: '/page1', builder: _dummy),
        GoRoute(path: '/page1', builder: _dummy),
        GoRoute(path: '/:ok', builder: _dummy),
      ];

      final GoRouter router = await _router(routes, tester);
      router.go('/user');
      final List<GoRouteMatch> matches = router.routerDelegate.matches;
      expect(matches, hasLength(1));
      expect(router.screenFor(matches.first).runtimeType, DummyScreen);
    });
  });

  group('named routes', () {
    testWidgets('match home route', (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
            name: 'home',
            path: '/',
            builder: (BuildContext context, GoRouterState state) =>
                const HomeScreen()),
      ];

      final GoRouter router = await _router(routes, tester);
      router.goNamed('home');
    });

    testWidgets('match too many routes', (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(name: 'home', path: '/', builder: _dummy),
        GoRoute(name: 'home', path: '/', builder: _dummy),
      ];

      await expectLater(() async {
        await _router(routes, tester);
      }, throwsA(isAssertionError));
    });

    test('empty name', () {
      expect(() {
        GoRoute(name: '', path: '/');
      }, throwsA(isAssertionError));
    });

    testWidgets('match no routes', (WidgetTester tester) async {
      await expectLater(() async {
        final List<GoRoute> routes = <GoRoute>[
          GoRoute(name: 'home', path: '/', builder: _dummy),
        ];
        final GoRouter router = await _router(routes, tester);
        router.goNamed('work');
      }, throwsA(isAssertionError));
    });

    testWidgets('match 2nd top level route', (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          name: 'home',
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
        ),
        GoRoute(
          name: 'login',
          path: '/login',
          builder: (BuildContext context, GoRouterState state) =>
              const LoginScreen(),
        ),
      ];

      final GoRouter router = await _router(routes, tester);
      router.goNamed('login');
    });

    testWidgets('match sub-route', (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          name: 'home',
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              name: 'login',
              path: 'login',
              builder: (BuildContext context, GoRouterState state) =>
                  const LoginScreen(),
            ),
          ],
        ),
      ];

      final GoRouter router = await _router(routes, tester);
      router.goNamed('login');
    });

    testWidgets('match w/ params', (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          name: 'home',
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              name: 'family',
              path: 'family/:fid',
              builder: (BuildContext context, GoRouterState state) =>
                  const FamilyScreen('dummy'),
              routes: <GoRoute>[
                GoRoute(
                  name: 'person',
                  path: 'person/:pid',
                  builder: (BuildContext context, GoRouterState state) {
                    expect(state.params,
                        <String, String>{'fid': 'f2', 'pid': 'p1'});
                    return const PersonScreen('dummy', 'dummy');
                  },
                ),
              ],
            ),
          ],
        ),
      ];

      final GoRouter router = await _router(routes, tester);
      router.goNamed('person',
          params: <String, String>{'fid': 'f2', 'pid': 'p1'});
    });

    testWidgets('too few params', (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          name: 'home',
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              name: 'family',
              path: 'family/:fid',
              builder: (BuildContext context, GoRouterState state) =>
                  const FamilyScreen('dummy'),
              routes: <GoRoute>[
                GoRoute(
                  name: 'person',
                  path: 'person/:pid',
                  builder: (BuildContext context, GoRouterState state) =>
                      const PersonScreen('dummy', 'dummy'),
                ),
              ],
            ),
          ],
        ),
      ];
      await expectLater(() async {
        final GoRouter router = await _router(routes, tester);
        router.goNamed('person', params: <String, String>{'fid': 'f2'});
        await tester.pump();
      }, throwsA(isAssertionError));
    });

    testWidgets('match case insensitive w/ params',
        (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          name: 'home',
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              name: 'family',
              path: 'family/:fid',
              builder: (BuildContext context, GoRouterState state) =>
                  const FamilyScreen('dummy'),
              routes: <GoRoute>[
                GoRoute(
                  name: 'PeRsOn',
                  path: 'person/:pid',
                  builder: (BuildContext context, GoRouterState state) {
                    expect(state.params,
                        <String, String>{'fid': 'f2', 'pid': 'p1'});
                    return const PersonScreen('dummy', 'dummy');
                  },
                ),
              ],
            ),
          ],
        ),
      ];

      final GoRouter router = await _router(routes, tester);
      router.goNamed('person',
          params: <String, String>{'fid': 'f2', 'pid': 'p1'});
    });

    testWidgets('too few params', (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          name: 'family',
          path: '/family/:fid',
          builder: (BuildContext context, GoRouterState state) =>
              const FamilyScreen('dummy'),
        ),
      ];
      await expectLater(() async {
        final GoRouter router = await _router(routes, tester);
        router.goNamed('family');
      }, throwsA(isAssertionError));
    });

    testWidgets('too many params', (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          name: 'family',
          path: '/family/:fid',
          builder: (BuildContext context, GoRouterState state) =>
              const FamilyScreen('dummy'),
        ),
      ];
      await expectLater(() async {
        final GoRouter router = await _router(routes, tester);
        router.goNamed('family',
            params: <String, String>{'fid': 'f2', 'pid': 'p1'});
      }, throwsA(isAssertionError));
    });

    testWidgets('sparsely named routes', (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          path: '/',
          redirect: (_) => '/family/f2',
        ),
        GoRoute(
          path: '/family/:fid',
          builder: (BuildContext context, GoRouterState state) => FamilyScreen(
            state.params['fid']!,
          ),
          routes: <GoRoute>[
            GoRoute(
              name: 'person',
              path: 'person:pid',
              builder: (BuildContext context, GoRouterState state) =>
                  PersonScreen(
                state.params['fid']!,
                state.params['pid']!,
              ),
            ),
          ],
        ),
      ];

      final GoRouter router = await _router(routes, tester);
      router.goNamed('person',
          params: <String, String>{'fid': 'f2', 'pid': 'p1'});

      final List<GoRouteMatch> matches = router.routerDelegate.matches;
      expect(router.screenFor(matches.last).runtimeType, PersonScreen);
    });

    testWidgets('preserve path param spaces and slashes',
        (WidgetTester tester) async {
      const String param1 = 'param w/ spaces and slashes';
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          name: 'page1',
          path: '/page1/:param1',
          builder: (BuildContext c, GoRouterState s) {
            expect(s.params['param1'], param1);
            return const DummyScreen();
          },
        ),
      ];

      final GoRouter router = await _router(routes, tester);
      final String loc = router
          .namedLocation('page1', params: <String, String>{'param1': param1});
      log.info('loc= $loc');
      router.go(loc);

      final List<GoRouteMatch> matches = router.routerDelegate.matches;
      log.info('param1= ${matches.first.decodedParams['param1']}');
      expect(router.screenFor(matches.first).runtimeType, DummyScreen);
      expect(matches.first.decodedParams['param1'], param1);
    });

    testWidgets('preserve query param spaces and slashes',
        (WidgetTester tester) async {
      const String param1 = 'param w/ spaces and slashes';
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          name: 'page1',
          path: '/page1',
          builder: (BuildContext c, GoRouterState s) {
            expect(s.queryParams['param1'], param1);
            return const DummyScreen();
          },
        ),
      ];

      final GoRouter router = await _router(routes, tester);
      final String loc = router.namedLocation('page1',
          queryParams: <String, String>{'param1': param1});
      router.go(loc);
      await tester.pump();
      final List<GoRouteMatch> matches = router.routerDelegate.matches;
      expect(router.screenFor(matches.first).runtimeType, DummyScreen);
      expect(matches.first.queryParams['param1'], param1);
    });
  });

  group('redirects', () {
    testWidgets('top-level redirect', (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
                path: 'dummy',
                builder: (BuildContext context, GoRouterState state) =>
                    const DummyScreen()),
            GoRoute(
                path: 'login',
                builder: (BuildContext context, GoRouterState state) =>
                    const LoginScreen()),
          ],
        ),
      ];

      final GoRouter router = await _router(routes, tester,
          redirect: (GoRouterState state) =>
              state.subloc == '/login' ? null : '/login');

      expect(router.location, '/login');
    });

    testWidgets('top-level redirect w/ named routes',
        (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          name: 'home',
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              name: 'dummy',
              path: 'dummy',
              builder: (BuildContext context, GoRouterState state) =>
                  const DummyScreen(),
            ),
            GoRoute(
              name: 'login',
              path: 'login',
              builder: (BuildContext context, GoRouterState state) =>
                  const LoginScreen(),
            ),
          ],
        ),
      ];

      final GoRouter router = await _router(
        routes,
        tester,
        redirect: (GoRouterState state) =>
            state.subloc == '/login' ? null : state.namedLocation('login'),
      );
      expect(router.location, '/login');
    });

    testWidgets('route-level redirect', (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              path: 'dummy',
              builder: (BuildContext context, GoRouterState state) =>
                  const DummyScreen(),
              redirect: (GoRouterState state) => '/login',
            ),
            GoRoute(
              path: 'login',
              builder: (BuildContext context, GoRouterState state) =>
                  const LoginScreen(),
            ),
          ],
        ),
      ];

      final GoRouter router = await _router(routes, tester);
      router.go('/dummy');
      await tester.pump();
      expect(router.location, '/login');
    });

    testWidgets('route-level redirect w/ named routes',
        (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          name: 'home',
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              name: 'dummy',
              path: 'dummy',
              builder: (BuildContext context, GoRouterState state) =>
                  const DummyScreen(),
              redirect: (GoRouterState state) => state.namedLocation('login'),
            ),
            GoRoute(
              name: 'login',
              path: 'login',
              builder: (BuildContext context, GoRouterState state) =>
                  const LoginScreen(),
            ),
          ],
        ),
      ];

      final GoRouter router = await _router(routes, tester);
      router.go('/dummy');
      await tester.pump();
      expect(router.location, '/login');
    });

    testWidgets('multiple mixed redirect', (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              path: 'dummy1',
              builder: (BuildContext context, GoRouterState state) =>
                  const DummyScreen(),
            ),
            GoRoute(
              path: 'dummy2',
              builder: (BuildContext context, GoRouterState state) =>
                  const DummyScreen(),
              redirect: (GoRouterState state) => '/',
            ),
          ],
        ),
      ];

      final GoRouter router = await _router(routes, tester,
          redirect: (GoRouterState state) =>
              state.subloc == '/dummy1' ? '/dummy2' : null);
      router.go('/dummy1');
      await tester.pump();
      expect(router.location, '/');
    });

    testWidgets('top-level redirect loop', (WidgetTester tester) async {
      final GoRouter router = await _router(<GoRoute>[], tester,
          redirect: (GoRouterState state) => state.subloc == '/'
              ? '/login'
              : state.subloc == '/login'
                  ? '/'
                  : null);

      final List<GoRouteMatch> matches = router.routerDelegate.matches;
      expect(matches, hasLength(1));
      expect(router.screenFor(matches.first).runtimeType, ErrorScreen);
      expect((router.screenFor(matches.first) as ErrorScreen).ex, isNotNull);
      log.info((router.screenFor(matches.first) as ErrorScreen).ex);
    });

    testWidgets('route-level redirect loop', (WidgetTester tester) async {
      final GoRouter router = await _router(
        <GoRoute>[
          GoRoute(
            path: '/',
            redirect: (GoRouterState state) => '/login',
          ),
          GoRoute(
            path: '/login',
            redirect: (GoRouterState state) => '/',
          ),
        ],
        tester,
      );

      final List<GoRouteMatch> matches = router.routerDelegate.matches;
      expect(matches, hasLength(1));
      expect(router.screenFor(matches.first).runtimeType, ErrorScreen);
      expect((router.screenFor(matches.first) as ErrorScreen).ex, isNotNull);
      log.info((router.screenFor(matches.first) as ErrorScreen).ex);
    });

    testWidgets('mixed redirect loop', (WidgetTester tester) async {
      final GoRouter router = await _router(
        <GoRoute>[
          GoRoute(
            path: '/login',
            redirect: (GoRouterState state) => '/',
          ),
        ],
        tester,
        redirect: (GoRouterState state) =>
            state.subloc == '/' ? '/login' : null,
      );

      final List<GoRouteMatch> matches = router.routerDelegate.matches;
      expect(matches, hasLength(1));
      expect(router.screenFor(matches.first).runtimeType, ErrorScreen);
      expect((router.screenFor(matches.first) as ErrorScreen).ex, isNotNull);
      log.info((router.screenFor(matches.first) as ErrorScreen).ex);
    });

    testWidgets('top-level redirect loop w/ query params',
        (WidgetTester tester) async {
      final GoRouter router = await _router(
        <GoRoute>[],
        tester,
        redirect: (GoRouterState state) => state.subloc == '/'
            ? '/login?from=${state.location}'
            : state.subloc == '/login'
                ? '/'
                : null,
      );

      final List<GoRouteMatch> matches = router.routerDelegate.matches;
      expect(matches, hasLength(1));
      expect(router.screenFor(matches.first).runtimeType, ErrorScreen);
      expect((router.screenFor(matches.first) as ErrorScreen).ex, isNotNull);
      log.info((router.screenFor(matches.first) as ErrorScreen).ex);
    });

    testWidgets('expect null path/fullpath on top-level redirect',
        (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
        ),
        GoRoute(
          path: '/dummy',
          redirect: (GoRouterState state) => '/',
        ),
      ];

      final GoRouter router = await _router(
        routes,
        tester,
        initialLocation: '/dummy',
      );
      expect(router.location, '/');
    });

    testWidgets('top-level redirect state', (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (BuildContext context, GoRouterState state) =>
              const LoginScreen(),
        ),
      ];

      final GoRouter router = await _router(
        routes,
        tester,
        initialLocation: '/login?from=/',
        redirect: (GoRouterState state) {
          expect(Uri.parse(state.location).queryParameters, isNotEmpty);
          expect(Uri.parse(state.subloc).queryParameters, isEmpty);
          expect(state.path, isNull);
          expect(state.fullpath, isNull);
          expect(state.params.length, 0);
          expect(state.queryParams.length, 1);
          expect(state.queryParams['from'], '/');
          return null;
        },
      );

      final List<GoRouteMatch> matches = router.routerDelegate.matches;
      expect(matches, hasLength(1));
      expect(router.screenFor(matches.first).runtimeType, LoginScreen);
    });

    testWidgets('route-level redirect state', (WidgetTester tester) async {
      const String loc = '/book/0';
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          path: '/book/:bookId',
          redirect: (GoRouterState state) {
            expect(state.location, loc);
            expect(state.subloc, loc);
            expect(state.path, '/book/:bookId');
            expect(state.fullpath, '/book/:bookId');
            expect(state.params, <String, String>{'bookId': '0'});
            expect(state.queryParams.length, 0);
            return null;
          },
          builder: (BuildContext c, GoRouterState s) => const HomeScreen(),
        ),
      ];

      final GoRouter router = await _router(
        routes,
        tester,
        initialLocation: loc,
      );

      final List<GoRouteMatch> matches = router.routerDelegate.matches;
      expect(matches, hasLength(1));
      expect(router.screenFor(matches.first).runtimeType, HomeScreen);
    });

    testWidgets('sub-sub-route-level redirect params',
        (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (BuildContext c, GoRouterState s) => const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              path: 'family/:fid',
              builder: (BuildContext c, GoRouterState s) =>
                  FamilyScreen(s.params['fid']!),
              routes: <GoRoute>[
                GoRoute(
                  path: 'person/:pid',
                  redirect: (GoRouterState s) {
                    expect(s.params['fid'], 'f2');
                    expect(s.params['pid'], 'p1');
                    return null;
                  },
                  builder: (BuildContext c, GoRouterState s) => PersonScreen(
                    s.params['fid']!,
                    s.params['pid']!,
                  ),
                ),
              ],
            ),
          ],
        ),
      ];

      final GoRouter router = await _router(
        routes,
        tester,
        initialLocation: '/family/f2/person/p1',
      );

      final List<GoRouteMatch> matches = router.routerDelegate.matches;
      expect(matches.length, 3);
      expect(router.screenFor(matches.first).runtimeType, HomeScreen);
      expect(router.screenFor(matches[1]).runtimeType, FamilyScreen);
      final PersonScreen page = router.screenFor(matches[2]) as PersonScreen;
      expect(page.fid, 'f2');
      expect(page.pid, 'p1');
    });

    testWidgets('redirect limit', (WidgetTester tester) async {
      final GoRouter router = await _router(
        <GoRoute>[],
        tester,
        redirect: (GoRouterState state) => '${state.location}+',
        redirectLimit: 10,
      );

      final List<GoRouteMatch> matches = router.routerDelegate.matches;
      expect(matches, hasLength(1));
      expect(router.screenFor(matches.first).runtimeType, ErrorScreen);
      expect((router.screenFor(matches.first) as ErrorScreen).ex, isNotNull);
      log.info((router.screenFor(matches.first) as ErrorScreen).ex);
    });
  });

  group('initial location', () {
    testWidgets('initial location', (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              path: 'dummy',
              builder: (BuildContext context, GoRouterState state) =>
                  const DummyScreen(),
            ),
          ],
        ),
      ];

      final GoRouter router = await _router(
        routes,
        tester,
        initialLocation: '/dummy',
      );
      expect(router.location, '/dummy');
    });

    testWidgets('initial location w/ redirection', (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
        ),
        GoRoute(
          path: '/dummy',
          redirect: (GoRouterState state) => '/',
        ),
      ];

      final GoRouter router = await _router(
        routes,
        tester,
        initialLocation: '/dummy',
      );
      expect(router.location, '/');
    });

    testWidgets(
        'does not take precedence over platformDispatcher.defaultRouteName',
        (WidgetTester tester) async {
      TestWidgetsFlutterBinding
          .instance.platformDispatcher.defaultRouteNameTestValue = '/dummy';

      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
          routes: <GoRoute>[
            GoRoute(
              path: 'dummy',
              builder: (BuildContext context, GoRouterState state) =>
                  const DummyScreen(),
            ),
          ],
        ),
      ];

      final GoRouter router = await _router(
        routes,
        tester,
        initialLocation: '/',
      );
      expect(router.routeInformationProvider.value.location, '/dummy');
      TestWidgetsFlutterBinding
          .instance.platformDispatcher.defaultRouteNameTestValue = '/';
    });
  });

  group('params', () {
    testWidgets('preserve path param case', (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
        ),
        GoRoute(
          path: '/family/:fid',
          builder: (BuildContext context, GoRouterState state) =>
              FamilyScreen(state.params['fid']!),
        ),
      ];

      final GoRouter router = await _router(routes, tester);
      for (final String fid in <String>['f2', 'F2']) {
        final String loc = '/family/$fid';
        router.go(loc);
        final List<GoRouteMatch> matches = router.routerDelegate.matches;

        expect(router.location, loc);
        expect(matches, hasLength(1));
        expect(router.screenFor(matches.first).runtimeType, FamilyScreen);
        expect(matches.first.decodedParams['fid'], fid);
      }
    });

    testWidgets('preserve query param case', (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
        ),
        GoRoute(
          path: '/family',
          builder: (BuildContext context, GoRouterState state) => FamilyScreen(
            state.queryParams['fid']!,
          ),
        ),
      ];

      final GoRouter router = await _router(routes, tester);
      for (final String fid in <String>['f2', 'F2']) {
        final String loc = '/family?fid=$fid';
        router.go(loc);
        final List<GoRouteMatch> matches = router.routerDelegate.matches;

        expect(router.location, loc);
        expect(matches, hasLength(1));
        expect(router.screenFor(matches.first).runtimeType, FamilyScreen);
        expect(matches.first.queryParams['fid'], fid);
      }
    });

    testWidgets('preserve path param spaces and slashes',
        (WidgetTester tester) async {
      const String param1 = 'param w/ spaces and slashes';
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          path: '/page1/:param1',
          builder: (BuildContext c, GoRouterState s) {
            expect(s.params['param1'], param1);
            return const DummyScreen();
          },
        ),
      ];

      final GoRouter router = await _router(routes, tester);
      final String loc = '/page1/${Uri.encodeComponent(param1)}';
      router.go(loc);

      final List<GoRouteMatch> matches = router.routerDelegate.matches;
      log.info('param1= ${matches.first.decodedParams['param1']}');
      expect(router.screenFor(matches.first).runtimeType, DummyScreen);
      expect(matches.first.decodedParams['param1'], param1);
    });

    testWidgets('preserve query param spaces and slashes',
        (WidgetTester tester) async {
      const String param1 = 'param w/ spaces and slashes';
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          path: '/page1',
          builder: (BuildContext c, GoRouterState s) {
            expect(s.queryParams['param1'], param1);
            return const DummyScreen();
          },
        ),
      ];

      final GoRouter router = await _router(routes, tester);
      router.go('/page1?param1=$param1');

      final List<GoRouteMatch> matches = router.routerDelegate.matches;
      expect(router.screenFor(matches.first).runtimeType, DummyScreen);
      expect(matches.first.queryParams['param1'], param1);

      final String loc = '/page1?param1=${Uri.encodeQueryComponent(param1)}';
      router.go(loc);

      final List<GoRouteMatch> matches2 = router.routerDelegate.matches;
      expect(router.screenFor(matches2[0]).runtimeType, DummyScreen);
      expect(matches2[0].queryParams['param1'], param1);
    });

    test('error: duplicate path param', () {
      try {
        GoRouter(
          routes: <GoRoute>[
            GoRoute(
              path: '/:id/:blah/:bam/:id/:blah',
              builder: _dummy,
            ),
          ],
          errorBuilder: (BuildContext context, GoRouterState state) =>
              ErrorScreen(state.error!),
          initialLocation: '/0/1/2/0/1',
        );
        expect(false, true);
      } on Exception catch (ex) {
        log.info(ex);
      }
    });

    testWidgets('duplicate query param', (WidgetTester tester) async {
      final GoRouter router = await _router(
        <GoRoute>[
          GoRoute(
            path: '/',
            builder: (BuildContext context, GoRouterState state) {
              log.info('id= ${state.params['id']}');
              expect(state.params.length, 0);
              expect(state.queryParams.length, 1);
              expect(state.queryParams['id'], anyOf('0', '1'));
              return const HomeScreen();
            },
          ),
        ],
        tester,
        initialLocation: '/?id=0&id=1',
      );
      final List<GoRouteMatch> matches = router.routerDelegate.matches;
      expect(matches, hasLength(1));
      expect(matches.first.fullpath, '/');
      expect(router.screenFor(matches.first).runtimeType, HomeScreen);
    });

    testWidgets('duplicate path + query param', (WidgetTester tester) async {
      final GoRouter router = await _router(
        <GoRoute>[
          GoRoute(
            path: '/:id',
            builder: (BuildContext context, GoRouterState state) {
              expect(state.params, <String, String>{'id': '0'});
              expect(state.queryParams, <String, String>{'id': '1'});
              return const HomeScreen();
            },
          ),
        ],
        tester,
      );

      router.go('/0?id=1');
      await tester.pump();
      final List<GoRouteMatch> matches = router.routerDelegate.matches;
      expect(matches, hasLength(1));
      expect(matches.first.fullpath, '/:id');
      expect(router.screenFor(matches.first).runtimeType, HomeScreen);
    });

    testWidgets('push + query param', (WidgetTester tester) async {
      final GoRouter router = await _router(
        <GoRoute>[
          GoRoute(path: '/', builder: _dummy),
          GoRoute(
            path: '/family',
            builder: (BuildContext context, GoRouterState state) =>
                FamilyScreen(
              state.queryParams['fid']!,
            ),
          ),
          GoRoute(
            path: '/person',
            builder: (BuildContext context, GoRouterState state) =>
                PersonScreen(
              state.queryParams['fid']!,
              state.queryParams['pid']!,
            ),
          ),
        ],
        tester,
      );

      router.go('/family?fid=f2');
      await tester.pump();
      router.push('/person?fid=f2&pid=p1');
      await tester.pump();
      final FamilyScreen page1 =
          router.screenFor(router.routerDelegate.matches.first) as FamilyScreen;
      expect(page1.fid, 'f2');

      final PersonScreen page2 =
          router.screenFor(router.routerDelegate.matches[1]) as PersonScreen;
      expect(page2.fid, 'f2');
      expect(page2.pid, 'p1');
    });

    testWidgets('push + extra param', (WidgetTester tester) async {
      final GoRouter router = await _router(
        <GoRoute>[
          GoRoute(path: '/', builder: _dummy),
          GoRoute(
            path: '/family',
            builder: (BuildContext context, GoRouterState state) =>
                FamilyScreen(
              (state.extra! as Map<String, String>)['fid']!,
            ),
          ),
          GoRoute(
            path: '/person',
            builder: (BuildContext context, GoRouterState state) =>
                PersonScreen(
              (state.extra! as Map<String, String>)['fid']!,
              (state.extra! as Map<String, String>)['pid']!,
            ),
          ),
        ],
        tester,
      );

      router.go('/family', extra: <String, String>{'fid': 'f2'});
      await tester.pump();
      router.push('/person', extra: <String, String>{'fid': 'f2', 'pid': 'p1'});
      await tester.pump();
      final FamilyScreen page1 =
          router.screenFor(router.routerDelegate.matches.first) as FamilyScreen;
      expect(page1.fid, 'f2');

      final PersonScreen page2 =
          router.screenFor(router.routerDelegate.matches[1]) as PersonScreen;
      expect(page2.fid, 'f2');
      expect(page2.pid, 'p1');
    });

    testWidgets('keep param in nested route', (WidgetTester tester) async {
      final List<GoRoute> routes = <GoRoute>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
        ),
        GoRoute(
          path: '/family/:fid',
          builder: (BuildContext context, GoRouterState state) =>
              FamilyScreen(state.params['fid']!),
          routes: <GoRoute>[
            GoRoute(
              path: 'person/:pid',
              builder: (BuildContext context, GoRouterState state) {
                final String fid = state.params['fid']!;
                final String pid = state.params['pid']!;

                return PersonScreen(fid, pid);
              },
            ),
          ],
        ),
      ];

      final GoRouter router = await _router(routes, tester);
      const String fid = 'f1';
      const String pid = 'p2';
      const String loc = '/family/$fid/person/$pid';

      router.push(loc);
      await tester.pump();
      final List<GoRouteMatch> matches = router.routerDelegate.matches;

      expect(router.location, loc);
      expect(matches, hasLength(2));
      expect(router.screenFor(matches.last).runtimeType, PersonScreen);
      expect(matches.last.decodedParams['fid'], fid);
      expect(matches.last.decodedParams['pid'], pid);
    });
  });

  group('refresh listenable', () {
    late StreamController<int> streamController;

    setUpAll(() async {
      streamController = StreamController<int>.broadcast();
      await streamController.addStream(Stream<int>.value(0));
    });

    tearDownAll(() {
      streamController.close();
    });

    group('stream', () {
      test('no stream emits', () async {
        // Act
        final GoRouterRefreshStreamSpy notifyListener =
            GoRouterRefreshStreamSpy(
          streamController.stream,
        );

        // Assert
        expect(notifyListener.notifyCount, equals(1));

        // Cleanup
        notifyListener.dispose();
      });

      test('three stream emits', () async {
        // Arrange
        final List<int> toEmit = <int>[1, 2, 3];

        // Act
        final GoRouterRefreshStreamSpy notifyListener =
            GoRouterRefreshStreamSpy(
          streamController.stream,
        );

        await streamController.addStream(Stream<int>.fromIterable(toEmit));

        // Assert
        expect(notifyListener.notifyCount, equals(toEmit.length + 1));

        // Cleanup
        notifyListener.dispose();
      });
    });
  });

  group('GoRouterHelper extensions', () {
    final GlobalKey<_DummyStatefulWidgetState> key =
        GlobalKey<_DummyStatefulWidgetState>();
    final List<GoRoute> routes = <GoRoute>[
      GoRoute(
        path: '/',
        name: 'home',
        builder: (BuildContext context, GoRouterState state) =>
            DummyStatefulWidget(key: key),
      ),
      GoRoute(
        path: '/page1',
        name: 'page1',
        builder: (BuildContext context, GoRouterState state) =>
            const Page1Screen(),
      ),
    ];

    const String name = 'page1';
    final Map<String, String> params = <String, String>{
      'a-param-key': 'a-param-value',
    };
    final Map<String, String> queryParams = <String, String>{
      'a-query-key': 'a-query-value',
    };
    const String location = '/page1';
    const String extra = 'Hello';

    testWidgets('calls [namedLocation] on closest GoRouter',
        (WidgetTester tester) async {
      final GoRouterNamedLocationSpy router =
          GoRouterNamedLocationSpy(routes: routes);
      await tester.pumpWidget(
        MaterialApp.router(
          routeInformationProvider: router.routeInformationProvider,
          routeInformationParser: router.routeInformationParser,
          routerDelegate: router.routerDelegate,
          title: 'GoRouter Example',
        ),
      );
      key.currentContext!.namedLocation(
        name,
        params: params,
        queryParams: queryParams,
      );
      expect(router.name, name);
      expect(router.params, params);
      expect(router.queryParams, queryParams);
    });

    testWidgets('calls [go] on closest GoRouter', (WidgetTester tester) async {
      final GoRouterGoSpy router = GoRouterGoSpy(routes: routes);
      await tester.pumpWidget(
        MaterialApp.router(
          routeInformationProvider: router.routeInformationProvider,
          routeInformationParser: router.routeInformationParser,
          routerDelegate: router.routerDelegate,
          title: 'GoRouter Example',
        ),
      );
      key.currentContext!.go(
        location,
        extra: extra,
      );
      expect(router.myLocation, location);
      expect(router.extra, extra);
    });

    testWidgets('calls [goNamed] on closest GoRouter',
        (WidgetTester tester) async {
      final GoRouterGoNamedSpy router = GoRouterGoNamedSpy(routes: routes);
      await tester.pumpWidget(
        MaterialApp.router(
          routeInformationProvider: router.routeInformationProvider,
          routeInformationParser: router.routeInformationParser,
          routerDelegate: router.routerDelegate,
          title: 'GoRouter Example',
        ),
      );
      key.currentContext!.goNamed(
        name,
        params: params,
        queryParams: queryParams,
        extra: extra,
      );
      expect(router.name, name);
      expect(router.params, params);
      expect(router.queryParams, queryParams);
      expect(router.extra, extra);
    });

    testWidgets('calls [push] on closest GoRouter',
        (WidgetTester tester) async {
      final GoRouterPushSpy router = GoRouterPushSpy(routes: routes);
      await tester.pumpWidget(
        MaterialApp.router(
          routeInformationProvider: router.routeInformationProvider,
          routeInformationParser: router.routeInformationParser,
          routerDelegate: router.routerDelegate,
          title: 'GoRouter Example',
        ),
      );
      key.currentContext!.push(
        location,
        extra: extra,
      );
      expect(router.myLocation, location);
      expect(router.extra, extra);
    });

    testWidgets('calls [pushNamed] on closest GoRouter',
        (WidgetTester tester) async {
      final GoRouterPushNamedSpy router = GoRouterPushNamedSpy(routes: routes);
      await tester.pumpWidget(
        MaterialApp.router(
          routeInformationProvider: router.routeInformationProvider,
          routeInformationParser: router.routeInformationParser,
          routerDelegate: router.routerDelegate,
          title: 'GoRouter Example',
        ),
      );
      key.currentContext!.pushNamed(
        name,
        params: params,
        queryParams: queryParams,
        extra: extra,
      );
      expect(router.name, name);
      expect(router.params, params);
      expect(router.queryParams, queryParams);
      expect(router.extra, extra);
    });

    testWidgets('calls [pop] on closest GoRouter', (WidgetTester tester) async {
      final GoRouterPopSpy router = GoRouterPopSpy(routes: routes);
      await tester.pumpWidget(
        MaterialApp.router(
          routeInformationProvider: router.routeInformationProvider,
          routeInformationParser: router.routeInformationParser,
          routerDelegate: router.routerDelegate,
          title: 'GoRouter Example',
        ),
      );
      key.currentContext!.pop();
      expect(router.popped, true);
    });
  });

  testWidgets('pop triggers pop on routerDelegate',
      (WidgetTester tester) async {
    final GoRouter router = await createGoRouter(tester)
      ..push('/error');
    router.routerDelegate.addListener(expectAsync0(() {}));
    router.pop();
    await tester.pump();
  });

  testWidgets('didPush notifies listeners', (WidgetTester tester) async {
    await createGoRouter(tester)
      ..addListener(expectAsync0(() {}))
      ..didPush(
        MaterialPageRoute<void>(builder: (_) => const Text('Current route')),
        MaterialPageRoute<void>(builder: (_) => const Text('Previous route')),
      );
  });

  testWidgets('didPop notifies listeners', (WidgetTester tester) async {
    await createGoRouter(tester)
      ..addListener(expectAsync0(() {}))
      ..didPop(
        MaterialPageRoute<void>(builder: (_) => const Text('Current route')),
        MaterialPageRoute<void>(builder: (_) => const Text('Previous route')),
      );
  });

  testWidgets('didRemove notifies listeners', (WidgetTester tester) async {
    await createGoRouter(tester)
      ..addListener(expectAsync0(() {}))
      ..didRemove(
        MaterialPageRoute<void>(builder: (_) => const Text('Current route')),
        MaterialPageRoute<void>(builder: (_) => const Text('Previous route')),
      );
  });

  testWidgets('didReplace notifies listeners', (WidgetTester tester) async {
    await createGoRouter(tester)
      ..addListener(expectAsync0(() {}))
      ..didReplace(
        newRoute: MaterialPageRoute<void>(
          builder: (_) => const Text('Current route'),
        ),
        oldRoute: MaterialPageRoute<void>(
          builder: (_) => const Text('Previous route'),
        ),
      );
  });

  testWidgets('uses navigatorBuilder when provided',
      (WidgetTester tester) async {
    final Func3<Widget, BuildContext, GoRouterState, Widget> navigatorBuilder =
        expectAsync3(fakeNavigationBuilder);
    final GoRouter router = GoRouter(
      initialLocation: '/',
      routes: <GoRoute>[
        GoRoute(path: '/', builder: (_, __) => const DummyStatefulWidget()),
        GoRoute(
          path: '/error',
          builder: (_, __) => const GoRouterErrorScreen(null),
        ),
      ],
      navigatorBuilder: navigatorBuilder,
    );

    final GoRouterDelegate delegate = router.routerDelegate;
    delegate.builderWithNav(
      DummyBuildContext(),
      GoRouterState(router.routeInformationParser,
          location: '/foo', subloc: '/bar', name: 'baz'),
      const Navigator(),
    );
  });
}

Future<GoRouter> createGoRouter(
  WidgetTester tester, {
  GoRouterNavigatorBuilder? navigatorBuilder,
}) async {
  final GoRouter goRouter = GoRouter(
    initialLocation: '/',
    routes: <GoRoute>[
      GoRoute(path: '/', builder: (_, __) => const DummyStatefulWidget()),
      GoRoute(
        path: '/error',
        builder: (_, __) => const GoRouterErrorScreen(null),
      ),
    ],
    navigatorBuilder: navigatorBuilder,
  );
  await tester.pumpWidget(MaterialApp.router(
      routeInformationProvider: goRouter.routeInformationProvider,
      routeInformationParser: goRouter.routeInformationParser,
      routerDelegate: goRouter.routerDelegate));
  return goRouter;
}

Widget fakeNavigationBuilder(
  BuildContext context,
  GoRouterState state,
  Widget child,
) =>
    child;

class GoRouterNamedLocationSpy extends GoRouter {
  GoRouterNamedLocationSpy({required List<GoRoute> routes})
      : super(routes: routes);

  String? name;
  Map<String, String>? params;
  Map<String, String>? queryParams;

  @override
  String namedLocation(
    String name, {
    Map<String, String> params = const <String, String>{},
    Map<String, String> queryParams = const <String, String>{},
  }) {
    this.name = name;
    this.params = params;
    this.queryParams = queryParams;
    return '';
  }
}

class GoRouterGoSpy extends GoRouter {
  GoRouterGoSpy({required List<GoRoute> routes}) : super(routes: routes);

  String? myLocation;
  Object? extra;

  @override
  void go(String location, {Object? extra}) {
    myLocation = location;
    this.extra = extra;
  }
}

class GoRouterGoNamedSpy extends GoRouter {
  GoRouterGoNamedSpy({required List<GoRoute> routes}) : super(routes: routes);

  String? name;
  Map<String, String>? params;
  Map<String, String>? queryParams;
  Object? extra;

  @override
  void goNamed(
    String name, {
    Map<String, String> params = const <String, String>{},
    Map<String, String> queryParams = const <String, String>{},
    Object? extra,
  }) {
    this.name = name;
    this.params = params;
    this.queryParams = queryParams;
    this.extra = extra;
  }
}

class GoRouterPushSpy extends GoRouter {
  GoRouterPushSpy({required List<GoRoute> routes}) : super(routes: routes);

  String? myLocation;
  Object? extra;

  @override
  void push(String location, {Object? extra}) {
    myLocation = location;
    this.extra = extra;
  }
}

class GoRouterPushNamedSpy extends GoRouter {
  GoRouterPushNamedSpy({required List<GoRoute> routes}) : super(routes: routes);

  String? name;
  Map<String, String>? params;
  Map<String, String>? queryParams;
  Object? extra;

  @override
  void pushNamed(
    String name, {
    Map<String, String> params = const <String, String>{},
    Map<String, String> queryParams = const <String, String>{},
    Object? extra,
  }) {
    this.name = name;
    this.params = params;
    this.queryParams = queryParams;
    this.extra = extra;
  }
}

class GoRouterPopSpy extends GoRouter {
  GoRouterPopSpy({required List<GoRoute> routes}) : super(routes: routes);

  bool popped = false;

  @override
  void pop() {
    popped = true;
  }
}

class GoRouterRefreshStreamSpy extends GoRouterRefreshStream {
  GoRouterRefreshStreamSpy(
    Stream<dynamic> stream,
  )   : notifyCount = 0,
        super(stream);

  late int notifyCount;

  @override
  void notifyListeners() {
    notifyCount++;
    super.notifyListeners();
  }
}

Future<GoRouter> _router(
  List<GoRoute> routes,
  WidgetTester tester, {
  GoRouterRedirect? redirect,
  String initialLocation = '/',
  int redirectLimit = 5,
}) async {
  final GoRouter goRouter = GoRouter(
    routes: routes,
    redirect: redirect,
    initialLocation: initialLocation,
    redirectLimit: redirectLimit,
    errorBuilder: (BuildContext context, GoRouterState state) =>
        ErrorScreen(state.error!),
    debugLogDiagnostics: false,
  );
  await tester.pumpWidget(
    MaterialApp.router(
      routeInformationProvider: goRouter.routeInformationProvider,
      routeInformationParser: goRouter.routeInformationParser,
      routerDelegate: goRouter.routerDelegate,
    ),
  );
  return goRouter;
}

class ErrorScreen extends DummyScreen {
  const ErrorScreen(this.ex, {Key? key}) : super(key: key);
  final Exception ex;
}

class HomeScreen extends DummyScreen {
  const HomeScreen({Key? key}) : super(key: key);
}

class Page1Screen extends DummyScreen {
  const Page1Screen({Key? key}) : super(key: key);
}

class Page2Screen extends DummyScreen {
  const Page2Screen({Key? key}) : super(key: key);
}

class LoginScreen extends DummyScreen {
  const LoginScreen({Key? key}) : super(key: key);
}

class FamilyScreen extends DummyScreen {
  const FamilyScreen(this.fid, {Key? key}) : super(key: key);
  final String fid;
}

class FamiliesScreen extends DummyScreen {
  const FamiliesScreen({required this.selectedFid, Key? key}) : super(key: key);
  final String selectedFid;
}

class PersonScreen extends DummyScreen {
  const PersonScreen(this.fid, this.pid, {Key? key}) : super(key: key);
  final String fid;
  final String pid;
}

class DummyScreen extends StatelessWidget {
  const DummyScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => const Placeholder();
}

Widget _dummy(BuildContext context, GoRouterState state) => const DummyScreen();

extension on GoRouter {
  Page<dynamic> _pageFor(GoRouteMatch match) {
    final List<GoRouteMatch> matches = routerDelegate.matches;
    final int i = matches.indexOf(match);
    final List<Page<dynamic>> pages =
        routerDelegate.getPages(DummyBuildContext(), matches).toList();
    return pages[i];
  }

  Widget screenFor(GoRouteMatch match) =>
      (_pageFor(match) as MaterialPage<void>).child;
}

class DummyBuildContext implements BuildContext {
  @override
  bool get debugDoingBuild => throw UnimplementedError();

  @override
  InheritedWidget dependOnInheritedElement(InheritedElement ancestor,
      {Object aspect = 1}) {
    throw UnimplementedError();
  }

  @override
  T? dependOnInheritedWidgetOfExactType<T extends InheritedWidget>(
      {Object? aspect}) {
    throw UnimplementedError();
  }

  @override
  DiagnosticsNode describeElement(String name,
      {DiagnosticsTreeStyle style = DiagnosticsTreeStyle.errorProperty}) {
    throw UnimplementedError();
  }

  @override
  List<DiagnosticsNode> describeMissingAncestor(
      {required Type expectedAncestorType}) {
    throw UnimplementedError();
  }

  @override
  DiagnosticsNode describeOwnershipChain(String name) {
    throw UnimplementedError();
  }

  @override
  DiagnosticsNode describeWidget(String name,
      {DiagnosticsTreeStyle style = DiagnosticsTreeStyle.errorProperty}) {
    throw UnimplementedError();
  }

  // @override
  // TODO(dit): Remove ignore below when flutter 2.11.0-0.0.pre.724 becomes stable
  // ignore:annotate_overrides
  void dispatchNotification(Notification notification) {
    throw UnimplementedError();
  }

  @override
  T? findAncestorRenderObjectOfType<T extends RenderObject>() {
    throw UnimplementedError();
  }

  @override
  T? findAncestorStateOfType<T extends State<StatefulWidget>>() {
    throw UnimplementedError();
  }

  @override
  T? findAncestorWidgetOfExactType<T extends Widget>() {
    throw UnimplementedError();
  }

  @override
  RenderObject? findRenderObject() {
    throw UnimplementedError();
  }

  @override
  T? findRootAncestorStateOfType<T extends State<StatefulWidget>>() {
    throw UnimplementedError();
  }

  @override
  InheritedElement?
      getElementForInheritedWidgetOfExactType<T extends InheritedWidget>() {
    throw UnimplementedError();
  }

  @override
  BuildOwner? get owner => throw UnimplementedError();

  @override
  Size? get size => throw UnimplementedError();

  @override
  void visitAncestorElements(bool Function(Element element) visitor) {}

  @override
  void visitChildElements(ElementVisitor visitor) {}

  @override
  Widget get widget => throw UnimplementedError();
}

class DummyStatefulWidget extends StatefulWidget {
  const DummyStatefulWidget({Key? key}) : super(key: key);

  @override
  State<DummyStatefulWidget> createState() => _DummyStatefulWidgetState();
}

class _DummyStatefulWidgetState extends State<DummyStatefulWidget> {
  @override
  Widget build(BuildContext context) => Container();
}
