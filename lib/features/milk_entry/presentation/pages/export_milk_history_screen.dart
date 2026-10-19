import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_toast.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/milk_history_models.dart';
import '../../data/repositories/milk_history_repository.dart';
import '../../services/milk_export_service.dart';

export '../../data/models/milk_history_models.dart'
    show ExportMilkSummary, ExportMilkLog;

class ExportMilkHistoryScreen extends StatefulWidget {
  final String farmName;
  final int? userId;
  final ExportMilkSummary summary;
  final List<ExportMilkLog> logs;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final MilkHistoryRepository? repository;
  final MilkExportService? exportService;

  const ExportMilkHistoryScreen({
    super.key,
    required this.farmName,
    this.userId,
    this.summary = const ExportMilkSummary(),
    this.logs = const [],
    this.initialStartDate,
    this.initialEndDate,
    this.repository,
    this.exportService,
  });

  @override
  State<ExportMilkHistoryScreen> createState() => _ExportMilkHistoryScreenState();
}

class _ExportMilkHistoryScreenState extends State<ExportMilkHistoryScreen> {
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  late final MilkHistoryRepository _repository;
  late final MilkExportService _exportService;

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 11));
  DateTime _endDate = DateTime.now();
  String _selectedFormat = 'Pdf';

  final numberFormat = NumberFormat('#,##0.0');
  final dateFormat = DateFormat('dd MMM yyyy');

  bool _isLoading = false;
  bool _isExporting = false;
  late ExportMilkSummary _summary;
  late List<ExportMilkLog> _logs;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? MilkHistoryRepository();
    _exportService = widget.exportService ?? MilkExportService();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _startDate = widget.initialStartDate != null
        ? DateTime(widget.initialStartDate!.year, widget.initialStartDate!.month, widget.initialStartDate!.day)
        : today.subtract(const Duration(days: 11));
    _endDate = widget.initialEndDate != null
        ? DateTime(widget.initialEndDate!.year, widget.initialEndDate!.month, widget.initialEndDate!.day)
        : today;

    _summary = widget.summary;
    _logs = List.from(widget.logs);

    // Initial clamp check
    _clampDateRange();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _clampDateRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final earliestAllowed = DateTime(today.year - 1, today.month, today.day);

    _startDate = DateTime(_startDate.year, _startDate.month, _startDate.day);
    _endDate = DateTime(_endDate.year, _endDate.month, _endDate.day);

    if (_startDate.isBefore(earliestAllowed)) {
      _startDate = earliestAllowed;
    }
    if (_endDate.isAfter(today)) {
      _endDate = today;
    }
    if (_startDate.isAfter(_endDate)) {
      _startDate = _endDate;
    }
    if (_endDate.difference(_startDate).inDays > 366) {
      _startDate = DateTime(_endDate.year - 1, _endDate.month, _endDate.day);
    }
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
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _repository.getExportDataForRange(
        userId: userId,
        startDate: _startDate,
        endDate: _endDate,
      );

      if (mounted) {
        setState(() {
          _summary = result.summary;
          _logs = result.logs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final earliestAllowed = DateTime(today.year - 1, today.month, today.day);

    final rawInitial = isStart ? _startDate : _endDate;
    final normalizedInitial = DateTime(rawInitial.year, rawInitial.month, rawInitial.day);
    final initialDate = normalizedInitial.isBefore(earliestAllowed)
        ? earliestAllowed
        : (normalizedInitial.isAfter(today) ? today : normalizedInitial);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: earliestAllowed, // Clamped to max 12 calendar months in past
      lastDate: today,
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
        final normalizedPicked = DateTime(picked.year, picked.month, picked.day);
        if (isStart) {
          _startDate = normalizedPicked;
          if (_startDate.isAfter(_endDate)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = normalizedPicked;
          if (_endDate.isBefore(_startDate)) {
            _startDate = _endDate;
          }
        }
        _clampDateRange();
      });
      _loadData();
    }
  }

  Future<List<int>> _generateExportBytes() async {
    final format = _selectedFormat.toLowerCase();
    if (format == 'pdf') {
      return await _exportService.generatePdf(
        farmName: widget.farmName,
        startDate: _startDate,
        endDate: _endDate,
        summary: _summary,
        logs: _logs,
      );
    } else if (format == 'excel') {
      return await _exportService.generateExcel(
        farmName: widget.farmName,
        startDate: _startDate,
        endDate: _endDate,
        summary: _summary,
        logs: _logs,
      );
    } else {
      // High-resolution image capture with graceful fallback to Canvas generator
      try {
        final boundary = _repaintBoundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
        if (boundary != null &&
            boundary.attached &&
            boundary.hasSize &&
            !boundary.size.isEmpty &&
            !boundary.debugNeedsPaint) {
          return await _exportService.captureBoundaryImage(boundary, pixelRatio: 3.0);
        }
      } catch (_) {
        // Fall through to canvas generator fallback
      }
      return await _exportService.generateImageReport(
        farmName: widget.farmName,
        startDate: _startDate,
        endDate: _endDate,
        summary: _summary,
        logs: _logs,
      );
    }
  }

  String _getFileExtension() {
    switch (_selectedFormat.toLowerCase()) {
      case 'pdf':
        return 'pdf';
      case 'excel':
        return 'xlsx';
      case 'image':
      default:
        return 'png';
    }
  }

  String _buildDefaultBaseFileName() {
    final startStr = DateFormat('yyyyMMdd').format(_startDate);
    final endStr = DateFormat('yyyyMMdd').format(_endDate);
    return 'milk_history_${startStr}_$endStr';
  }

  String _resolveFileName(String? customName) {
    final ext = _getFileExtension();
    if (customName == null || customName.trim().isEmpty) {
      return '${_buildDefaultBaseFileName()}.$ext';
    }
    var sanitized = customName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    if (sanitized.toLowerCase().endsWith('.$ext')) {
      return sanitized;
    }
    return '$sanitized.$ext';
  }

  Future<void> _handleShare({String? customFileName}) async {
    if (_logs.isEmpty) {
      AppToast.showInfo(context, 'No milk records found for the selected date range.');
      return;
    }

    final RenderBox? box = context.findRenderObject() as RenderBox?;
    final origin = box != null ? (box.localToGlobal(Offset.zero) & box.size) : null;

    setState(() => _isExporting = true);
    try {
      final bytes = await _generateExportBytes();
      final fileName = _resolveFileName(customFileName);
      final subject = '${widget.farmName} Milk History (${dateFormat.format(_startDate)} - ${dateFormat.format(_endDate)})';
      await _exportService.shareFile(
        fileName: fileName,
        bytes: bytes,
        subject: subject,
        sharePositionOrigin: origin,
      );
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Share failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _handleDownload({String? customFileName}) async {
    if (_logs.isEmpty) {
      AppToast.showInfo(context, 'No milk records found for the selected date range.');
      return;
    }

    setState(() => _isExporting = true);
    try {
      final bytes = await _generateExportBytes();
      final fileName = _resolveFileName(customFileName);
      final File savedFile = await _exportService.saveFile(fileName: fileName, bytes: bytes);
      if (mounted) {
        final displayName = savedFile.path.split(Platform.pathSeparator).last.split('/').last;
        final isImage = fileName.toLowerCase().endsWith('.png');
        if (isImage) {
          AppToast.showSuccess(context, 'Image saved to Gallery: $displayName');
        } else {
          AppToast.showSuccess(context, 'Report saved: $displayName');
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Download failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _openFileNameDialog() async {
    if (_logs.isEmpty) {
      AppToast.showInfo(context, 'No milk records found for the selected date range.');
      return;
    }

    final ext = _getFileExtension();
    final defaultBaseName = _buildDefaultBaseFileName();
    final controller = TextEditingController(text: defaultBaseName);

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: AppColors.mintCardBg,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.description_outlined,
                        color: AppColors.deepGreen,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Export File Name',
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.darkForest,
                            ),
                          ),
                          Text(
                            'Format: ${_selectedFormat.toUpperCase()} (.$ext)',
                            style: const TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: AppColors.textGrey),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  'Customize the file name or save with the proposed name:',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 12,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: false,
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.backspaceBg,
                    labelText: 'File Name',
                    labelStyle: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 12,
                      color: AppColors.textGrey,
                    ),
                    suffixText: '.$ext',
                    suffixStyle: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.deepGreen,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.deepGreen, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          final chosen = controller.text;
                          Navigator.of(dialogContext).pop();
                          _handleShare(customFileName: chosen);
                        },
                        icon: const Icon(Icons.share_outlined, size: 16),
                        label: const Text('Share'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.darkForest,
                          side: const BorderSide(color: AppColors.darkForest),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          textStyle: const TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final chosen = controller.text;
                          Navigator.of(dialogContext).pop();
                          _handleDownload(customFileName: chosen);
                        },
                        icon: const Icon(Icons.download_outlined, size: 16),
                        label: const Text('Save Report'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.darkForest,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          textStyle: const TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final daysSpan = _endDate.difference(_startDate).inDays.abs() + 1;
    final bool hasData = _logs.isNotEmpty;

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
                  const SizedBox(width: 36),
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

            // Scrollable Body (Wrapped with RepaintBoundary for high-res PNG export)
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.deepGreen))
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          RepaintBoundary(
                            key: _repaintBoundaryKey,
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
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              widget.farmName.toUpperCase(),
                                              style: TextStyle(
                                                fontFamily: 'Plus Jakarta Sans',
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.sageGreen.withValues(alpha: 0.9),
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            const Text(
                                              'Milk Export Report',
                                              style: TextStyle(
                                                fontFamily: 'Plus Jakarta Sans',
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                            Text(
                                              '${dateFormat.format(_startDate)} - ${dateFormat.format(_endDate)}',
                                              style: const TextStyle(
                                                fontFamily: 'Plus Jakarta Sans',
                                                fontSize: 10,
                                                color: Colors.white70,
                                              ),
                                            ),
                                          ],
                                        ),
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
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Total Milk Produced',
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
                                                    numberFormat.format(_summary.totalQuantity),
                                                    style: const TextStyle(
                                                      fontFamily: 'Plus Jakarta Sans',
                                                      fontSize: 30,
                                                      fontWeight: FontWeight.w800,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  const Text(
                                                    'Kg',
                                                    style: TextStyle(
                                                      fontFamily: 'Plus Jakarta Sans',
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.w600,
                                                      color: AppColors.sageGreen,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          const Text(
                                            'Gross Earnings',
                                            style: TextStyle(
                                              fontFamily: 'Plus Jakarta Sans',
                                              fontSize: 12,
                                              color: Colors.white70,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerRight,
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.baseline,
                                              textBaseline: TextBaseline.alphabetic,
                                              children: [
                                                const Text(
                                                  'PKR ',
                                                  style: TextStyle(
                                                    fontFamily: 'Plus Jakarta Sans',
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.sageGreen,
                                                  ),
                                                ),
                                                Text(
                                                  numberFormat.format(_summary.grossRevenue),
                                                  style: const TextStyle(
                                                    fontFamily: 'Plus Jakarta Sans',
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.w800,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
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
                                                numberFormat.format(_summary.morningQuantity),
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
                                                numberFormat.format(_summary.eveningQuantity),
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
                                                numberFormat.format(_summary.dailyAvg),
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
                                    '${_logs.length} Logs',
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

                            // Breakdown List or Validation Notice
                            if (_logs.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.info_outline,
                                      size: 32,
                                      color: AppColors.textGrey,
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'No records match this date range',
                                      style: TextStyle(
                                        fontFamily: 'Plus Jakarta Sans',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.darkForest,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Zero milk records found between ${dateFormat.format(_startDate)} and ${dateFormat.format(_endDate)}. Select another range to export.',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontFamily: 'Plus Jakarta Sans',
                                        fontSize: 12,
                                        color: AppColors.textGrey,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              ..._logs.map((log) => _buildBreakdownRow(log)),
                          ],
                        ),
                      ),

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
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
            ),

            // Bottom Action Bar (Export triggers disabled / blocked when zero records match date range)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: AppTheme.softShadow,
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (!hasData || _isExporting) ? null : _openFileNameDialog,
                  icon: _isExporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.file_download_outlined, size: 20),
                  label: const Text('Generate File'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.darkForest,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    disabledForegroundColor: Colors.grey.shade500,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
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
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
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
                  if (log.amount > 0)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'PKR ${numberFormat.format(log.amount)}',
                        style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 8, fontWeight: FontWeight.w700, color: AppColors.deepGreen),
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
