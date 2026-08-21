import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/app_toast.dart';
import '../../../../core/utils/money_utils.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../models.dart';
import '../providers/dodi_provider.dart';
import '../widgets/dodi_card.dart';
import 'dodi_detail_screen.dart';

// ---------------------------------------------------------------------------
// DodiLedgerScreen
// ---------------------------------------------------------------------------
// Shows the full list of milk buyers (Dodis) and their outstanding balances.
//
// Pure UI — all buyer data arrives via [dodis]; all user actions are
// forwarded through callbacks. The widget has no side effects.
// ---------------------------------------------------------------------------

class DodiLedgerScreen extends StatefulWidget {
  final List<DodiModel> dodis;
  final int currentNavIndex;
  final VoidCallback onAddBuyerTap;
  final ValueChanged<String> onDodiCardTap;
  final ValueChanged<String>? onDodiCardLongPress;
  final ValueChanged<int> onNavTap;

  const DodiLedgerScreen({
    super.key,
    required this.dodis,
    required this.onAddBuyerTap,
    required this.onDodiCardTap,
    this.onDodiCardLongPress,
    required this.onNavTap,
    this.currentNavIndex = 2,
  });

  @override
  State<DodiLedgerScreen> createState() => _DodiLedgerScreenState();
}

class _DodiLedgerScreenState extends State<DodiLedgerScreen> {
  int _selectedTab = 0; // 0 = Active Buyers, 1 = Bin

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final userId = auth.currentUser?.id ?? 0;
      Provider.of<DodiProvider>(context, listen: false).loadDeletedDodis(userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dodiProvider = Provider.of<DodiProvider>(context);
    final deletedList = dodiProvider.deletedDodis;

    return Scaffold(
      backgroundColor: AppColors.bgGrey,
      appBar: _DodiAppBar(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page title row + FAB
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  AppStrings.milkBuyers,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                _AddBuyerButton(onTap: widget.onAddBuyerTap),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Active vs Bin Tab Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _TabPill(
                  label: 'Active Buyers (${widget.dodis.length})',
                  icon: Icons.people_alt_rounded,
                  isSelected: _selectedTab == 0,
                  onTap: () => setState(() => _selectedTab = 0),
                ),
                const SizedBox(width: 10),
                _TabPill(
                  label: 'Bin (${deletedList.length})',
                  icon: Icons.archive_outlined,
                  isSelected: _selectedTab == 1,
                  onTap: () => setState(() => _selectedTab = 1),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Content body
          Expanded(
            child: _selectedTab == 0
                ? (widget.dodis.isEmpty
                    ? _EmptyState(onAddTap: widget.onAddBuyerTap)
                    : _DodiList(
                        dodis: widget.dodis,
                        onDodiCardTap: widget.onDodiCardTap,
                        onDodiCardLongPress: widget.onDodiCardLongPress ?? (dodiIdStr) {
                          final id = int.tryParse(dodiIdStr);
                          if (id != null) {
                            final dodi = widget.dodis.where((d) => d.id == id).firstOrNull;
                            if (dodi != null) {
                              showBuyerManageModal(context, dodi);
                            }
                          }
                        },
                      ))
                : _BinList(
                    deletedDodis: deletedList,
                    onDodiCardTap: widget.onDodiCardTap,
                  ),
          ),
        ],
      ),

      bottomNavigationBar: _LedgerNavBar(
        currentIndex: widget.currentNavIndex,
        onTap: widget.onNavTap,
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabPill({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.deepGreen : AppColors.cardWhite,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [BoxShadow(color: AppColors.deepGreen.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : AppColors.textGrey),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textDark,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BinList extends StatelessWidget {
  final List<DodiModel> deletedDodis;
  final ValueChanged<String> onDodiCardTap;

  const _BinList({required this.deletedDodis, required this.onDodiCardTap});

  @override
  Widget build(BuildContext context) {
    if (deletedDodis.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.archive_outlined, size: 56, color: AppColors.textGrey),
            SizedBox(height: 12),
            Text(
              'No buyers in the Bin',
              style: TextStyle(color: AppColors.textDark, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 6),
            Text(
              'Buyers moved to the Bin will appear here and can be restored anytime.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textGrey, fontSize: 14),
            ),
          ],
        ),
      );
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.currentUser?.id ?? 0;
    final dodiProvider = Provider.of<DodiProvider>(context, listen: false);

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: deletedDodis.length,
      separatorBuilder: (ctx, i) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final dodi = deletedDodis[index];
        final rateRs = MoneyUtils.formatPaiseToRupees(dodi.defaultRatePaise);

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            dodi.name,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: const TextStyle(
                              color: AppColors.textDark,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'ARCHIVED',
                            style: TextStyle(color: Color(0xFFE65100), fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () async {
                      final success = await dodiProvider.restoreDodi(dodi.id!, userId);
                      if (context.mounted) {
                        if (success) {
                          AppToast.showSuccess(context, '✅ ${dodi.name} restored to active list.');
                        } else {
                          AppToast.showError(context, dodiProvider.errorMessage ?? 'Failed to restore buyer.');
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.deepGreen,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.restore_from_trash_rounded, size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Restore',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Rate: ${AppStrings.currency}$rateRs/${AppStrings.weightUnit}',
                    style: const TextStyle(color: AppColors.textGrey, fontSize: 13),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => DodiDetailScreen(
                            dodi: dodi,
                            isArchived: true,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        children: const [
                          Icon(Icons.history_rounded, color: AppColors.deepGreen, size: 18),
                          SizedBox(width: 4),
                          Text(
                            'Inspect History',
                            style: TextStyle(color: AppColors.deepGreen, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// _DodiAppBar
// Simple top bar with app icon + name on the left and a settings icon on
// the right, matching the DairyFarm Pro mockup header style.
// ---------------------------------------------------------------------------
class _DodiAppBar extends StatelessWidget implements PreferredSizeWidget {
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.bgGrey,
      elevation: 0,
      scrolledUnderElevation: 0,
      leadingWidth: 180,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(
              Icons.agriculture_rounded,
              color: AppColors.deepGreen,
              size: 22,
            ),
            SizedBox(width: 8),
            Text(
              AppStrings.appName,
              style: TextStyle(
                color: AppColors.deepGreen,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
      actions: const [],
    );
  }
}

// ---------------------------------------------------------------------------
// _AddBuyerButton
// Deep-green circle with a white "+" icon — exact match to the mockup FAB.
// ---------------------------------------------------------------------------
class _AddBuyerButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddBuyerButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.deepGreen,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.deepGreen.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 26),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _DodiList
// Scrollable list of DodiCard widgets with consistent horizontal padding.
// ---------------------------------------------------------------------------
class _DodiList extends StatelessWidget {
  final List<DodiModel> dodis;
  final ValueChanged<String> onDodiCardTap;
  final ValueChanged<String>? onDodiCardLongPress;

  const _DodiList({
    required this.dodis,
    required this.onDodiCardTap,
    this.onDodiCardLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: dodis.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final dodi = dodis[index];
        return DodiCard(
          dodi: dodi,
          onTap: onDodiCardTap,
          onLongPress: onDodiCardLongPress,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// _EmptyState
// Shown when [dodis] is empty — friendly nudge to add a first buyer.
// ---------------------------------------------------------------------------
class _EmptyState extends StatelessWidget {
  final VoidCallback onAddTap;
  const _EmptyState({required this.onAddTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: AppColors.sageTint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                color: AppColors.deepGreen,
                size: 38,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Buyers Yet',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap the + button to add your first milk buyer.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textGrey,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: 180,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: onAddTap,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Buyer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _LedgerNavBar
// Same 4-tab nav bar design used across the app, consistent with the
// bottom navigation visible in the buyer_ledger mockup.
// ---------------------------------------------------------------------------
class _LedgerNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _LedgerNavBar({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: AppStrings.navHome,
                isActive: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Icons.water_drop_outlined,
                activeIcon: Icons.water_drop_rounded,
                label: AppStrings.navMilk,
                isActive: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _NavItem(
                icon: Icons.account_balance_wallet_outlined,
                activeIcon: Icons.account_balance_wallet_rounded,
                label: AppStrings.navBuyers,
                isActive: currentIndex == 2,
                onTap: () => onTap(2),
              ),
              _NavItem(
                icon: Icons.pets_outlined,
                activeIcon: Icons.pets_rounded,
                label: AppStrings.navHerd,
                isActive: currentIndex == 3,
                onTap: () => onTap(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.sageTint : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? AppColors.deepGreen : AppColors.textGrey,
              size: 24,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: isActive ? AppColors.deepGreen : AppColors.textGrey,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
