import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/money_utils.dart';
import '../widgets/custom_numpad.dart';
import '../../../dodi_ledger/presentation/providers/dodi_provider.dart';
import '../../../dodi_ledger/data/models/dodi_model.dart';

// ---------------------------------------------------------------------------
// MilkEntryScreen
// ---------------------------------------------------------------------------
// The most important data-capture screen in the app. A farmer must be able
// to record a milk quantity with a single hand in poor lighting.
//
// This screen handles three states:
// 1. Zero-Dodi: Prompts the user to go to the Buyers tab.
// 2. Selection: Lets the user pick a Dodi if initialDodiId is null.
// 3. Numpad: Enters quantity and rate, and saves.
// ---------------------------------------------------------------------------

enum MilkSession { morning, evening }

class MilkEntryScreen extends StatefulWidget {
  final int? initialDodiId;
  final String cowLabel;
  final void Function(
    int dodiId,
    String buyerName,
    String quantity,
    String session,
    int ratePaise,
    String date,
    String loadTag,
  ) onSaveEntry;
  final MilkSession initialSession;
  final String? initialQuantity;
  final int? initialRatePaise;
  final DateTime? initialDate;

  const MilkEntryScreen({
    super.key,
    required this.onSaveEntry,
    this.initialDodiId,
    this.cowLabel = 'Record Milk',
    this.initialSession = MilkSession.morning,
    this.initialDate,
    this.initialQuantity,
    this.initialRatePaise,
  });

  @override
  State<MilkEntryScreen> createState() => _MilkEntryScreenState();
}

class _MilkEntryScreenState extends State<MilkEntryScreen> {
  String _displayValue = '0';
  late MilkSession _session;
  int? _selectedDodiId;
  final TextEditingController _rateController = TextEditingController();
  final TextEditingController _loadTagController = TextEditingController(text: 'Load 1');
  DateTime _selectedDate = DateTime.now();

  static const int _maxIntegerDigits = 5;
  static const int _maxDecimalDigits = 1;

  @override
  void initState() {
    super.initState();
    _selectedDodiId = widget.initialDodiId;
    _session = widget.initialSession;
    
    if (widget.initialDate != null) {
      _selectedDate = widget.initialDate!;
    }
    if (widget.initialQuantity != null) {
      _displayValue = widget.initialQuantity!;
    }
    if (widget.initialRatePaise != null) {
      _rateController.text = MoneyUtils.formatPaiseToRupees(widget.initialRatePaise!);
    }
    
    // Auto-fill rate if initialDodiId is provided
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_selectedDodiId != null && widget.initialRatePaise == null) {
        _populateRateForDodi(_selectedDodiId!);
      }
    });
  }

  @override
  void dispose() {
    _rateController.dispose();
    _loadTagController.dispose();
    super.dispose();
  }

  void _populateRateForDodi(int dodiId) {
    final dodiProvider = Provider.of<DodiProvider>(context, listen: false);
    final dodi = dodiProvider.dodis.where((d) => d.id == dodiId).firstOrNull;
    if (dodi != null) {
      _rateController.text = MoneyUtils.formatPaiseToRupees(dodi.defaultRatePaise);
    }
  }

  // ── Numpad key handling ────────────────────────────────────────────────

  void _handleKey(NumpadKey key) {
    setState(() {
      if (key == NumpadKey.backspace) {
        _handleBackspace();
      } else if (key == NumpadKey.decimal) {
        _handleDecimal();
      } else {
        _handleDigit(key.character!);
      }
    });
  }

  void _handleBackspace() {
    if (_displayValue.length <= 1) {
      _displayValue = '0';
    } else {
      _displayValue = _displayValue.substring(0, _displayValue.length - 1);
      if (_displayValue == '-') _displayValue = '0';
    }
  }

  void _handleDecimal() {
    if (_displayValue.contains('.')) return;
    _displayValue = '$_displayValue.';
  }

  void _handleDigit(String digit) {
    if (_displayValue == '0') {
      _displayValue = digit;
      return;
    }

    final dotIndex = _displayValue.indexOf('.');
    if (dotIndex == -1) {
      if (_displayValue.length < _maxIntegerDigits) {
        _displayValue = '$_displayValue$digit';
      }
    } else {
      final decimals = _displayValue.length - dotIndex - 1;
      if (decimals < _maxDecimalDigits) {
        _displayValue = '$_displayValue$digit';
      }
    }
  }

  // ── Save action ────────────────────────────────────────────────────────

  void _handleSave() {
    final sanitised = _displayValue.endsWith('.') ? '${_displayValue}0' : _displayValue;

    if (sanitised == '0') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a quantity before saving.'),
          backgroundColor: AppColors.warningRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }
    
    if (_rateController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a valid rate.'),
          backgroundColor: AppColors.warningRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    final int ratePaise = ((double.tryParse(_rateController.text.trim()) ?? 0.0) * 100).round();

    final dodiProvider = Provider.of<DodiProvider>(context, listen: false);
    final selectedDodi = dodiProvider.dodis.where((d) => d.id == _selectedDodiId).firstOrNull;

    HapticFeedback.mediumImpact();
    final tag = _loadTagController.text.trim().isEmpty ? 'Load 1' : _loadTagController.text.trim();
    widget.onSaveEntry(
      _selectedDodiId!,
      selectedDodi?.name ?? 'Unknown Buyer',
      sanitised,
      _session == MilkSession.morning ? 'MORNING' : 'EVENING',
      ratePaise,
      DateFormat('yyyy-MM-dd').format(_selectedDate),
      tag,
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────

  void _pickDate() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (pickedDate != null && mounted) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dodiProvider = Provider.of<DodiProvider>(context);

    Widget body;
    if (dodiProvider.dodis.isEmpty) {
      body = _buildZeroDodiState();
    } else if (_selectedDodiId == null) {
      body = _buildDodiSelectionState(dodiProvider.dodis);
    } else {
      body = _buildNumpadState();
    }

    return Scaffold(
      backgroundColor: AppColors.bgGrey,
      appBar: _MilkEntryAppBar(
        cowLabel: _selectedDodiId != null 
          ? (dodiProvider.dodis.where((d) => d.id == _selectedDodiId).firstOrNull?.name ?? widget.cowLabel)
          : 'Select Buyer',
        selectedDate: _selectedDate,
        onDateTap: _pickDate,
        showDateChip: _selectedDodiId != null,
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: body,
        ),
      ),
    );
  }

  Widget _buildZeroDodiState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.group_off_rounded, size: 64, color: AppColors.textGrey),
        const SizedBox(height: 16),
        const Text(
          'No buyers added yet',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark),
        ),
        const SizedBox(height: 8),
        const Text(
          'You need to add a buyer from the Buyers tab before recording milk.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: AppColors.textGrey),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop(2);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.deepGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
          child: const Text('Go to Buyers', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildDodiSelectionState(List<DodiModel> dodis) {
    return ListView.builder(
      itemCount: dodis.length,
      itemBuilder: (context, index) {
        final dodi = dodis[index];
        return Card(
          color: AppColors.cardWhite,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: const CircleAvatar(
              backgroundColor: AppColors.cardSubtle,
              child: Icon(Icons.person, color: AppColors.sageGreen),
            ),
            title: Text(dodi.name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)),
            subtitle: Text('Rate: ${AppStrings.currency} ${MoneyUtils.formatPaiseToRupees(dodi.defaultRatePaise)}/${AppStrings.weightUnit}', style: const TextStyle(color: AppColors.textGrey)),
            onTap: () {
              setState(() {
                _selectedDodiId = dodi.id;
              });
              _populateRateForDodi(dodi.id!);
            },
          ),
        );
      },
    );
  }

  Widget _buildNumpadState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        _QuantityDisplay(value: _displayValue),
        const SizedBox(height: 10),
        // Rate input field
        TextField(
          controller: _rateController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.deepGreen),
          decoration: AppTheme.filledInputDecoration(
            labelText: 'Rate (${AppStrings.currency}/${AppStrings.weightUnit}) *',
            prefixIcon: const Icon(Icons.attach_money_rounded, size: 20, color: AppColors.deepGreen),
          ),
        ),
        const SizedBox(height: 8),
        // Load Tag input field
        TextField(
          controller: _loadTagController,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark),
          decoration: AppTheme.filledInputDecoration(
            labelText: 'Load Tag / Label (e.g. Load 1, Tanker A) *',
            prefixIcon: const Icon(Icons.label_outline_rounded, size: 20, color: AppColors.deepGreen),
          ),
        ),
        const SizedBox(height: 10),
        _SessionToggle(
          selected: _session,
          onChanged: (s) {
            HapticFeedback.selectionClick();
            setState(() => _session = s);
          },
        ),
        const SizedBox(height: 10),
        Expanded(
          child: CustomNumpad(onKeyTap: _handleKey),
        ),
        const SizedBox(height: 12),
        _SaveButton(onTap: _handleSave),
        const SizedBox(height: 12),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _MilkEntryAppBar
// ---------------------------------------------------------------------------
class _MilkEntryAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String cowLabel;
  final DateTime selectedDate;
  final VoidCallback onDateTap;
  final bool showDateChip;
  const _MilkEntryAppBar({required this.cowLabel, required this.selectedDate, required this.onDateTap, this.showDateChip = true});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.bgGrey,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.lightImpact();
            FocusScope.of(context).unfocus();
            if (ModalRoute.of(context)?.isCurrent == true) {
              Navigator.of(context).pop();
            }
          },
          child: Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFFE5E5EA),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.close_rounded,
              color: AppColors.textDark,
              size: 20,
            ),
          ),
        ),
      ),
      title: Text(
        cowLabel,
        style: const TextStyle(
          color: AppColors.textDark,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),
      actions: [
        if (showDateChip)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: InkWell(
                onTap: onDateTap,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.sageTint,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: AppColors.deepGreen),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('yyyy-MM-dd').format(selectedDate),
                        style: const TextStyle(color: AppColors.deepGreen, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _QuantityDisplay
// ---------------------------------------------------------------------------
class _QuantityDisplay extends StatelessWidget {
  final String value;
  const _QuantityDisplay({required this.value});

  @override
  Widget build(BuildContext context) {
    final dotIndex = value.indexOf('.');
    final hasDecimal = dotIndex != -1;

    final intPart = hasDecimal ? value.substring(0, dotIndex) : value;
    final decPart = hasDecimal ? value.substring(dotIndex) : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.cardSubtle,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0E0E5), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppStrings.weightLabel,
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: intPart,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 64,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -3,
                      height: 1.0,
                    ),
                  ),
                  if (hasDecimal)
                    TextSpan(
                      text: decPart,
                      style: const TextStyle(
                        color: AppColors.textGrey,
                        fontSize: 64,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -3,
                        height: 1.0,
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
// _SessionToggle
// ---------------------------------------------------------------------------
class _SessionToggle extends StatelessWidget {
  final MilkSession selected;
  final ValueChanged<MilkSession> onChanged;

  const _SessionToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE8E8EE),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          _ToggleSegment(
            icon: Icons.wb_sunny_outlined,
            label: AppStrings.morning,
            isSelected: selected == MilkSession.morning,
            onTap: () => onChanged(MilkSession.morning),
          ),
          _ToggleSegment(
            icon: Icons.nightlight_round_outlined,
            label: AppStrings.evening,
            isSelected: selected == MilkSession.evening,
            onTap: () => onChanged(MilkSession.evening),
          ),
        ],
      ),
    );
  }
}

class _ToggleSegment extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleSegment({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.deepGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.deepGreen.withValues(alpha: 0.30),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : AppColors.textGrey,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textGrey,
                  fontSize: 15,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _SaveButton
// ---------------------------------------------------------------------------
class _SaveButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SaveButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.check_circle_outline_rounded, size: 22),
        label: const Text(AppStrings.saveEntry),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.deepGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}
