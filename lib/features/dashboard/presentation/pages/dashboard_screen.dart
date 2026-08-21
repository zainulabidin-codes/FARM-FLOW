import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_strings.dart';

// ---------------------------------------------------------------------------
// Data model — dashboard only (no DB logic, pure UI data carrier)
// ---------------------------------------------------------------------------

/// A single entry shown in the "Recent Activity" list on the dashboard.
class RecentActivity {
  /// Display title, e.g. "Morning Milk".
  final String title;

  /// Subtitle, e.g. "Cow #42".
  final String subtitle;

  /// Value label, e.g. "+12.5L" or "−200L".
  final String value;

  /// Timestamp or date label, e.g. "06:30 AM" or "Yesterday".
  final String time;

  /// Icon shown in the leading circle avatar.
  final IconData icon;

  /// If true the value is styled in sage green (+), otherwise warning red (−).
  final bool isPositive;

  /// Extra structured data specific to the event type.
  final Map<String, dynamic>? metadata;

  /// The raw unix timestamp of the event.
  final int timeUnix;

  const RecentActivity({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.time,
    required this.icon,
    required this.timeUnix,
    this.isPositive = true,
    this.metadata,
  });
}

// ---------------------------------------------------------------------------
// DashboardScreen
// ---------------------------------------------------------------------------
// Pure UI — every piece of data arrives via parameters; every user action
// is forwarded through callbacks. The widget contains no side effects.
// ---------------------------------------------------------------------------

class DashboardScreen extends StatefulWidget {
  // ── Data parameters ──────────────────────────────────────────────────────

  /// Farm / profile name shown in the greeting, e.g. "Singh Farm".
  final String farmName;

  /// Total milk collected today, e.g. "245.5".
  final String totalMilk;

  /// Morning session milk, e.g. "120".
  final String morningMilk;

  /// Evening session milk, e.g. "125.5".
  final String eveningMilk;

  /// Total cows in the herd.
  final String totalCows;

  /// Number of active cows, e.g. "18".
  final String activeCows;

  /// Number of pregnant cows shown in the badge, e.g. "2".
  final String pregnantCount;

  /// Number of dry cows shown in the badge, e.g. "1".
  final String dryCount;

  /// Number of bred heifers shown in the badge, e.g. "1".
  final String bredHeiferCount;

  /// Number of heifers shown in the badge, e.g. "2".
  final String heiferCount;

  /// Recent activity feed shown at the bottom of the screen.
  final List<RecentActivity> recentActivities;

  /// Index of the currently selected bottom-nav tab.
  final int currentNavIndex;

  // ── Callbacks ─────────────────────────────────────────────────────────────

  /// Fired when the user taps the "Milk" FAB / quick-action area.
  final VoidCallback onMilkEntryTap;

  /// Fired when the user taps the "Buyers" nav item or quick-action.
  final VoidCallback onDodiTap;

  /// Fired when the bottom-nav index changes.
  final ValueChanged<int> onNavTap;

  /// Fired when the user taps "Add Cow" in the empty state.
  final VoidCallback onAddCowTap;

  /// Fired when the user taps "View All" on the recent activity section.
  final VoidCallback onViewAllTap;

  /// Fired when user pulls to refresh dashboard metrics.
  final Future<void> Function()? onRefresh;

  /// The actual name of the farm.
  final String? actualFarmName;

  const DashboardScreen({
    super.key,
    required this.farmName,
    required this.totalMilk,
    required this.morningMilk,
    required this.eveningMilk,
    required this.totalCows,
    required this.activeCows,
    required this.pregnantCount,
    required this.dryCount,
    this.bredHeiferCount = '0',
    this.heiferCount = '0',
    required this.recentActivities,
    required this.onMilkEntryTap,
    required this.onDodiTap,
    required this.onNavTap,
    required this.onAddCowTap,
    required this.onViewAllTap,
    this.currentNavIndex = 0,
    this.actualFarmName,
    this.onRefresh,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _greeting = AppStrings.greeting;

  @override
  void initState() {
    super.initState();
    _computeGreeting();
  }

  Future<void> _handleRefresh() async {
    _computeGreeting();
    if (widget.onRefresh != null) {
      await widget.onRefresh!();
    }
  }

  void _computeGreeting() {
    final hour = DateTime.now().hour;
    String newGreeting;
    if (hour >= 5 && hour < 12) {
      newGreeting = 'Good Morning,';
    } else if (hour >= 12 && hour < 17) {
      newGreeting = 'Good Afternoon,';
    } else if (hour >= 17 && hour < 21) {
      newGreeting = 'Good Evening,';
    } else {
      newGreeting = 'Good Night,';
    }

    if (_greeting != newGreeting) {
      setState(() {
        _greeting = newGreeting;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgGrey,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          color: AppColors.deepGreen,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            slivers: [
              // ── Sticky top greeting bar ──────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: _GreetingBar(
                    greeting: _greeting,
                    farmName: widget.farmName,
                    actualFarmName: widget.actualFarmName,
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // ── Stat cards row ───────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      // Today's Milk card
                      Expanded(
                        child: _MilkCard(
                          totalMilk: widget.totalMilk,
                          morningMilk: widget.morningMilk,
                          eveningMilk: widget.eveningMilk,
                          onTap: widget.onMilkEntryTap,
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Active Cows card
                      Expanded(
                        child: _CowsCard(
                          totalCows: widget.totalCows,
                          activeCount: widget.activeCows,
                          pregnantCount: widget.pregnantCount,
                          dryCount: widget.dryCount,
                          bredHeiferCount: widget.bredHeiferCount,
                          heiferCount: widget.heiferCount,
                          onAddCowTap: widget.onAddCowTap,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 28)),

              // ── Recent Activity header ───────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppStrings.recentActivity,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      GestureDetector(
                        onTap: widget.onViewAllTap,
                        child: Text(
                          AppStrings.viewAll,
                          style: const TextStyle(
                            color: AppColors.deepGreen,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // ── Activity list ────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _ActivityCard(
                    activities: widget.recentActivities,
                    onAddCowTap: widget.onAddCowTap,
                  ),
                ),
              ),

              // Bottom padding so nothing hides behind the nav bar.
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),

      // ── Bottom Navigation Bar ─────────────────────────────────────────
      bottomNavigationBar: _DashboardNavBar(
        currentIndex: widget.currentNavIndex,
        onTap: widget.onNavTap,
        onDodiTap: widget.onDodiTap,
        onMilkTap: widget.onMilkEntryTap,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _GreetingBar
// ---------------------------------------------------------------------------
class _GreetingBar extends StatelessWidget {
  final String greeting;
  final String farmName;
  final String? actualFarmName;
  const _GreetingBar({required this.greeting, required this.farmName, this.actualFarmName});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                greeting,
                style: const TextStyle(
                  color: AppColors.textDark,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  height: 1.1,
                ),
              ),
              Text(
                farmName,
                style: const TextStyle(
                  color: AppColors.deepGreen,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  height: 1.1,
                ),
              ),
              if (actualFarmName != null && actualFarmName!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  actualFarmName!.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.8),
                  ),
                ),
              ]
            ],
          ),
        ),
        // Offline Date Card
        const _DateCard(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _DateCard
// ---------------------------------------------------------------------------
class _DateCard extends StatelessWidget {
  const _DateCard();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final dateStr = '${now.day} ${months[now.month - 1]}';
    final yearStr = '${now.year}';

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            dateStr,
            style: const TextStyle(
              color: AppColors.deepGreen,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            yearStr,
            style: const TextStyle(
              color: AppColors.textGrey,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _MilkCard  —  "Today's Milk" stat card
// ---------------------------------------------------------------------------
class _MilkCard extends StatelessWidget {
  final String totalMilk;
  final String morningMilk;
  final String eveningMilk;
  final VoidCallback onTap;

  const _MilkCard({
    required this.totalMilk,
    required this.morningMilk,
    required this.eveningMilk,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 140),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.todaysMilk,
              style: const TextStyle(
                color: AppColors.textGrey,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            // FittedBox ensures the number+unit never clips on small screens.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '$totalMilk Kg',
                style: const TextStyle(
                  color: AppColors.deepGreen,
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -2,
                  height: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 10),
            // M / E breakdown pill with FittedBox scale-down protection
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.bgGrey,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${AppStrings.morningAbbr}: $morningMilk ${AppStrings.weightUnit}  |  '
                  '${AppStrings.eveningAbbr}: $eveningMilk ${AppStrings.weightUnit}',
                  style: const TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
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
// _CowsCard  —  "Active Cows" stat card
// ---------------------------------------------------------------------------
class _CowsCard extends StatelessWidget {
  final String totalCows;
  final String activeCount;
  final String pregnantCount;
  final String dryCount;
  final String bredHeiferCount;
  final String heiferCount;
  final VoidCallback onAddCowTap;

  const _CowsCard({
    required this.totalCows,
    required this.activeCount,
    required this.pregnantCount,
    required this.dryCount,
    required this.bredHeiferCount,
    required this.heiferCount,
    required this.onAddCowTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 140),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${AppStrings.totalHerd}: $totalCows',
            style: const TextStyle(
              color: AppColors.textGrey,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              totalCows,
              style: const TextStyle(
                color: AppColors.deepGreen,
                fontSize: 48,
                fontWeight: FontWeight.w800,
                letterSpacing: -2,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Badges Wrap (All 5 Tags)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _StatusBadge(count: activeCount, label: 'Milking'),
              _StatusBadge(count: pregnantCount, label: 'Pregnant'),
              _StatusBadge(count: dryCount, label: 'Dry'),
              _StatusBadge(count: bredHeiferCount, label: 'Bred Heifer'),
              _StatusBadge(count: heiferCount, label: 'Heifer'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String count;
  final String label;

  const _StatusBadge({required this.count, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.sageTint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: AppColors.deepGreen,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            '$count $label',
            style: const TextStyle(
              color: AppColors.deepGreen,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ActivityCard  —  Recent Activity list inside a single white card
// ---------------------------------------------------------------------------
class _ActivityCard extends StatelessWidget {
  final List<RecentActivity> activities;
  final VoidCallback onAddCowTap;
  
  const _ActivityCard({
    required this.activities,
    required this.onAddCowTap,
  });

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'No recent activity',
              style: TextStyle(color: AppColors.textGrey, fontSize: 14),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: onAddCowTap,
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Add Cow'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListView.separated(
        // Not scrollable itself — wrapped inside the outer CustomScrollView.
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: activities.length,
        separatorBuilder: (_, _) => const Divider(
          height: 1,
          indent: 68,
          endIndent: 20,
          color: Color(0xFFE5E5EA),
        ),
        itemBuilder: (context, index) {
          final item = activities[index];
          return _ActivityTile(activity: item);
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ActivityTile  —  A single row inside the activity card
// ---------------------------------------------------------------------------
class _ActivityTile extends StatelessWidget {
  final RecentActivity activity;
  const _ActivityTile({required this.activity});

  @override
  Widget build(BuildContext context) {
    final valueColor =
        activity.isPositive ? AppColors.deepGreen : AppColors.textGrey;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Leading circle icon
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: activity.isPositive
                  ? AppColors.sageTint
                  : const Color(0xFFEEEEEE),
              shape: BoxShape.circle,
            ),
            child: Icon(
              activity.icon,
              color: activity.isPositive
                  ? AppColors.deepGreen
                  : AppColors.textGrey,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),

          // Main text column (Left Side)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  activity.title,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                ..._buildLeftDetails(),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Right Side (Identifier / timestamp)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _getTopRightText(),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: valueColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _getBottomRightText(),
                  style: const TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getTopRightText() {
    final meta = activity.metadata ?? {};
    if (activity.title == 'New Cow Added' || activity.title == 'Cow Removed' || activity.title == 'Cow Updated' || activity.title == 'Pregnancy Ended' || activity.title == 'Pregnancy Confirmed' || activity.title == 'Heat Repeated') {
      final name = meta['name']?.toString() ?? activity.subtitle;
      final tag = meta['tag']?.toString();
      if (tag != null && name != tag && !name.contains(tag)) {
        return '$name ($tag)';
      }
      return name;
    }
    if (activity.title == 'Payment Received' || activity.title == 'Milk Sold') {
      return '${activity.subtitle}  ${activity.value}';
    }
    if (activity.title == 'Buyer Added' || activity.title == 'Buyer Removed' || activity.title == 'Buyer Updated') {
      return activity.subtitle;
    }
    return activity.value;
  }

  String _getBottomRightText() {
    if (activity.title == 'Payment Received' || activity.title == 'Milk Sold' || activity.title == 'Cow Removed' || activity.title == 'Buyer Removed') {
      return _formatExactTime(activity.timeUnix);
    }
    return activity.time;
  }

  List<Widget> _buildLeftDetails() {
    final meta = activity.metadata ?? {};
    if (activity.title == 'New Cow Added' || activity.title == 'Cow Updated') {
      return [
        Text(activity.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
      ];
    }
    if (activity.title == 'Pregnancy Ended' || activity.title == 'Pregnancy Confirmed' || activity.title == 'Heat Repeated') {
      return [
        Text(activity.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
      ];
    }
    if (activity.title == 'Buyer Added' || activity.title == 'Buyer Updated') {
      return [
        if (meta['phone'] != null)
          Text(meta['phone'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
        Text(activity.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
      ];
    }
    if (activity.title == 'Cow Removed' || activity.title == 'Buyer Removed') {
      return [
        Text(activity.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
      ];
    }
    return [
      Text(activity.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
    ];
  }

  String _formatExactTime(int timeUnix) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timeUnix);
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final minutes = dt.minute.toString().padLeft(2, '0');
    final monthStr = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][dt.month - 1];
    return '$hour:$minutes $ampm, $monthStr ${dt.day}';
  }
}

// ---------------------------------------------------------------------------
// _DashboardNavBar
// Matches the 4-tab layout in the mockup: Home | Milk | Buyers | Herd.
// The active tab gets a circular sage-tint background pill.
// ---------------------------------------------------------------------------
class _DashboardNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onDodiTap;
  final VoidCallback onMilkTap;

  const _DashboardNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.onDodiTap,
    required this.onMilkTap,
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
                fontWeight:
                    isActive ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
