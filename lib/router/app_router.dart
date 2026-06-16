import 'package:go_router/go_router.dart';
import '../screens/home_screen.dart';
import '../screens/discover_screen.dart';
import '../screens/map_screen.dart';
import '../screens/venue_detail_screen.dart';
import '../screens/event_detail_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/auth_screen.dart';
import '../screens/otp_screen.dart';
import '../screens/venue_owner_screen.dart';
import '../screens/my_bookings_screen.dart';
import '../screens/my_reservations_screen.dart';
import '../screens/venue_application_screen.dart';
import '../widgets/main_shell.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/',
        redirect: (_, __) => '/home',
      ),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/discover',
            builder: (context, state) => const DiscoverScreen(),
          ),
          GoRoute(
            path: '/map',
            builder: (context, state) => const MapScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/venue/:id',
        builder: (context, state) => VenueDetailScreen(venueId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/event/:id',
        builder: (context, state) => EventDetailScreen(eventId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final signup = extra?['signup'] as bool? ?? false;
          return AuthScreen(initialSignUp: signup);
        },
      ),
      GoRoute(
        path: '/venue-owner',
        builder: (context, state) => const VenueOwnerScreen(),
      ),
      GoRoute(
        path: '/bookings',
        builder: (context, state) => const MyBookingsScreen(),
      ),
      GoRoute(
        path: '/reservations',
        builder: (context, state) => const MyReservationsScreen(),
      ),
      GoRoute(
        path: '/applications/new',
        builder: (context, state) => const VenueApplicationScreen(),
      ),
      GoRoute(
        path: '/verify-otp',
        builder: (context, state) {
          final email = state.extra as String? ?? '';
          return OtpScreen(email: email);
        },
      ),
    ],
  );
}
