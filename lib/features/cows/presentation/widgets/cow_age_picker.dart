import 'package:flutter/cupertino.dart';

import '../../../../core/theme/app_theme.dart';

/// A 3-wheel picker for tracking a cow's age in Years, Months, and Days.
/// Returns the selected (years, months, days) via [onAgeChanged].
class CowAgePicker extends StatefulWidget {
  final int initialYears;
  final int initialMonths;
  final int initialDays;
  final void Function(int years, int months, int days) onAgeChanged;

  const CowAgePicker({
    super.key,
    this.initialYears = 0,
    this.initialMonths = 0,
    this.initialDays = 0,
    required this.onAgeChanged,
  });

  @override
  State<CowAgePicker> createState() => _CowAgePickerState();
}

class _CowAgePickerState extends State<CowAgePicker> {
  late int _selectedYears;
  late int _selectedMonths;
  late int _selectedDays;

  @override
  void initState() {
    super.initState();
    _selectedYears = widget.initialYears;
    _selectedMonths = widget.initialMonths;
    _selectedDays = widget.initialDays;
  }

  void _notifyChange() {
    widget.onAgeChanged(_selectedYears, _selectedMonths, _selectedDays);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Age (Optional)',
          style: TextStyle(
            color: AppColors.textDark,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.bgGrey,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDDDDE0)),
          ),
          child: Row(
            children: [
              _buildWheel(
                label: 'Years',
                itemCount: 30, // 0 to 29 years
                initialItem: _selectedYears,
                onChanged: (val) {
                  _selectedYears = val;
                  _notifyChange();
                },
              ),
              _buildWheel(
                label: 'Months',
                itemCount: 13, // 0 to 12 months
                initialItem: _selectedMonths,
                onChanged: (val) {
                  _selectedMonths = val;
                  _notifyChange();
                },
              ),
              _buildWheel(
                label: 'Days',
                itemCount: 32, // 0 to 31 days
                initialItem: _selectedDays,
                onChanged: (val) {
                  _selectedDays = val;
                  _notifyChange();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWheel({
    required String label,
    required int itemCount,
    required int initialItem,
    required ValueChanged<int> onChanged,
  }) {
    return Expanded(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textGrey,
              ),
            ),
          ),
          Expanded(
            child: CupertinoPicker(
              scrollController: FixedExtentScrollController(initialItem: initialItem),
              itemExtent: 32.0,
              onSelectedItemChanged: onChanged,
              children: List<Widget>.generate(itemCount, (int index) {
                return Center(
                  child: Text(
                    index.toString(),
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textDark,
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
