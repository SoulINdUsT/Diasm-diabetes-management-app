
import 'package:go_router/go_router.dart';

// Feature imports
import '../features/onboarding/onboarding_screen.dart';
import '../features/onboarding/profile_onboarding_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';

import '../features/root/root_shell.dart';
import '../features/home/home_screen.dart';
import '../features/home/risk_form_screen.dart';

import '../features/education/education_hub_screen.dart';
import '../features/education/education_topic_screen.dart';
import '../features/education/education_detail_screen.dart';

import '../features/monitoring/monitoring_screen.dart';
import '../features/monitoring/monitoring_log_form_screen.dart';
import '../features/monitoring/monitoring_summary_screen.dart';
import '../features/monitoring/monitoring_glucose_history_screen.dart';

import '../features/tools/tools_screen.dart';
import '../features/tools/chatbot/chatbot_screen.dart';

import '../features/tools/calc/calc_screen.dart';
import '../features/reminders/reminders_screen.dart';

//import '../features/profile/profile_screen.dart';
import 'package:diasm_front_endv2/features/profile/profile_screen.dart';

// ✅ NEW IMPORT FOR FASTING
import '../features/tools/lifestyle/fasting_main_screen.dart';


import '../features/home/daily_wellness_screen.dart';



/// Central app router for DIAsm.
final GoRouter appRouter = GoRouter(
  initialLocation: '/onboarding',
  routes: [
    // ---------- Standalone top-level screens ----------
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),

    GoRoute(
  path: '/onboarding/profile',
  builder: (context, state) => const ProfileOnboardingScreen(),
),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),

        GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),

    GoRoute(
      path: '/risk-form',
      builder: (context, state) => const RiskFormScreen(),
    ),

    // ---------- Shell with bottom navigation ----------
    ShellRoute(
      builder: (context, state, child) => RootShell(child: child),
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
  path: '/education',
  builder: (context, state) => const EducationHubScreen(),
),

        GoRoute(
          path: '/education/topics',
          builder: (context, state) {
            final categoryId =
                state.uri.queryParameters['id'] ?? 'unknown-category';
            final categoryTitle =
                state.uri.queryParameters['title'] ?? 'Topics';

            return EducationTopicScreen(
              categoryId: categoryId,
              categoryTitle: categoryTitle,
            );
          },
        ),
        GoRoute(
          path: '/education/detail',
          builder: (context, state) {
            final title = state.uri.queryParameters['title'] ?? 'Details';
            final idStr = state.uri.queryParameters['id'] ?? '0';
            final id = int.tryParse(idStr) ?? 0;

            return EducationDetailScreen(
              contentId: id,
              title: title,
            );
          },
        ),

        GoRoute(
          path: MonitoringLogFormScreen.routeName,
          builder: (context, state) => const MonitoringLogFormScreen(),
        ),
        GoRoute(
          path: MonitoringSummaryScreen.routeName,
          builder: (context, state) => const MonitoringSummaryScreen(),
        ),
        GoRoute(
          path: '/monitoring',
          builder: (context, state) => const MonitoringScreen(),
        ),
        GoRoute(
          path: MonitoringGlucoseHistoryScreen.routeName,
          builder: (context, state) {
            final isEnglish = (state.extra as bool?) ?? true;
            return MonitoringGlucoseHistoryScreen(isEnglish: isEnglish);
          },
        ),

        GoRoute(
          path: '/tools',
          builder: (context, state) => const ToolsScreen(),
        ),

        // Calc screen
        GoRoute(
          path: CalcScreen.routeName, // '/tools/calc'
          builder: (context, state) {
            final isEnglish = (state.extra as bool?) ?? true;
            return CalcScreen(isEnglish: isEnglish);
          },
        ),

                // Chatbot screen
        GoRoute(
          path: ChatbotScreen.routeName, // '/tools/chatbot'
          builder: (context, state) {
            final isEnglish = (state.extra as bool?) ?? true;
            return ChatbotScreen(isEnglish: isEnglish);
          },
        ),

GoRoute(
  path: DailyWellnessScreen.routeName,
  builder: (context, state) => const DailyWellnessScreen(),
),

        // Profile
       GoRoute(
  path: '/profile',
  name: 'profile',
  builder: (context, state) => const ProfileScreen(),
),


        // Reminders
        GoRoute(
          path: '/reminders',
          builder: (context, state) {
            final isEnglish = (state.extra as bool?) ?? true;
            return RemindersScreen(isEnglish: isEnglish);
          },
        ),

        // -------------------------------------------------------
        // ✅ NEW: Fasting Tracker Route
        // -------------------------------------------------------
        GoRoute(
          path: FastingMainScreen.routeName, // '/tools/lifestyle/fasting'
          builder: (context, state) {
            final isEnglish = (state.extra as bool?) ?? true;
            return FastingMainScreen(isEnglish: isEnglish);
          },
        ),
      ],
    ),
  ],
);
