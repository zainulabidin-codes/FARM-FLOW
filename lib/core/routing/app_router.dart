import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/auth/presentation/pages/auth_screen.dart';
import '../../features/auth/presentation/pages/register_screen.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/shell/app_shell.dart';
import '../../features/milk_entry/presentation/pages/milk_entry_screen.dart';
import '../../features/milk_entry/presentation/providers/milk_entry_provider.dart';
import '../../features/milk_entry/data/models/ledger_entry_model.dart';
import '../../features/dodi_ledger/presentation/providers/dodi_provider.dart';
import '../../features/cows/presentation/providers/cow_provider.dart';
import '../../features/cows/data/models/cow_model.dart';
import '../../features/dashboard/presentation/providers/activity_log_provider.dart';
import '../utils/app_toast.dart';
import '../../features/milk_entry/presentation/utils/conflict_resolution_dialog.dart';

// ---------------------------------------------------------------------------
// AppRouter
// ---------------------------------------------------------------------------
// Single source of truth for every programmatic navigation call.
// All methods are static — no router instance needed.
//
// Stack strategy:
//   Auth screen  ──(login)──▶  AppShell (tabs: Home / Buyers / Herd)
//                                 ▲
//                          Milk Entry (modal push, closes itself on save)
// ---------------------------------------------------------------------------

abstract final class AppRouter {
  // ── Route name constants ──────────────────────────────────────────────────
  static const String routeAuth = '/';
  static const String routeShell = '/home';
  static const String routeMilkEntry = '/milk-entry';

  // ── Public navigation methods ─────────────────────────────────────────────

  /// Centralized navigation event logger for analytics and performance tracking.
  static void logNavigation(String routeName, {Object? arguments}) {
    debugPrint('[NavigationEvent] Pushing route: $routeName with args: $arguments (timestamp: ${DateTime.now().toIso8601String()})');
  }

  /// Defensive navigation to CowMilkScreen with cowId parsing, validation, and existence checks.
  static Future<void> pushPerCowMilk(
    BuildContext context, {
    required String cowIdStr,
  }) async {
    final cowId = int.tryParse(cowIdStr);
    if (cowId == null) {
      if (context.mounted) {
        AppToast.showError(context, 'Invalid cow identifier.');
      }
      return;
    }

    final cowProvider = Provider.of<CowProvider>(context, listen: false);
    final cow = cowProvider.cows.firstWhere(
      (c) => c.id == cowId && c.isDeleted == 0,
      orElse: () => const CowModel(userId: 0, tagNumber: ''),
    );

    if (cow.userId == 0) {
      if (context.mounted) {
        AppToast.showError(context, 'Cow not found or has been deleted.');
      }
      return;
    }

    logNavigation('/per-cow-milk', arguments: {'cowId': cowId});
    if (context.mounted) {
      await Navigator.of(context).pushNamed('/per-cow-milk', arguments: cowId);
    }
  }

  /// Remove the entire navigation stack and show the Auth screen.
  static void goToAuth(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      _fade(const _AuthEntryPage()),
      (_) => false,
    );
  }

  /// Remove the stack and show the main AppShell.
  /// [userId] is the DB primary key of the logged-in farmer.
  static void goToShell(BuildContext context, {required int userId, int initialIndex = 0}) {
    Navigator.of(context).pushAndRemoveUntil(
      _fade(
        AppShell(
          userId: userId,
          initialIndex: initialIndex,
        ),
      ),
      (_) => false,
    );
  }

  /// Push the Milk Entry screen as a fullscreen modal over the shell.
  ///
  /// [dodiId] and [dodiName] are optional — if provided the entry will be
  /// pre-associated with that dodi; otherwise the user picks from a list.
  static Future<int?> pushMilkEntry(
    BuildContext context, {
    int? dodiId,
    String? dodiName,
  }) {
    return Navigator.of(context).push<int>(
      MaterialPageRoute<int>(
        fullscreenDialog: true,
        builder: (_) => MilkEntryScreen(
          initialDodiId: dodiId,
          cowLabel: dodiName ?? 'Record Milk',
          onSaveEntry: (selectedDodiId, buyerName, quantity, session, ratePaise, date, loadTag) async {
            final milkProvider = Provider.of<MilkEntryProvider>(context, listen: false);
            final authProvider = Provider.of<AuthProvider>(context, listen: false);
            final userId = authProvider.currentUser?.id;
            if (userId == null) {
              if (context.mounted) {
                authProvider.logout();
                AppRouter.goToAuth(context);
                AppToast.showError(context, 'Session expired. Please log in again.');
              }
              return;
            }

            // Conflict Check
            final existingEntry = await milkProvider.checkExistingEntry(
              dodiId: selectedDodiId,
              session: session,
              date: date,
            );

            if (existingEntry != null && context.mounted) {
              final action = await showDuplicateShiftConflictDialog(
                context: context,
                existingEntry: existingEntry,
                newQuantity: quantity,
                session: session,
              );

              if (action == null || action == ConflictResolutionAction.cancel) {
                return;
              }

              bool success = false;
              if (action == ConflictResolutionAction.saveAsSeparate) {
                success = await milkProvider.recordMilkEntry(
                  userId: userId,
                  buyerName: buyerName,
                  dodiId: selectedDodiId,
                  quantityString: quantity,
                  ratePaise: ratePaise,
                  session: session,
                  date: date,
                  loadTag: loadTag,
                );
              } else if (action == ConflictResolutionAction.replaceExisting) {
                success = await milkProvider.updateMilkEntry(
                  entryId: existingEntry.id!,
                  userId: userId,
                  buyerName: buyerName,
                  dodiId: selectedDodiId,
                  quantityString: quantity,
                  ratePaise: ratePaise,
                  session: session,
                  date: date,
                  loadTag: loadTag,
                );
              } else if (action == ConflictResolutionAction.mergeAndHarmonize) {
                final existingQtyGrams = existingEntry.quantityGrams ?? 0;
                final newQtyGrams = ((double.tryParse(quantity) ?? 0.0) * 1000).round();
                final totalQtyGrams = existingQtyGrams + newQtyGrams;
                final totalQtyString = (totalQtyGrams / 1000).toStringAsFixed(1);
                
                final existingAmountPaise = existingEntry.amountPaise;
                final newAmountPaise = ((newQtyGrams * ratePaise) / 1000).round();
                final totalAmountPaise = existingAmountPaise + newAmountPaise;
                
                final newRatePaise = totalQtyGrams > 0 ? ((totalAmountPaise * 1000) / totalQtyGrams).round() : ratePaise;

                success = await milkProvider.updateMilkEntry(
                  entryId: existingEntry.id!,
                  userId: userId,
                  buyerName: buyerName,
                  dodiId: selectedDodiId,
                  quantityString: totalQtyString,
                  ratePaise: newRatePaise,
                  session: session,
                  date: date,
                  loadTag: loadTag,
                );
              }

              if (!context.mounted) return;
              if (success) {
                Provider.of<DodiProvider>(context, listen: false).refreshDodi(selectedDodiId);
                Provider.of<ActivityLogProvider>(context, listen: false).loadActivities(userId);
              }
              Navigator.of(context).pop();
              if (success) {
                AppToast.showSuccess(context, 'Saved successfully');
              } else {
                AppToast.showError(context, milkProvider.errorMessage ?? 'Failed to save.');
              }
              return;
            }

            final success = await milkProvider.recordMilkEntry(
              userId: userId,
              buyerName: buyerName,
              dodiId: selectedDodiId,
              quantityString: quantity,
              ratePaise: ratePaise,
              session: session,
              date: date,
              loadTag: loadTag,
            );

            if (!context.mounted) return;

            if (success) {
              Provider.of<DodiProvider>(context, listen: false).refreshDodi(selectedDodiId);
              Provider.of<ActivityLogProvider>(context, listen: false).loadActivities(userId);
            }

            Navigator.of(context).pop();

            if (success) {
              AppToast.showSuccess(context, 'Saved ${quantity}L — $session session');
            } else {
              AppToast.showError(context, milkProvider.errorMessage ?? 'Failed to save.');
            }
          },
        ),
      ),
    );
  }

  /// Push the Milk Entry screen in Edit Mode.
  static Future<int?> pushEditMilkEntry(
    BuildContext context, {
    required LedgerEntryModel entry,
    required String dodiName,
  }) {
    return Navigator.of(context).push<int>(
      MaterialPageRoute<int>(
        fullscreenDialog: true,
        builder: (_) => MilkEntryScreen(
          initialDodiId: entry.dodiId,
          cowLabel: dodiName,
          initialSession: entry.session == 'EVENING' ? MilkSession.evening : MilkSession.morning,
          initialQuantity: entry.quantityGrams != null ? (entry.quantityGrams! / 1000).toStringAsFixed(1) : null,
          initialRatePaise: entry.ratePaise,
          initialDate: DateTime.parse(entry.date),
          onSaveEntry: (selectedDodiId, buyerName, quantity, session, ratePaise, date, loadTag) async {
            final milkProvider = Provider.of<MilkEntryProvider>(context, listen: false);
            final authProvider = Provider.of<AuthProvider>(context, listen: false);
            final userId = authProvider.currentUser?.id;
            if (userId == null) {
              if (context.mounted) {
                authProvider.logout();
                AppRouter.goToAuth(context);
                AppToast.showError(context, 'Session expired. Please log in again.');
              }
              return;
            }

            final success = await milkProvider.updateMilkEntry(
              entryId: entry.id!,
              userId: userId,
              buyerName: buyerName,
              dodiId: selectedDodiId,
              quantityString: quantity,
              ratePaise: ratePaise,
              session: session,
              date: date,
              loadTag: loadTag,
            );

            if (!context.mounted) return;

            if (success) {
              Provider.of<DodiProvider>(context, listen: false).refreshDodi(selectedDodiId);
              Provider.of<ActivityLogProvider>(context, listen: false).loadActivities(userId);
            }

            Navigator.of(context).pop();

            if (success) {
              AppToast.showSuccess(context, 'Updated ${quantity}L — $session session');
            } else {
              AppToast.showError(context, milkProvider.errorMessage ?? 'Failed to update.');
            }
          },
        ),
      ),
    );
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Smooth fade transition for top-level route changes.
  static PageRoute<T> _fade<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (_, _, _) => page,
      transitionDuration: const Duration(milliseconds: 380),
      transitionsBuilder: (_, animation, _, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          ),
          child: child,
        );
      },
    );
  }
}

/// Internal page widget that re-builds auth callbacks inside a new context
/// (needed after a navigation where the root context changes).
class _AuthEntryPage extends StatefulWidget {
  const _AuthEntryPage();

  @override
  State<_AuthEntryPage> createState() => _AuthEntryPageState();
}

class _AuthEntryPageState extends State<_AuthEntryPage> {
  bool _showRegister = false;

  @override
  Widget build(BuildContext context) {
    if (_showRegister) {
      return RegisterScreen(
        onSignupTap: (u, p, farm, farmer) async {
          final auth = Provider.of<AuthProvider>(context, listen: false);
          await auth.signup(u, p, farm, farmer);

          if (!context.mounted) return;
          if (auth.status == AuthStatus.success && auth.currentUser != null) {
            final userId = auth.currentUser!.id!;
            await Future.wait([
              Provider.of<DodiProvider>(context, listen: false).loadDodis(userId),
              Provider.of<CowProvider>(context, listen: false).loadCows(userId),
              Provider.of<MilkEntryProvider>(context, listen: false).fetchTodaysTotalMilk(),
              Provider.of<ActivityLogProvider>(context, listen: false).loadActivities(userId),
            ]);

            if (!context.mounted) return;
            AppRouter.goToShell(context, userId: userId);
          } else if (auth.status == AuthStatus.error) {
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
      onLoginTap: (u, p) async {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        await auth.login(u, p);
        if (!context.mounted) return;
        if (auth.status == AuthStatus.success && auth.currentUser != null) {
          final userId = auth.currentUser!.id!;
          await Future.wait([
            Provider.of<DodiProvider>(context, listen: false).loadDodis(userId),
            Provider.of<CowProvider>(context, listen: false).loadCows(userId),
            Provider.of<MilkEntryProvider>(context, listen: false).fetchTodaysTotalMilk(),
            Provider.of<ActivityLogProvider>(context, listen: false).loadActivities(userId),
          ]);
          if (!context.mounted) return;
          AppRouter.goToShell(context, userId: userId);
        } else if (auth.status == AuthStatus.error) {
          AppToast.showError(context, auth.errorMessage ?? 'Login failed.');
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
