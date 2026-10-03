import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';

class ExportMilkSummary {
  final double totalQuantity;
  final double morningQuantity;
  final double eveningQuantity;
  final double dailyAvg;

  const ExportMilkSummary({
    this.totalQuantity = 0,
    this.morningQuantity = 0,
    this.eveningQuantity = 0,
    this.dailyAvg = 0,
  });
}

class ExportMilkLog {
  final DateTime date;
  final double totalQty;
  final double morningQty;
  final double eveningQty;

  const ExportMilkLog({
    required this.date,
    required this.totalQty,
    required this.morningQty,
    required this.eveningQty,
  });
}

class ExportMilkHistoryScreen extends StatefulWidget {
  final String farmName;
  final ExportMilkSummary summary;
  final List<ExportMilkLog> logs;

  const ExportMilkHistoryScreen({
    super.key,
    required this.farmName,
    this.summary = const ExportMilkSummary(),
    this.logs = const [],
  });

  @override
  State<ExportMilkHistoryScreen> createState() => _ExportMilkHistoryScreenState();
}

class _ExportMilkHistoryScreenState extends State<ExportMilkHistoryScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 11));
  DateTime _endDate = DateTime.now();
  String _selectedFormat = 'Pdf';

  final numberFormat = NumberFormat('#,##0.0');
  final dateFormat = DateFormat('dd MMM yyyy');

  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: now.subtract(const Duration(days: 365 * 5)),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.darkForest,
              onPrimary: Colors.white,
              onSurface: AppColors.textDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_startDate.isAfter(_endDate)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _startDate = _endDate;
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final daysSpan = _endDate.difference(_startDate).inDays.abs() + 1;

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
                          'Export Milk History',
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
                  const SizedBox(width: 36), // Balance the close button
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE5E5EA)),

            // Date Pickers Row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _pickDate(true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Start Date', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 10, color: AppColors.textGrey)),
                                const SizedBox(height: 2),
                                Text(dateFormat.format(_startDate), style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.darkForest)),
                              ],
                            ),
                            const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textGrey),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _pickDate(false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('End Date', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 10, color: AppColors.textGrey)),
                                const SizedBox(height: 2),
                                Text(dateFormat.format(_endDate), style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.darkForest)),
                              ],
                            ),
                            const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textGrey),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Body
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Green Summary Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.darkForest,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const CircleAvatar(radius: 4, backgroundColor: AppColors.sageGreen),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Total Milk Export Summary',
                                    style: TextStyle(
                                      fontFamily: 'Plus Jakarta Sans',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.sageGreen.withValues(alpha: 0.9),
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$daysSpan Days Span',
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
                          const SizedBox(height: 16),
                          const Text(
                            'Total Milk Produced / Dispatched',
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  numberFormat.format(widget.summary.totalQuantity),
                                  style: const TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'Kg',
                                  style: TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.sageGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.wb_sunny_outlined, size: 14, color: Colors.white70),
                                          SizedBox(width: 4),
                                          Text('Morning', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 10, color: Colors.white70)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        numberFormat.format(widget.summary.morningQuantity),
                                        style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                                      ),
                                      const Text('Kg', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 10, color: Colors.white54)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.nights_stay_outlined, size: 14, color: Colors.white70),
                                          SizedBox(width: 4),
                                          Text('Evening', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 10, color: Colors.white70)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        numberFormat.format(widget.summary.eveningQuantity),
                                        style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                                      ),
                                      const Text('Kg', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 10, color: Colors.white54)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.trending_up, size: 14, color: Colors.white70),
                                          SizedBox(width: 4),
                                          Text('Daily Avg', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 10, color: Colors.white70)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        numberFormat.format(widget.summary.dailyAvg),
                                        style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                                      ),
                                      const Text('Kg/day', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 10, color: Colors.white54)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Daily Breakdown Header
                    Row(
                      children: [
                        const Text(
                          'Daily Breakdown',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.mintCardBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${widget.logs.length} Logs',
                            style: const TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.deepGreen,
                            ),
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          'Kg (Net)',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 12,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Breakdown List
                    if (widget.logs.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        alignment: Alignment.center,
                        child: const Text(
                          'No daily breakdown records found for this period.',
                          style: TextStyle(fontFamily: 'Plus Jakarta Sans', color: AppColors.textGrey),
                        ),
                      )
                    else
                      ...widget.logs.map((log) => _buildBreakdownRow(log)),
                    
                    const SizedBox(height: 24),

                    // File Format Selector
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.backspaceBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.description_outlined, color: AppColors.textDark),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'File Format',
                                  style: TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                Text(
                                  'Image, PDF & Excel (.xlsx) package',
                                  style: TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontSize: 11,
                                    color: AppColors.textGrey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: AppTheme.softShadow,
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedFormat,
                                isDense: true,
                                icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                                style: const TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textDark,
                                ),
                                items: ['Pdf', 'Excel', 'Image'].map((f) {
                                  return DropdownMenuItem(value: f, child: Text(f));
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedFormat = val);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32), // Bottom padding
                  ],
                ),
              ),
            ),
            
            // Bottom Action Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: AppTheme.softShadow,
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.share_outlined, size: 18),
                      label: const Text('Share'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.backspaceBg,
                        foregroundColor: AppColors.textDark,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.download_outlined, size: 18),
                      label: const Text('Download Report'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.darkForest,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
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

  Widget _buildBreakdownRow(ExportMilkLog log) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          // 1. Date
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.backspaceBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    DateFormat('dd MMM').format(log.date),
                    style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textDark),
                  ),
                  Text(
                    DateFormat('yyyy').format(log.date),
                    style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 9, color: AppColors.textGrey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          // 2. Total
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.mintCardBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text(
                    'TOTAL',
                    style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.deepGreen),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      numberFormat.format(log.totalQty),
                      style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.darkForest),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          // 3. Morning
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wb_sunny_outlined, size: 10, color: Colors.grey),
                      SizedBox(width: 2),
                      Text('Morn', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 9, color: Colors.grey)),
                    ],
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      numberFormat.format(log.morningQty),
                      style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          // 4. Evening
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.nights_stay_outlined, size: 10, color: Colors.grey),
                      SizedBox(width: 2),
                      Text('Eve', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 9, color: Colors.grey)),
                    ],
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      numberFormat.format(log.eveningQty),
                      style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark),
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
