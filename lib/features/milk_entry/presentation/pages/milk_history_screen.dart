import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/milk_history_models.dart';
import '../../data/repositories/milk_history_repository.dart';

export '../../data/models/milk_history_models.dart'
    show MilkHistoryLog, MilkHistoryOverview;

class MilkHistoryScreen extends StatefulWidget {
  final String farmName;
  final int? userId;
  final DateTime? initialMonth;
  final double totalQuantity;
  final double avgQuantityPerDay;
  final double grossRevenue;
  final double avgRevenuePerKg;
  final List<MilkHistoryLog> logs;
  final MilkHistoryRepository? repository;

  const MilkHistoryScreen({
    super.key,
    required this.farmName,
    this.userId,
    this.initialMonth,
    this.totalQuantity = 0,
    this.avgQuantityPerDay = 0,
    this.grossRevenue = 0,
    this.avgRevenuePerKg = 0,
    this.logs = const [],
    this.repository,
  });

  @override
  State<MilkHistoryScreen> createState() => _MilkHistoryScreenState();
}

class _MilkHistoryScreenState extends State<MilkHistoryScreen> {
  late final MilkHistoryRepository _repository;
  late DateTime _selectedMonth;
  late int _selectedDaysToShow;
  String _activeFilter = 'All Loads';

  bool _isLoading = false;
  DateTime? _earliestActivityDate;
  double _totalQuantity = 0;
  double _avgQuantityPerDay = 0;
  double _grossRevenue = 0;
  double _avgRevenuePerKg = 0;
  List<MilkHistoryLog> _logs = [];

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? MilkHistoryRepository();

    final now = DateTime.now();
    _selectedMonth = widget.initialMonth ?? DateTime(now.year, now.month);
    _selectedDaysToShow = _getDaysInMonth(_selectedMonth);

    _totalQuantity = widget.totalQuantity;
    _avgQuantityPerDay = widget.avgQuantityPerDay;
    _grossRevenue = widget.grossRevenue;
    _avgRevenuePerKg = widget.avgRevenuePerKg;
    _logs = List.from(widget.logs);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  int _getDaysInMonth(DateTime month) {
    return DateTime(month.year, month.month + 1, 0).day;
  }

  int? _resolveUserId() {
    if (widget.userId != null) return widget.userId;
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      return auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadData() async {
    final userId = _resolveUserId();
    if (userId == null) {
      // If no DB user context available (e.g. standalone test), retain passed logs
      if (_earliestActivityDate == null) {
        setState(() {
          _earliestActivityDate = DateTime.now();
        });
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final earliest = await _repository.getEarliestUserActivityDate(userId);
      final overview = await _repository.getMilkHistoryForMonth(
        userId: userId,
        month: _selectedMonth,
        daysToShow: _selectedDaysToShow,
      );

      if (mounted) {
        setState(() {
          _earliestActivityDate = earliest;
          _totalQuantity = overview.totalQuantity;
          _avgQuantityPerDay = overview.avgQuantityPerDay;
          _grossRevenue = overview.grossRevenue;
          _avgRevenuePerKg = overview.avgRevenuePerKg;
          _logs = overview.logs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _pickMonth() {
    final now = DateTime.now();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        // Clamped strictly to the last 12 calendar months (R1)
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 16),
          itemCount: 12,
          itemBuilder: (ctx, i) {
            final monthDate = DateTime(now.year, now.month - i);
            final isSelected = _selectedMonth.year == monthDate.year &&
                _selectedMonth.month == monthDate.month;
            return ListTile(
              title: Text(
                DateFormat('MMMM yyyy').format(monthDate),
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppColors.deepGreen : AppColors.textDark,
                ),
              ),
              trailing: isSelected
                  ? const Icon(Icons.check, color: AppColors.deepGreen)
                  : null,
              onTap: () {
                setState(() {
                  _selectedMonth = monthDate;
                  final maxDays = _getDaysInMonth(_selectedMonth);
                  if (_selectedDaysToShow > maxDays) {
                    _selectedDaysToShow = maxDays;
                  }
                });
                Navigator.pop(ctx);
                _loadData();
              },
            );
          },
        );
      },
    );
  }

  void _pickDaysToShow() {
    final maxDays = _getDaysInMonth(_selectedMonth);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 16),
          itemCount: maxDays,
          itemBuilder: (ctx, i) {
            final days = i + 1;
            final isSelected = _selectedDaysToShow == days;
            return ListTile(
              title: Text(
                '$days Days',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppColors.deepGreen : AppColors.textDark,
                ),
              ),
              trailing: isSelected
                  ? const Icon(Icons.check, color: AppColors.deepGreen)
                  : null,
              onTap: () {
                setState(() => _selectedDaysToShow = days);
                Navigator.pop(ctx);
                _loadData();
              },
            );
          },
        );
      },
    );
  }

  List<MilkHistoryLog> get _filteredLogs {
    var list = _logs;
    final maxDays = _getDaysInMonth(_selectedMonth);
    if (_selectedDaysToShow < maxDays) {
      list = list.where((l) => l.date.day <= _selectedDaysToShow).toList();
    }
    if (_activeFilter == 'Morning Only') {
      list = list.where((l) => l.morningQty > 0).toList();
    } else if (_activeFilter == 'Evening Only') {
      list = list.where((l) => l.eveningQty > 0).toList();
    }
    return list;
  }

  bool get _isPreAccountPeriod {
    if (_earliestActivityDate == null) return false;
    final inceptionMonth = DateTime(
      _earliestActivityDate!.year,
      _earliestActivityDate!.month,
    );
    final currentPickedMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month,
    );
    return currentPickedMonth.isBefore(inceptionMonth);
  }

  @override
  Widget build(BuildContext context) {
    final monthFormat = DateFormat('MMM yyyy');
    final numberFormat = NumberFormat('#,##0.0');
    final displayedLogs = _filteredLogs;

    return Scaffold(
      backgroundColor: AppColors.creamBg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: const Icon(Icons.close, size: 20, color: AppColors.textDark),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          widget.farmName.toUpperCase(),
                          style: const TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textGrey,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Milk History',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkForest,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _pickMonth,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.mintCardBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.deepGreen),
                          const SizedBox(width: 4),
                          Text(
                            monthFormat.format(_selectedMonth),
                            style: const TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.deepGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE5E5EA)),

            // Scrollable Body
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.deepGreen),
                    )
                  : CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                // Green Overview Card
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: AppColors.darkForest,
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              const CircleAvatar(radius: 3, backgroundColor: AppColors.sageGreen),
                                              const SizedBox(width: 8),
                                              Text(
                                                '${DateFormat('MMMM').format(_selectedMonth).toUpperCase()} OVERVIEW',
                                                style: TextStyle(
                                                  fontFamily: 'Plus Jakarta Sans',
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.sageGreen.withValues(alpha: 0.9),
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              '${displayedLogs.length} Records',
                                              style: const TextStyle(
                                                fontFamily: 'Plus Jakarta Sans',
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.sageGreen,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 20),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Total Quantity',
                                                  style: TextStyle(
                                                    fontFamily: 'Plus Jakarta Sans',
                                                    fontSize: 12,
                                                    color: Colors.white70,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  child: Row(
                                                    crossAxisAlignment: CrossAxisAlignment.baseline,
                                                    textBaseline: TextBaseline.alphabetic,
                                                    children: [
                                                      Text(
                                                        numberFormat.format(_totalQuantity),
                                                        style: const TextStyle(
                                                          fontFamily: 'Plus Jakarta Sans',
                                                          fontSize: 28,
                                                          fontWeight: FontWeight.w700,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      const Text(
                                                        'Kg',
                                                        style: TextStyle(
                                                          fontFamily: 'Plus Jakarta Sans',
                                                          fontSize: 14,
                                                          fontWeight: FontWeight.w600,
                                                          color: Colors.white70,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Avg ${_avgQuantityPerDay.toStringAsFixed(1)} Kg/day',
                                                  style: const TextStyle(
                                                    fontFamily: 'Plus Jakarta Sans',
                                                    fontSize: 11,
                                                    color: Colors.white54,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(width: 1, height: 60, color: Colors.white.withValues(alpha: 0.1)),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Gross Revenue',
                                                  style: TextStyle(
                                                    fontFamily: 'Plus Jakarta Sans',
                                                    fontSize: 12,
                                                    color: Colors.white70,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  child: Row(
                                                    crossAxisAlignment: CrossAxisAlignment.baseline,
                                                    textBaseline: TextBaseline.alphabetic,
                                                    children: [
                                                      Text(
                                                        numberFormat.format(_grossRevenue / 1000),
                                                        style: const TextStyle(
                                                          fontFamily: 'Plus Jakarta Sans',
                                                          fontSize: 28,
                                                          fontWeight: FontWeight.w700,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                      const Text(
                                                        'k',
                                                        style: TextStyle(
                                                          fontFamily: 'Plus Jakarta Sans',
                                                          fontSize: 28,
                                                          fontWeight: FontWeight.w700,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      const Text(
                                                        'PKR',
                                                        style: TextStyle(
                                                          fontFamily: 'Plus Jakarta Sans',
                                                          fontSize: 14,
                                                          fontWeight: FontWeight.w600,
                                                          color: Colors.white70,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Avg Rs. ${_avgRevenuePerKg.toStringAsFixed(0)}/Kg',
                                                  style: const TextStyle(
                                                    fontFamily: 'Plus Jakarta Sans',
                                                    fontSize: 11,
                                                    color: Colors.white54,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Filter Chips
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  child: Row(
                                    children: [
                                      _FilterChip(
                                        label: 'All Loads',
                                        icon: Icons.list_alt,
                                        isSelected: _activeFilter == 'All Loads',
                                        onTap: () => setState(() => _activeFilter = 'All Loads'),
                                      ),
                                      const SizedBox(width: 8),
                                      _FilterChip(
                                        label: 'Morning Only',
                                        icon: Icons.wb_sunny_outlined,
                                        isSelected: _activeFilter == 'Morning Only',
                                        onTap: () => setState(() => _activeFilter = 'Morning Only'),
                                      ),
                                      const SizedBox(width: 8),
                                      _FilterChip(
                                        label: 'Evening Only',
                                        icon: Icons.nights_stay_outlined,
                                        isSelected: _activeFilter == 'Evening Only',
                                        onTap: () => setState(() => _activeFilter = 'Evening Only'),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Dispatch Logs Header
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Dispatch Logs',
                                      style: TextStyle(
                                        fontFamily: 'Plus Jakarta Sans',
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.darkForest,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: _pickDaysToShow,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppColors.darkForest,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          'Showing $_selectedDaysToShow Days',
                                          style: const TextStyle(
                                            fontFamily: 'Plus Jakarta Sans',
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Dual Empty State & Dispatch Logs List
                        if (displayedLogs.isEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                              child: _isPreAccountPeriod
                                  ? _buildPreAccountEmptyState()
                                  : _buildNoMilkEmptyState(),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: _DispatchLogCard(log: displayedLogs[index]),
                                  );
                                },
                                childCount: displayedLogs.length,
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreAccountEmptyState() {
    final earliestStr = _earliestActivityDate != null
        ? DateFormat('MMMM yyyy').format(_earliestActivityDate!)
        : 'recent registration';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.backspaceBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.history_toggle_off,
              size: 36,
              color: AppColors.textGrey,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Pre-Account Period',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.darkForest,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This month is before your farm account inception in $earliestStr. No activity was recorded prior to registration.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 13,
              color: AppColors.textGrey,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoMilkEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.mintCardBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.water_drop_outlined,
              size: 36,
              color: AppColors.deepGreen,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Milk Recorded',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.darkForest,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Zero milk sales recorded for ${DateFormat('MMMM yyyy').format(_selectedMonth)}.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 13,
              color: AppColors.textGrey,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.mintCardBg : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.mintCardBg : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppColors.deepGreen : AppColors.textGrey,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? AppColors.deepGreen : AppColors.textGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DispatchLogCard extends StatelessWidget {
  final MilkHistoryLog log;

  const _DispatchLogCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM');
    final yearFormat = DateFormat('yyyy');
    final numberFormat = NumberFormat('#,##0.0');
    final currencyFormat = NumberFormat('#,##0');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppColors.sageTint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.local_shipping_outlined, size: 20, color: AppColors.deepGreen),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  log.buyerName,
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkForest,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.backspaceBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      dateFormat.format(log.date),
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkForest,
                      ),
                    ),
                    Text(
                      yearFormat.format(log.date),
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 10,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Collected',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 11,
                        color: AppColors.textGrey,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          numberFormat.format(log.totalCollected),
                          style: const TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.darkForest,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Kg',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkForest,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Rate: Rs. ${log.rate.toStringAsFixed(0)}/Kg',
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 11,
                        color: AppColors.textGrey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rs. ${currencyFormat.format(log.totalAmount ?? (log.totalCollected * log.rate))}',
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.creamBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.wb_sunny_outlined, size: 16, color: Colors.amber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Morning (Load 1)',
                              style: TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 10,
                                color: AppColors.textGrey,
                              ),
                            ),
                            Text(
                              '${numberFormat.format(log.morningQty)} Kg',
                              style: const TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.darkForest,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.creamBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.nights_stay_outlined, size: 16, color: AppColors.sageGreen),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Evening (Load 2)',
                              style: TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 10,
                                color: AppColors.textGrey,
                              ),
                            ),
                            Text(
                              '${numberFormat.format(log.eveningQty)} Kg',
                              style: const TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.darkForest,
                              ),
                            ),
                          ],
                        ),
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
  }
}
