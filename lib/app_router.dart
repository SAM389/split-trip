import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/auth_gate.dart';
import 'screens/trips_list_screen.dart';
import 'screens/trip_home_screen.dart';
import 'screens/add_expense_screen.dart';
import 'screens/export_screen.dart';
import 'screens/profile_screen.dart';

/// Router provider with auth state redirect
final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateStreamProvider);
  
  return GoRouter(
    initialLocation: '/login',
    observers: [
      FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
    ],
    redirect: (context, state) {
      final isLoggedIn = authState.value != null;
      final isLoggingIn = state.matchedLocation == '/login';
      
      // If user is logged in and on login page, redirect to trips
      if (isLoggedIn && isLoggingIn) {
        return '/trips';
      }
      
      // If user is not logged in and not on login page, redirect to login
      if (!isLoggedIn && !isLoggingIn) {
        return '/login';
      }
      
      // No redirect needed
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const AuthGate(),
      ),
      GoRoute(
        path: '/trips',
        builder: (context, state) => const TripsListScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/trip/:tripId',
        builder: (context, state) {
          final tripId = state.pathParameters['tripId']!;
          return TripHomeScreen(tripId: tripId);
        },
      ),
      GoRoute(
        path: '/trip/:tripId/add-expense',
        builder: (context, state) {
          final tripId = state.pathParameters['tripId']!;
          return AddExpenseScreen(tripId: tripId);
        },
      ),
      GoRoute(
        path: '/trip/:tripId/export',
        builder: (context, state) {
          final tripId = state.pathParameters['tripId']!;
          return ExportScreen(tripId: tripId);
        },
      ),
    ],
  );
});

/// Stream provider for auth state (for router redirect)
final authStateStreamProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});
