import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_toast.dart';
import '../providers/cow_provider.dart';

class LogYieldsScreen extends StatefulWidget {
  const LogYieldsScreen({super.key});

  @override
  State<LogYieldsScreen> createState() => _LogYieldsScreenState();
}

class _LogYieldsScreenState extends State<LogYieldsScreen> {
  DateTime _selectedDate = DateTime.now();
  final Map<int, TextEditingController> _morningControllers = {};
  final Map<int, TextEditingController> _eveningControllers = {};
  bool _isSaving = false;

  @override
  void dispose() {
    for (var c in _morningControllers.values) { c.dispose(); }
    for (var c in _eveningControllers.values) { c.dispose(); }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(), // Only allow backwards
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.deepGreen,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        // Clearing inputs when date changes to prevent accidental wrong-day saving
        _morningControllers.clear();
        _eveningControllers.clear();
      });
    }
  }

  Future<void> _saveAll() async {
    setState(() => _isSaving = true);
    final provider = Provider.of<CowProvider>(context, listen: false);
    
    final dateStr = "${_selectedDate.year.toString().padLeft(4, '0')}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
    
    bool hasErrors = false;
    
    for (var cow in provider.milkingCows) {
      final morningText = _morningControllers[cow.id]?.text.trim() ?? '';
      final eveningText = _eveningControllers[cow.id]?.text.trim() ?? '';
      
      if (morningText.isEmpty && eveningText.isEmpty) continue;

      int? morningGrams;
      int? eveningGrams;
      
      if (morningText.isNotEmpty) {
        final val = double.tryParse(morningText);
        if (val != null) morningGrams = (val * 1000).toInt();
      }
      if (eveningText.isNotEmpty) {
        final val = double.tryParse(eveningText);
        if (val != null) eveningGrams = (val * 1000).toInt();
      }

      if (morningGrams != null || eveningGrams != null) {
        final success = await provider.logDailyYield(
          cowId: cow.id!,
          date: dateStr,
          morningGrams: morningGrams,
          eveningGrams: eveningGrams,
        );
        if (!success) hasErrors = true;
      }
    }

    setState(() => _isSaving = false);

    if (!mounted) return;
    
    if (hasErrors) {
      AppToast.showError(context, 'Saved with some errors.');
    } else {
      AppToast.showSuccess(context, 'Yields saved successfully!');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CowProvider>(context);
    
    if (provider.isRollupRunning) {
      return Scaffold(
        backgroundColor: AppColors.bgGrey,
        appBar: AppBar(title: const Text('Log Daily Yields')),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.deepGreen),
              SizedBox(height: 16),
              Text('Optimizing data...', style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      );
    }

    final cows = provider.milkingCows;
    final dateDisplay = "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}";

    return Scaffold(
      backgroundColor: AppColors.bgGrey,
      appBar: AppBar(
        title: const Text('Log Daily Yields', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.cardWhite,
        iconTheme: const IconThemeData(color: AppColors.textDark),
        elevation: 1,
        actions: [
          if (_isSaving)
            const Center(child: Padding(padding: EdgeInsets.only(right: 16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.deepGreen))))
          else
            TextButton(
              onPressed: cows.isEmpty ? null : _saveAll,
              child: const Text('SAVE', style: TextStyle(color: AppColors.deepGreen, fontWeight: FontWeight.bold)),
            )
        ],
      ),
      body: Column(
        children: [
          // Date Picker Header
          Container(
            color: AppColors.cardWhite,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Date', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                InkWell(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.bgGrey,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: AppColors.textGrey),
                        const SizedBox(width: 8),
                        Text(dateDisplay, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: cows.isEmpty
                ? const Center(child: Text("No milking cows available.", style: TextStyle(color: AppColors.textGrey)))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: cows.length,
                    itemBuilder: (context, index) {
                      final cow = cows[index];
                      
                      _morningControllers.putIfAbsent(cow.id!, () => TextEditingController());
                      _eveningControllers.putIfAbsent(cow.id!, () => TextEditingController());
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.cardWhite,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE8F5E9),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      cow.tagNumber,
                                      style: const TextStyle(
                                        color: Color(0xFF00522A),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(cow.name ?? cow.tagNumber, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('☀️ Morning', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textGrey)),
                                        const SizedBox(height: 6),
                                        TextField(
                                          controller: _morningControllers[cow.id],
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          decoration: const InputDecoration(
                                            hintText: '0.0',
                                            suffixText: 'kg',
                                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('🌙 Evening', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textGrey)),
                                        const SizedBox(height: 6),
                                        TextField(
                                          controller: _eveningControllers[cow.id],
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          decoration: const InputDecoration(
                                            hintText: '0.0',
                                            suffixText: 'kg',
                                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}



