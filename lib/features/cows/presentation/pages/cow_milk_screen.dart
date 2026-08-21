import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_toast.dart';
import '../../data/models/cow_model.dart';
import '../providers/cow_provider.dart';
import '../../../dashboard/presentation/providers/activity_log_provider.dart';
import 'package:intl/intl.dart';

class CowMilkScreen extends StatefulWidget {
  final int cowId;

  const CowMilkScreen({super.key, required this.cowId});

  @override
  State<CowMilkScreen> createState() => _CowMilkScreenState();
}

class _CowMilkScreenState extends State<CowMilkScreen> {
  CowModel? _cow;
  Map<String, int?>? _currentSeasonYields;
  Map<String, dynamic>? _latestSeason;
  List<Map<String, dynamic>> _rawSessions = [];
  List<Map<String, dynamic>> _monthlySummaries = [];
  bool _isLoading = true;

  final _gramsController = TextEditingController();
  String _selectedSession = 'MORNING';
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _gramsController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final provider = context.read<CowProvider>();
    final cowList = provider.cows.where((c) => c.id == widget.cowId).toList();
    if (cowList.isNotEmpty) {
      _cow = cowList.first;
    }

    _currentSeasonYields = await provider.getSeasonSessionYields(widget.cowId);
    _latestSeason = await provider.getLatestSeason(widget.cowId);

    final seasonId = _latestSeason?['id'] as int?;
    if (seasonId != null) {
      _rawSessions = await provider.getSessionsForSeason(seasonId);
      _monthlySummaries = await provider.getMonthlySummariesForSeason(seasonId);
    }

    setState(() => _isLoading = false);
  }

  Future<void> _submitYield() async {
    final text = _gramsController.text.trim();
    if (text.isEmpty) {
      AppToast.showWarning(context, 'Please enter a milk yield amount');
      return;
    }
    
    final parsedKg = double.tryParse(text);
    if (parsedKg == null) {
      AppToast.showWarning(context, 'Please enter a valid decimal number');
      return;
    }
    
    final grams = (parsedKg * 1000).toInt();

    final dateStr = _selectedDate != null 
        ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
        : DateFormat('yyyy-MM-dd').format(DateTime.now());

    final provider = context.read<CowProvider>();
    await provider.logDailyYield(
      cowId: widget.cowId,
      date: dateStr,
      morningGrams: _selectedSession == 'MORNING' ? grams : null,
      eveningGrams: _selectedSession == 'EVENING' ? grams : null,
    );

    _gramsController.clear();
    _selectedDate = null;
    if (mounted) {
      FocusScope.of(context).unfocus();
    }

    await _loadData();
    if (mounted && _cow != null) {
      context.read<ActivityLogProvider>().loadActivities(_cow!.userId);
    }
    if (mounted) {
      AppToast.showSuccess(context, 'Milk entry recorded successfully');
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgGrey,
      appBar: AppBar(
        title: const Text('Milk Records'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _cow == null
              ? const Center(child: Text('Cow not found'))
              : SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight - 32,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHeader(),
                                const SizedBox(height: 24),
                                _buildSeasonSummary(),
                                if (_cow!.status == 'MILKING' || _cow!.status == 'PREGNANT') ...[
                                  const SizedBox(height: 24),
                                  _buildEntryForm(),
                                ],
                                const SizedBox(height: 24),
                                if (_rawSessions.isEmpty && _monthlySummaries.isEmpty)
                                  Container(
                                    constraints: const BoxConstraints(minHeight: 200),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Records not available',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  )
                                else ...[
                                  _buildRecentSessions(),
                                  const SizedBox(height: 24),
                                  _buildMonthlySummaries(),
                                ],
                              ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.sageTint,
            child: const Icon(Icons.pets, color: AppColors.deepGreen),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _cow!.name ?? 'Cow ${_cow!.tagNumber}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  'Tag: ${_cow!.tagNumber} • ${_cow!.status}',
                  style: const TextStyle(color: AppColors.textGrey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeasonSummary() {
    String? mPeak, ePeak;
    
    if (_latestSeason != null && _latestSeason!['season_end_date'] == null) {
      // Active season
      mPeak = _currentSeasonYields?['peakMorning'] != null ? '${(_currentSeasonYields!['peakMorning']! / 1000).toStringAsFixed(1)} kg' : '?';
      ePeak = _currentSeasonYields?['peakEvening'] != null ? '${(_currentSeasonYields!['peakEvening']! / 1000).toStringAsFixed(1)} kg' : '?';
    } else if (_latestSeason != null) {
      // Ended season
      // We look for highest session from latest season
      final hSession = _latestSeason!['season_highest_session'];
      final hGrams = _latestSeason!['season_highest_grams'];
      if (hSession == 'MORNING') mPeak = '${(hGrams / 1000).toStringAsFixed(1)} kg';
      if (hSession == 'EVENING') ePeak = '${(hGrams / 1000).toStringAsFixed(1)} kg';
      mPeak ??= '?';
      ePeak ??= '?';
    } else {
      mPeak = '?';
      ePeak = '?';
    }

    if (mPeak == '?' && ePeak == '?') {
      return const SizedBox.shrink(); // No data yet
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Season Peak',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricBox('Morning', mPeak),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricBox('Evening', ePeak),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgGrey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textDark)),
        ],
      ),
    );
  }

  Widget _buildEntryForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add Milk Entry',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedSession,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'MORNING', child: Text('Morning')),
                    DropdownMenuItem(value: 'EVENING', child: Text('Evening')),
                  ],
                  onChanged: (v) => setState(() => _selectedSession = v!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _gramsController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                  decoration: const InputDecoration(
                    labelText: 'kg',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(_selectedDate != null 
                    ? DateFormat('MMM d, yyyy').format(_selectedDate!)
                    : 'Today'),
                onPressed: _pickDate,
              ),
              SizedBox(
                width: 120,
                child: ElevatedButton(
                  onPressed: _submitYield,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.deepGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSessions() {
    if (_rawSessions.isEmpty) return const SizedBox.shrink();

    // Group by date
    final Map<String, Map<String, int>> grouped = {};
    for (var session in _rawSessions) {
      final date = session['date'] as String;
      final sess = session['session'] as String;
      final grams = session['quantity_grams'] as int;
      grouped.putIfAbsent(date, () => {});
      grouped[date]![sess] = grams;
    }

    final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Sessions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: MediaQuery.of(context).size.height * 0.35,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            itemCount: dates.length,
            itemBuilder: (context, index) {
              final date = dates[index];
              final yields = grouped[date]!;
              final mGrams = yields['MORNING'];
              final eGrams = yields['EVENING'];

              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: InkWell(
                  onLongPress: () => _confirmDeleteSessionDate(date, mGrams, eGrams),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.cardWhite,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: Row(
                      children: [
                        Text(
                          date,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.deepGreen),
                        ),
                        const Spacer(),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (mGrams != null)
                              Text('M: ${(mGrams / 1000).toStringAsFixed(1)} kg', style: const TextStyle(color: AppColors.deepGreen)),
                            if (mGrams != null && eGrams != null) const SizedBox(width: 12),
                            if (eGrams != null)
                              Text('E: ${(eGrams / 1000).toStringAsFixed(1)} kg', style: const TextStyle(color: AppColors.deepGreen)),
                          ],
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.deepGreen),
                          onPressed: () => _showEditSessionDateDialog(date, mGrams, eGrams),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMonthlySummaries() {
    if (_monthlySummaries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Monthly History',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _monthlySummaries.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final summary = _monthlySummaries[index];
            final ym = summary['year_month'] as String;
            final hGrams = summary['highest_grams'] as int;
            final lGrams = summary['lowest_grams'] as int;
            
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(12),
                boxShadow: AppTheme.softShadow,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    ym,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Peak: ${(hGrams / 1000).toStringAsFixed(1)} kg', style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
                      const SizedBox(width: 8),
                      Text('Low: ${(lGrams / 1000).toStringAsFixed(1)} kg', style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  void _confirmDeleteSessionDate(String date, int? mGrams, int? eGrams) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entries?'),
        content: Text('Are you sure you want to delete milk entries for $date?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final provider = context.read<CowProvider>();
              if (mGrams != null) {
                await provider.deleteMilkSession(widget.cowId, date, 'MORNING');
              }
              if (eGrams != null) {
                await provider.deleteMilkSession(widget.cowId, date, 'EVENING');
              }
              await _loadData();
              if (mounted) {
                AppToast.showSuccess(context, 'Entries deleted successfully');
              }
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.warningRed)),
          ),
        ],
      ),
    );
  }

  void _showEditSessionDateDialog(String date, int? mGrams, int? eGrams) {
    final mController = TextEditingController(text: mGrams != null ? (mGrams / 1000).toStringAsFixed(1) : '');
    final eController = TextEditingController(text: eGrams != null ? (eGrams / 1000).toStringAsFixed(1) : '');
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text('Edit Entries - $date'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: mController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Morning (kg)'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: eController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Evening (kg)'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        setStateDialog(() => isSaving = true);
                        final provider = context.read<CowProvider>();
                        
                        final mVal = double.tryParse(mController.text.trim());
                        final eVal = double.tryParse(eController.text.trim());
                        
                        if (mGrams != null && mVal == null) {
                          await provider.deleteMilkSession(widget.cowId, date, 'MORNING');
                        } else if (mVal != null) {
                          if (mGrams != null) {
                            await provider.updateMilkSession(widget.cowId, date, 'MORNING', (mVal * 1000).toInt());
                          } else {
                            await provider.logDailyYield(cowId: widget.cowId, date: date, morningGrams: (mVal * 1000).toInt());
                          }
                        }

                        if (eGrams != null && eVal == null) {
                          await provider.deleteMilkSession(widget.cowId, date, 'EVENING');
                        } else if (eVal != null) {
                          if (eGrams != null) {
                            await provider.updateMilkSession(widget.cowId, date, 'EVENING', (eVal * 1000).toInt());
                          } else {
                            await provider.logDailyYield(cowId: widget.cowId, date: date, eveningGrams: (eVal * 1000).toInt());
                          }
                        }

                        await _loadData();
                        if (mounted && ctx.mounted) {
                          Navigator.of(ctx).pop();
                          AppToast.showSuccess(context, 'Entries updated successfully');
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepGreen,
                  foregroundColor: Colors.white,
                ),
                child: isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }
}
