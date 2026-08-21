import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_toast.dart';
import '../../data/models/cow_model.dart';
import '../providers/cow_provider.dart';
import '../widgets/cow_age_picker.dart';

class EditCowSheet extends StatefulWidget {
  final CowModel cow;
  const EditCowSheet({super.key, required this.cow});

  @override
  State<EditCowSheet> createState() => _EditCowSheetState();
}

class _EditCowSheetState extends State<EditCowSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _tagController;
  late final TextEditingController _nameController;
  late String _selectedStatus;
  DateTime? _matingDate;
  bool _saving = false;
  String? _tagError;
  int _ageYears = 0;
  int _ageMonths = 0;
  int _ageDays = 0;

  @override
  void initState() {
    super.initState();
    _tagController = TextEditingController(text: widget.cow.tagNumber);
    _nameController = TextEditingController(text: widget.cow.name ?? '');
    _selectedStatus = widget.cow.status;
    if (widget.cow.matingDate != null && widget.cow.matingDate!.isNotEmpty) {
      _matingDate = DateTime.tryParse(widget.cow.matingDate!);
    }

    if (widget.cow.estimatedBirthDate != null && widget.cow.estimatedBirthDate!.isNotEmpty) {
      try {
        final birthDate = DateTime.parse(widget.cow.estimatedBirthDate!);
        final totalDays = DateTime.now().difference(birthDate).inDays;
        if (totalDays >= 0) {
          final totalMonths = (totalDays / 30.44).floor();
          _ageYears = totalMonths ~/ 12;
          _ageMonths = totalMonths % 12;
          _ageDays = totalDays - (totalMonths * 30.44).round();
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _tagController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if ((_selectedStatus == 'PREGNANT' || _selectedStatus == 'DRY') && _matingDate == null) {
      AppToast.showError(context, 'Mating Date is required for pregnant cows.');
      return;
    }

    final tagText = _tagController.text.trim();
    final cowProvider = Provider.of<CowProvider>(context, listen: false);
    
    final exists = cowProvider.isTagTaken(tagText, excludeCowId: widget.cow.id);
    if (exists) {
      setState(() => _tagError = 'Tag "$tagText" is already in use.');
      return;
    } else {
      setState(() => _tagError = null);
    }

    setState(() => _saving = true);

    String? estimatedBirthDateStr;
    if (_ageYears > 0 || _ageMonths > 0 || _ageDays > 0) {
      final today = DateTime.now();
      final birthDate = DateTime(today.year - _ageYears, today.month - _ageMonths, today.day - _ageDays);
      estimatedBirthDateStr = "${birthDate.year.toString().padLeft(4, '0')}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}";
    }

    int calculatedFlag;
    if (widget.cow.hasLactatedBefore == 1) {
      if (_selectedStatus == 'HEIFER' || _selectedStatus == 'BRED_HEIFER') {
        calculatedFlag = 0; // Allow typo correction
      } else {
        calculatedFlag = 1; // Preserve locked status
      }
    } else {
      calculatedFlag = (_selectedStatus == 'MILKING' || _selectedStatus == 'PREGNANT' || _selectedStatus == 'DRY') ? 1 : 0;
    }

    final success = await cowProvider.updateCowGeneral(
      userId: widget.cow.userId,
      cowId: widget.cow.id!,
      tagNumber: _tagController.text.trim(),
      name: _nameController.text.trim(),
      status: _selectedStatus,
      matingDate: _matingDate != null ? "${_matingDate!.year.toString().padLeft(4, '0')}-${_matingDate!.month.toString().padLeft(2, '0')}-${_matingDate!.day.toString().padLeft(2, '0')}" : null,
      hasLactatedBefore: calculatedFlag,
      estimatedBirthDate: estimatedBirthDateStr,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (success) {
      Navigator.of(context).pop();
      AppToast.showSuccess(context, 'Cow ${_tagController.text.trim()} updated.');
    } else {
      final err = cowProvider.errorMessage;
      AppToast.showError(context, err ?? 'Failed to update cow.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      margin: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            const Text(
              'Edit Cow',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 20),

            // Tag field
            TextFormField(
              controller: _tagController,
              onChanged: (val) {
                if (_tagError != null) setState(() => _tagError = null);
              },
              decoration: InputDecoration(
                labelText: 'Tag Number *',
                prefixIcon: const Icon(Icons.tag_rounded, size: 20),
                errorText: _tagError,
              ),
              textCapitalization: TextCapitalization.characters,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Tag number is required' : null,
            ),
            const SizedBox(height: 14),

            // Name field
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name (optional)',
                prefixIcon: Icon(Icons.pets_rounded, size: 20),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 14),

            // Status Selector (Adult Slider + Heifer/Bred Heifer Pills)
            _CowStatusSelector(
              selectedStatus: _selectedStatus,
              onStatusChanged: (val) {
                setState(() {
                  _selectedStatus = val;
                  if (val != 'PREGNANT' && val != 'DRY' && val != 'BRED_HEIFER') {
                    _matingDate = null;
                  }
                });
              },
            ),
            if (_selectedStatus == 'PREGNANT' || _selectedStatus == 'DRY' || _selectedStatus == 'BRED_HEIFER') ...[
              const SizedBox(height: 14),
              InkWell(
                onTap: () async {
                  final selected = await showDatePicker(
                    context: context,
                    initialDate: _matingDate ?? DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now(),
                  );
                  if (selected != null) {
                    setState(() => _matingDate = selected);
                  }
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: _selectedStatus == 'DRY' ? 'Dry-Off Date *' : 'Mating Date *',
                    prefixIcon: Icon(
                      _selectedStatus == 'DRY' ? Icons.bedtime_outlined : Icons.calendar_today_rounded,
                      size: 20,
                    ),
                  ),
                  child: Text(
                    _matingDate != null 
                        ? "${_matingDate!.year}-${_matingDate!.month.toString().padLeft(2, '0')}-${_matingDate!.day.toString().padLeft(2, '0')}"
                        : 'Select Date',
                    style: TextStyle(
                      color: _matingDate != null ? AppColors.textDark : AppColors.textGrey,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _selectedStatus == 'DRY' 
                    ? 'Date cow was dried off for pre-calving rest' 
                    : 'Auto-calculates expected calving date (+283 days)',
                style: const TextStyle(color: AppColors.textGrey, fontSize: 12),
              ),
              if (_matingDate != null && DateTime.now().difference(_matingDate!).inDays > 300) ...[
                const SizedBox(height: 8),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.warningRed),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'This date is over 10 months ago — please confirm this is correct.',
                        style: TextStyle(color: AppColors.warningRed, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ],
            const SizedBox(height: 14),
            CowAgePicker(
              initialYears: _ageYears,
              initialMonths: _ageMonths,
              initialDays: _ageDays,
              onAgeChanged: (y, m, d) {
                _ageYears = y;
                _ageMonths = m;
                _ageDays = d;
              },
            ),
            const SizedBox(height: 28),
            // Save button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text('Save Cow'),
              ),
            ),
          ],
        ),
      )),
    );
  }
}

// ---------------------------------------------------------------------------
// Custom Status Selector (Adult Slidable Toggle + Young Cattle Pills)
// ---------------------------------------------------------------------------
class _CowStatusSelector extends StatelessWidget {
  final String selectedStatus;
  final ValueChanged<String> onStatusChanged;

  const _CowStatusSelector({
    required this.selectedStatus,
    required this.onStatusChanged,
  });

  bool get isAdult => selectedStatus == 'MILKING' || selectedStatus == 'PREGNANT' || selectedStatus == 'DRY';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Status *',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (isAdult)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.sageTint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'ADULT COW',
                  style: TextStyle(
                    color: AppColors.deepGreen,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        // Row 1: Adult Slidable Segmented Control
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isAdult ? AppColors.cardSubtle : const Color(0xFFF0F0F4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isAdult ? AppColors.deepGreen.withValues(alpha: 0.4) : const Color(0xFFE5E5EA),
              width: isAdult ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              _SegmentTile(
                label: 'Milking',
                isSelected: selectedStatus == 'MILKING',
                onTap: () => onStatusChanged('MILKING'),
              ),
              _SegmentTile(
                label: 'Pregnant',
                isSelected: selectedStatus == 'PREGNANT',
                onTap: () => onStatusChanged('PREGNANT'),
              ),
              _SegmentTile(
                label: 'Dry',
                isSelected: selectedStatus == 'DRY',
                onTap: () => onStatusChanged('DRY'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Row 2: Young Cattle Pills (Heifer & Bred Heifer)
        Row(
          children: [
            Expanded(
              child: _PillChip(
                label: 'Heifer',
                isSelected: selectedStatus == 'HEIFER',
                onTap: () => onStatusChanged('HEIFER'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PillChip(
                label: 'Bred Heifer',
                isSelected: selectedStatus == 'BRED_HEIFER',
                onTap: () => onStatusChanged('BRED_HEIFER'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SegmentTile extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SegmentTile({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.deepGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.deepGreen.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.textDark,
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _PillChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PillChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.deepGreen : AppColors.cardWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.deepGreen : const Color(0xFFE0E0E5),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.deepGreen.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textDark,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
