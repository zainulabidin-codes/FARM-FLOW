import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/database/database_helper.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_toast.dart';
import 'core/routing/app_router.dart';
import 'features/auth/data/repositories/auth_repository.dart';
import 'features/auth/presentation/pages/auth_screen.dart';
import 'features/auth/presentation/pages/register_screen.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/cows/data/repositories/cow_repository.dart';
import 'features/cows/presentation/providers/cow_provider.dart';
import 'features/dashboard/presentation/providers/activity_log_provider.dart';
import 'features/cows/presentation/pages/cow_milk_screen.dart';
import 'features/dodi_ledger/data/repositories/dodi_repository.dart';
import 'features/dodi_ledger/presentation/providers/dodi_provider.dart';
import 'features/milk_entry/data/repositories/milk_entry_repository.dart';
import 'features/milk_entry/presentation/providers/milk_entry_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise SQLite FFI for Windows / Linux / macOS desktop.
  DatabaseHelper.initForPlatform();


  // Lock to portrait — dairy farm field use is always one-handed portrait.
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Match system UI to our light theme.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.cardWhite,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const DairyFarmApp());
}

/// Root widget for DairyFarm Pro.
///
/// [MultiProvider] at the root guarantees every provider is available
/// to all screens without requiring manual passing down the widget tree.
class DairyFarmApp extends StatelessWidget {
  const DairyFarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Auth — must be first; other providers may depend on the logged-in userId.
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(repository: AuthRepository()),
        ),

        // Dodi / Ledger
        ChangeNotifierProvider<DodiProvider>(
          create: (_) => DodiProvider(repository: DodiRepository()),
        ),

        // Cows & Breeding
        ChangeNotifierProvider<CowProvider>(
          create: (_) => CowProvider(repository: CowRepository()),
        ),

        // Milk Entry
        ChangeNotifierProvider<MilkEntryProvider>(
          create: (_) =>
              MilkEntryProvider(repository: MilkEntryRepository()),
        ),

        // Activity Log
        ChangeNotifierProvider<ActivityLogProvider>(
          create: (_) => ActivityLogProvider(),
        ),
      ],
      child: MaterialApp(
        title: 'Farm Flow',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        themeMode: ThemeMode.light,
        // Start at Auth. AppRouter handles the transition to the shell
        // once AuthProvider signals a successful login/signup.
        home: const _AuthEntry(),
        onGenerateRoute: (settings) {
          if (settings.name == '/per-cow-milk') {
            final cowId = int.tryParse(settings.arguments.toString()) ?? 0;
            return MaterialPageRoute(
              builder: (context) => CowMilkScreen(cowId: cowId),
            );
          }
          return null;
        },
      ),
    );
  }
}


/// Stateful entry point that wires [AuthProvider] to [AuthScreen].
///
/// Kept separate from [DairyFarmApp] so the [BuildContext] above the
/// [MultiProvider] is never needed for a [Provider.of] call.
class _AuthEntry extends StatefulWidget {
  const _AuthEntry();

  @override
  State<_AuthEntry> createState() => _AuthEntryState();
}

class _AuthEntryState extends State<_AuthEntry> {
  bool _showRegister = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (_showRegister) {
      return RegisterScreen(
        onSignupTap: (u, p, farm, farmer) async {
          final auth = Provider.of<AuthProvider>(context, listen: false);
          await auth.signup(u, p, farm, farmer);

          if (auth.status == AuthStatus.success &&
              auth.currentUser != null) {
            final userId = auth.currentUser!.id!;
            if (!context.mounted) return;
            await Future.wait([
              Provider.of<DodiProvider>(context, listen: false).loadDodis(userId),
              Provider.of<CowProvider>(context, listen: false).loadCows(userId),
              Provider.of<MilkEntryProvider>(context, listen: false).fetchTodaysTotalMilk(),
              Provider.of<ActivityLogProvider>(context, listen: false).loadActivities(userId),
            ]);

            if (!context.mounted) return;
            AppRouter.goToShell(context, userId: userId);
          } else if (auth.status == AuthStatus.error) {
            if (!context.mounted) return;
            AppToast.showError(context, auth.errorMessage ?? 'Sign-up failed.');
          }
        },
        onBackTap: () {
          setState(() {
            _showRegister = false;
          });
        },
      );
    }

    return AuthScreen(
      onLoginTap: (username, password) async {
        final authProvider =
            Provider.of<AuthProvider>(context, listen: false);
        await authProvider.login(username, password);

        if (authProvider.status == AuthStatus.success &&
            authProvider.currentUser != null) {
          final userId = authProvider.currentUser!.id!;

          // Pre-load all data concurrently — parallel Future.wait instead of
          // 4 sequential awaits.
          if (!context.mounted) return;
          await Future.wait([
            Provider.of<DodiProvider>(context, listen: false).loadDodis(userId),
            Provider.of<CowProvider>(context, listen: false).loadCows(userId),
            Provider.of<MilkEntryProvider>(context, listen: false).fetchTodaysTotalMilk(),
            Provider.of<ActivityLogProvider>(context, listen: false).loadActivities(userId),
          ]);

          if (!context.mounted) return;
          AppRouter.goToShell(context, userId: userId);
        } else if (authProvider.status == AuthStatus.error) {
          if (!context.mounted) return;
          AppToast.showError(context, authProvider.errorMessage ?? 'Login failed.');
        }
      },
      onSignupTap: () {
        setState(() {
          _showRegister = true;
        });
      },
    );
  }
}
