import 'package:flutter/material.dart';
import 'package:dairy_farm_app/core/theme/app_icons.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/activity_display_formatter.dart';
import '../../domain/connectors/milk_card_actions_connector.dart';

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
  final dynamic icon;

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
// Matches Figma Frame "Html → Body" (390x918)
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

  /// Fired when the user selects a 3-dots menu action on Today's Milk card (Node 14:2).
  final ValueChanged<MilkCardActionType>? onMilkCardAction;

  /// Fired when the user taps the Scheduled Vet Check banner.
  final VoidCallback? onVetCheckBannerTap;

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
    this.onMilkCardAction,
    this.onVetCheckBannerTap,
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
      backgroundColor: const Color(0xFFFBF9F6), // Figma background #FBF9F6
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          color: const Color(0xFF1B4332),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            slivers: [
              // ── Header - TopAppBar Shared Component Execution ───────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: _GreetingBar(
                    greeting: _greeting,
                    farmName: widget.farmName,
                    actualFarmName: widget.actualFarmName,
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // ── Farm Summary Split Hero Section ──────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Metric Card 1: Today's Milk
                      Expanded(
                        child: _MilkCard(
                          totalMilk: widget.totalMilk,
                          morningMilk: widget.morningMilk,
                          eveningMilk: widget.eveningMilk,
                          onTap: widget.onMilkEntryTap,
                          onMilkCardAction: widget.onMilkCardAction,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Metric Card 2: Total Herd
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

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // ── Section - Quick Shortcuts Banner ─────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _ScheduledVetBanner(
                    onTap: widget.onVetCheckBannerTap,
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // ── Section: Recent Activity Header ──────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Activity',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF1B1C1A),
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      GestureDetector(
                        onTap: widget.onViewAllTap,
                        child: Text(
                          'View All',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF2C694E),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // ── Activity Feed List Container ─────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _ActivityCard(
                    activities: widget.recentActivities,
                    onAddCowTap: widget.onAddCowTap,
                  ),
                ),
              ),

              // Bottom padding so nothing is obscured by bottom nav
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
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
// Matches Figma Frame TopAppBar: "BAJWA DAIRIES" sub-header + "Good Morning,\nZain-ul-abidin"
// ---------------------------------------------------------------------------
class _GreetingBar extends StatelessWidget {
  final String greeting;
  final String farmName;
  final String? actualFarmName;

  const _GreetingBar({
    required this.greeting,
    required this.farmName,
    this.actualFarmName,
  });

  @override
  Widget build(BuildContext context) {
    final displaySubHeader = (actualFarmName != null && actualFarmName!.trim().isNotEmpty)
        ? actualFarmName!.toUpperCase()
        : 'BAJWA DAIRIES';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Uppercase Sub-Header in Rammetto One font (#2C694E)
              Text(
                displaySubHeader,
                style: GoogleFonts.rammettoOne(
                  fontSize: 11,
                  color: const Color(0xFF2C694E),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              // Greeting + Farmer Name in Plus Jakarta Sans
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: RichText(
                  text: TextSpan(
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                      letterSpacing: -0.5,
                    ),
                    children: [
                      TextSpan(
                        text: '$greeting\n',
                        style: const TextStyle(color: Color(0xFF1B1C1A)),
                      ),
                      TextSpan(
                        text: farmName,
                        style: const TextStyle(color: Color(0xFF1B4332)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Date Quick-Badge (Level 2 Elevation)
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 110),
          child: const _DateCard(),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _DateCard — Date Quick-Badge (Figma node 7:29)
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: const Color(0x66C1C8C2), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x141B4332),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              dateStr,
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF1B4332),
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              yearStr,
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF717973),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _MilkCard — Metric Card 1: Today's Milk (Figma node 7:38 with Node 14:2 Menu)
// ---------------------------------------------------------------------------
class _MilkCard extends StatelessWidget {
  final String totalMilk;
  final String morningMilk;
  final String eveningMilk;
  final VoidCallback onTap;
  final ValueChanged<MilkCardActionType>? onMilkCardAction;

  const _MilkCard({
    required this.totalMilk,
    required this.morningMilk,
    required this.eveningMilk,
    required this.onTap,
    this.onMilkCardAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: const Color(0x4DC1C8C2), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x081B4332),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
          BoxShadow(
            color: Color(0x0F1B4332),
            blurRadius: 32,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Row: Icon + Title + Node 14:2 3-dots Menu Popup
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.water_drop_outlined,
                      color: Color(0xFF2C694E),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Today's Milk",
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF414844),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Node 14:2 "More options" 3-dots Popup Menu
              PopupMenuButton<MilkCardActionType>(
                icon: const Icon(
                  Icons.more_vert_rounded,
                  size: 20,
                  color: Color(0xFF717973),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 180),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: Colors.white,
                elevation: 6,
                onSelected: (action) {
                  if (onMilkCardAction != null) {
                    onMilkCardAction!(action);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: MilkCardActionType.viewHistory,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.history_rounded,
                          size: 18,
                          color: Color(0xFF1B4332),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'View Milk History',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1B1C1A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: MilkCardActionType.exportSummary,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.ios_share_rounded,
                          size: 18,
                          color: Color(0xFF1B4332),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Export Daily Summary',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1B1C1A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Big Stat: 0.0 Kg
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF1B4332),
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
                children: [
                  TextSpan(text: '$totalMilk '),
                  TextSpan(
                    text: 'Kg',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Morning/Evening Breakdown Pill
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3F0),
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(color: const Color(0x40C1C8C2), width: 1),
              ),
              child: Text(
                'M: $morningMilk Kg  |  E: $eveningMilk Kg',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF414844),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Log Milk Action Button
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(9999),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.add_circle_outline_rounded,
                    size: 14,
                    color: Color(0xFF2C694E),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Log Milk',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF2C694E),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _CowsCard — Metric Card 2: Total Herd (Figma node 7:59)
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: const Color(0x4DC1C8C2), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x081B4332),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
          BoxShadow(
            color: Color(0x0F1B4332),
            blurRadius: 32,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Row
          Row(
            children: [
              AppIcons.cowHoof(color: const Color(0xFF2C694E), size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Total Herd: $totalCows',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF414844),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Big Stat Number
          Text(
            totalCows,
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF1B4332),
              fontSize: 34,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),

          // Status Breakdown Pills (5 Vertical Rows matching Figma node 7:69)
          Column(
            children: [
              _StatusPillRow(
                count: activeCount,
                label: 'Milking',
                bgColor: const Color(0x66AEEECB),
                dotColor: const Color(0xFF1B4332),
                textColor: const Color(0xFF1B4332),
              ),
              const SizedBox(height: 4),
              _StatusPillRow(
                count: pregnantCount,
                label: 'Pregnant',
                bgColor: const Color(0xFFF5F3F0),
                dotColor: const Color(0xFF2C694E),
                textColor: const Color(0xFF414844),
              ),
              const SizedBox(height: 4),
              _StatusPillRow(
                count: dryCount,
                label: 'Dry',
                bgColor: const Color(0xFFF5F3F0),
                dotColor: const Color(0xFF717973),
                textColor: const Color(0xFF414844),
              ),
              const SizedBox(height: 4),
              _StatusPillRow(
                count: bredHeiferCount,
                label: 'Bred Heifer',
                bgColor: const Color(0xFFF5F3F0),
                dotColor: const Color(0xFF2C694E),
                textColor: const Color(0xFF414844),
              ),
              const SizedBox(height: 4),
              _StatusPillRow(
                count: heiferCount,
                label: 'Heifer',
                bgColor: const Color(0xCCF5F3F0),
                dotColor: const Color(0xFFC1C8C2),
                textColor: const Color(0xFF717973),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPillRow extends StatelessWidget {
  final String count;
  final String label;
  final Color bgColor;
  final Color dotColor;
  final Color textColor;

  const _StatusPillRow({
    required this.count,
    required this.label,
    required this.bgColor,
    required this.dotColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '$count $label',
                style: GoogleFonts.plusJakartaSans(
                  color: textColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ScheduledVetBanner — Section: Quick Shortcuts Banner (Figma node 7:85)
// ---------------------------------------------------------------------------
class _ScheduledVetBanner extends StatelessWidget {
  final VoidCallback? onTap;

  const _ScheduledVetBanner({this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: const Color(0x4DC1C8C2), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x081B4332),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
          BoxShadow(
            color: Color(0x0F1B4332),
            blurRadius: 32,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(36),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(36),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Green Circle Icon Badge
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0x66AEEECB),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    color: Color(0xFF1B4332),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),

                // Text Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scheduled Vet Check',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF1B1C1A),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Cow #04 health visit at 2:00 PM',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF717973),
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),

                // Trailing Arrow Icon
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Color(0xFF717973),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ActivityCard — Activity Feed List Container (Figma node 7:104)
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
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(36),
          border: Border.all(color: const Color(0x4DC1C8C2), width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F1B4332),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No recent activity',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF717973),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48, minWidth: double.infinity),
              child: ElevatedButton.icon(
                onPressed: onAddCowTap,
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Add Cow'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B4332),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  textStyle: GoogleFonts.plusJakartaSans(
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
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: const Color(0x4DC1C8C2), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F1B4332),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: activities.length,
        separatorBuilder: (_, _) => const Divider(
          height: 1,
          indent: 68,
          endIndent: 20,
          color: Color(0xFFEFEEEB),
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
// _ActivityTile — A single row inside activity feed
// ---------------------------------------------------------------------------
class _ActivityTile extends StatelessWidget {
  final RecentActivity activity;
  const _ActivityTile({required this.activity});

  @override
  Widget build(BuildContext context) {
    final valueColor =
        activity.isPositive ? const Color(0xFF1B4332) : const Color(0xFF717973);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Circle Icon Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: activity.isPositive
                  ? const Color(0x66AEEECB)
                  : const Color(0xFFEFEEEB),
              shape: BoxShape.circle,
            ),
            child: activity.icon is IconData ? Icon(
              activity.icon,
              color: const Color(0xFF1B4332),
              size: 20,
            ) : IconTheme(data: const IconThemeData(color: Color(0xFF1B4332), size: 20), child: activity.icon),
          ),
          const SizedBox(width: 14),

          // Main text details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  activity.title,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1B1C1A),
                  ),
                ),
                const SizedBox(height: 2),
                ..._buildLeftDetails(),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Right Column
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _getTopRightText(),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: valueColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _getBottomRightText(),
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF717973),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
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
    return ActivityDisplayFormatter.getTopRightText(
      title: activity.title,
      subtitle: activity.subtitle,
      value: activity.value,
      metadata: activity.metadata,
    );
  }

  String _getBottomRightText() {
    if (activity.title == 'Payment Received' ||
        activity.title == 'Milk Sold' ||
        activity.title == 'Cow Removed' ||
        activity.title == 'Buyer Removed') {
      return _formatExactTime(activity.timeUnix);
    }
    return activity.time;
  }

  List<Widget> _buildLeftDetails() {
    final details = ActivityDisplayFormatter.getLeftDetails(
      title: activity.title,
      subtitle: activity.subtitle,
      value: activity.value,
      metadata: activity.metadata,
    );

    return details
        .map((text) => Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: const Color(0xFF717973),
              ),
            ))
        .toList();
  }

  String _formatExactTime(int timeUnix) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timeUnix);
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final minutes = dt.minute.toString().padLeft(2, '0');
    final monthStr = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ][dt.month - 1];
    return '$hour:$minutes $ampm, $monthStr ${dt.day}';
  }
}

// ---------------------------------------------------------------------------
// _DashboardNavBar — Bottom Navigation Bar (Figma node 7:150)
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
      decoration: const BoxDecoration(
        color: Color(0xFFFFFFFF),
        boxShadow: [
          BoxShadow(
            color: Color(0x0D1B4332),
            blurRadius: 24,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                icon: AppIcons.cowHoof(),
                activeIcon: AppIcons.cowHoof(),
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
  final dynamic icon;
  final dynamic activeIcon;
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFAEEECB) : Colors.transparent,
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            isActive ? (activeIcon is IconData ? Icon(activeIcon, color: isActive ? const Color(0xFF012D1D) : const Color(0xFF717973), size: 20) : IconTheme(data: IconThemeData(color: isActive ? const Color(0xFF012D1D) : const Color(0xFF717973), size: 20), child: activeIcon)) : (icon is IconData ? Icon(icon, color: isActive ? const Color(0xFF012D1D) : const Color(0xFF717973), size: 20) : IconTheme(data: IconThemeData(color: isActive ? const Color(0xFF012D1D) : const Color(0xFF717973), size: 20), child: icon)),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: isActive ? const Color(0xFF012D1D) : const Color(0xFF717973),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
