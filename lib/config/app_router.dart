import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import 'constants.dart';
import '../screens/auth/login_screen.dart';
import '../screens/dashboards/student_dashboard.dart';
import '../screens/dashboards/faculty_dashboard.dart';
import '../screens/dashboards/admin_dashboard.dart';

/// Role-based routing (Application Flow §2): after a successful login the
/// matching role's dashboard opens automatically; logging out drops back
/// to the login screen. `refreshListenable: authService` means the router
/// re-evaluates `redirect` every time AuthService.notifyListeners() fires
/// (login/logout), so no manual Navigator calls are needed anywhere else.
GoRouter buildRouter(AuthService authService) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: authService,
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/student', builder: (context, state) => const StudentDashboard()),
      GoRoute(path: '/faculty', builder: (context, state) => const FacultyDashboard()),
      GoRoute(path: '/admin', builder: (context, state) => const AdminDashboard()),
    ],
    redirect: (context, state) {
      final loggedIn = authService.isLoggedIn;
      final onLoginPage = state.matchedLocation == '/login';

      if (!loggedIn) return onLoginPage ? null : '/login';

      // Logged in — send to the correct role dashboard.
      final target = switch (authService.currentUser!.role) {
        UserRole.student => '/student',
        UserRole.faculty => '/faculty',
        UserRole.admin => '/admin',
      };
      if (onLoginPage) return target;

      // Prevent a logged-in user from landing on the wrong role's route.
      if (state.matchedLocation != target) return target;
      return null;
    },
  );
}
