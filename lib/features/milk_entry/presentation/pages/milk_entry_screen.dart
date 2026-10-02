import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/money_utils.dart';
import '../../../../core/utils/app_toast.dart';
import '../widgets/custom_numpad.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dodi_ledger/presentation/providers/dodi_provider.dart';
import '../../../dodi_ledger/data/models/dodi_model.dart';
import '../../../dodi_ledger/presentation/widgets/edit_buyer_sheet.dart';

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
  final TextEditingController _buyerSearchController = TextEditingController();
  String _buyerSearchQuery = '';
  int _buyerFilterIndex = 0; // 0 = All, 1 = Active, 2 = Binned
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
    
    _buyerSearchController.addListener(() {
      if (mounted) {
        setState(() {
          _buyerSearchQuery = _buyerSearchController.text.trim();
        });
      }
    });

    // Auto-fill rate if initialDodiId is provided and load deleted dodis for Binned tab
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final userId = auth.currentUser?.id ?? 0;
      final dodiProvider = Provider.of<DodiProvider>(context, listen: false);
      dodiProvider.loadDeletedDodis(userId);

      if (_selectedDodiId != null && widget.initialRatePaise == null) {
        _populateRateForDodi(_selectedDodiId!);
      }
    });
  }

  @override
  void dispose() {
    _rateController.dispose();
    _loadTagController.dispose();
    _buyerSearchController.dispose();
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

    try { HapticFeedback.mediumImpact(); } catch (_) {}
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
    if (dodiProvider.dodis.isEmpty && dodiProvider.deletedDodis.isEmpty) {
      body = _buildZeroDodiState();
    } else if (_selectedDodiId == null) {
      body = _buildDodiSelectionState(dodiProvider);
    } else {
      body = _buildNumpadState();
    }

    return Scaffold(
      backgroundColor: AppColors.creamBg,
      resizeToAvoidBottomInset: true,
      appBar: _MilkEntryAppBar(
        cowLabel: _selectedDodiId != null 
          ? (dodiProvider.dodis.where((d) => d.id == _selectedDodiId).firstOrNull?.name ?? 
             dodiProvider.deletedDodis.where((d) => d.id == _selectedDodiId).firstOrNull?.name ?? widget.cowLabel)
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
    final authUser = Provider.of<AuthProvider>(context, listen: false).currentUser;
    final userId = authUser?.id ?? 0;
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
          'Add a buyer to start recording milk entries for your daily collection.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: AppColors.textGrey),
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: () => _openAddBuyerSheet(context, userId),
          icon: const Icon(Icons.person_add_rounded, size: 20),
          label: const Text('+ Register & Add New Buyer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.deepGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
        ),
      ],
    );
  }

  Widget _buildDodiSelectionState(DodiProvider dodiProvider) {
    final authUser = Provider.of<AuthProvider>(context, listen: false).currentUser;
    final userId = authUser?.id ?? 0;

    final activeItems = dodiProvider.dodis.map((d) => _BuyerListItem(dodi: d, isBinned: false)).toList();
    final binnedItems = dodiProvider.deletedDodis.map((d) => _BuyerListItem(dodi: d, isBinned: true)).toList();

    List<_BuyerListItem> displayedList;
    if (_buyerFilterIndex == 1) {
      displayedList = activeItems;
    } else if (_buyerFilterIndex == 2) {
      displayedList = binnedItems;
    } else {
      displayedList = [...activeItems, ...binnedItems];
    }

    if (_buyerSearchQuery.isNotEmpty) {
      final query = _buyerSearchQuery.toLowerCase();
      displayedList = displayedList.where((item) {
        final nameMatch = item.dodi.name.toLowerCase().contains(query);
        final phoneMatch = item.dodi.phone != null && item.dodi.phone!.contains(query);
        return nameMatch || phoneMatch;
      }).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        // Search Bar
        TextField(
          controller: _buyerSearchController,
          style: const TextStyle(fontSize: 15, color: AppColors.textDark),
          decoration: InputDecoration(
            hintText: 'Search buyer name or phone...',
            hintStyle: const TextStyle(color: AppColors.textGrey, fontSize: 14),
            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.deepGreen, size: 22),
            suffixIcon: _buyerSearchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textGrey, size: 20),
                    onPressed: () => _buyerSearchController.clear(),
                  )
                : null,
            filled: true,
            fillColor: AppColors.cardWhite,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.cardSubtle, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.deepGreen, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Filter Chips Bar
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                label: 'All (${activeItems.length + binnedItems.length})',
                isSelected: _buyerFilterIndex == 0,
                onTap: () => setState(() => _buyerFilterIndex = 0),
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: 'Active (${activeItems.length})',
                isSelected: _buyerFilterIndex == 1,
                onTap: () => setState(() => _buyerFilterIndex = 1),
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: 'Binned (${binnedItems.length})',
                isSelected: _buyerFilterIndex == 2,
                onTap: () => setState(() => _buyerFilterIndex = 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Buyer Cards List
        Expanded(
          child: displayedList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.person_search_rounded, size: 48, color: AppColors.textGrey),
                      const SizedBox(height: 12),
                      Text(
                        _buyerSearchQuery.isNotEmpty ? 'No buyers found for "$_buyerSearchQuery"' : 'No buyers in this category',
                        style: const TextStyle(fontSize: 15, color: AppColors.textGrey, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: displayedList.length,
                  itemBuilder: (context, index) {
                    final item = displayedList[index];
                    final dodi = item.dodi;
                    final isBinned = item.isBinned;

                    return Card(
                      color: isBinned ? const Color(0xFFF1F5F9) : AppColors.cardWhite,
                      elevation: isBinned ? 0 : 1,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: isBinned
                            ? const BorderSide(color: Color(0xFFE2E8F0), width: 1)
                            : BorderSide.none,
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        leading: CircleAvatar(
                          backgroundColor: isBinned ? const Color(0xFFCBD5E1) : AppColors.cardSubtle,
                          child: Icon(
                            isBinned ? Icons.archive_outlined : Icons.person_rounded,
                            color: isBinned ? AppColors.textGrey : AppColors.deepGreen,
                            size: 22,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                dodi.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isBinned ? AppColors.textGrey : AppColors.textDark,
                                ),
                              ),
                            ),
                            if (isBinned)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Binned',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textGrey,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          'Rate: ${AppStrings.currency} ${MoneyUtils.formatPaiseToRupees(dodi.defaultRatePaise)}/${AppStrings.weightUnit}${dodi.phone != null && dodi.phone!.isNotEmpty ? " • ${dodi.phone}" : ""}',
                          style: TextStyle(
                            fontSize: 13,
                            color: isBinned ? AppColors.textGrey.withValues(alpha: 0.8) : AppColors.textGrey,
                          ),
                        ),
                        trailing: Icon(
                          isBinned ? Icons.restore_rounded : Icons.chevron_right_rounded,
                          color: isBinned ? AppColors.deepGreen : AppColors.sageGreen,
                          size: 22,
                        ),
                        onTap: () {
                          if (isBinned) {
                            _showRestoreConfirmationDialog(context, dodi, userId, dodiProvider);
                          } else {
                            setState(() {
                              _selectedDodiId = dodi.id;
                            });
                            _populateRateForDodi(dodi.id!);
                          }
                        },
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 10),
        // Persistent "+ Register & Add New Buyer" Button
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () => _openAddBuyerSheet(context, userId),
            icon: const Icon(Icons.person_add_rounded, size: 20),
            label: const Text(
              '+ Register & Add New Buyer',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.deepGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
              elevation: 2,
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.deepGreen : AppColors.cardWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.deepGreen : AppColors.cardSubtle,
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.deepGreen.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textDark,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showRestoreConfirmationDialog(
    BuildContext context,
    DodiModel dodi,
    int userId,
    DodiProvider dodiProvider,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.restore_rounded, color: AppColors.deepGreen, size: 26),
              SizedBox(width: 10),
              Text('Restore Buyer?'),
            ],
          ),
          content: Text(
            '"${dodi.name}" is currently in the Bin. Would you like to restore this buyer to Active so you can select them for milk entry?',
            style: const TextStyle(fontSize: 15, color: AppColors.textDark),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textGrey)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                final success = await dodiProvider.restoreDodi(dodi.id!, userId);
                if (mounted && success) {
                  setState(() {
                    _selectedDodiId = dodi.id;
                  });
                  _populateRateForDodi(dodi.id!);
                  if (mounted) {
                    AppToast.showSuccess(this.context, '${dodi.name} restored to active buyers');
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Restore & Select'),
            ),
          ],
        );
      },
    );
  }

  void _openAddBuyerSheet(BuildContext context, int userId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditBuyerSheet(
        dodi: DodiModel(
          userId: userId,
          name: '',
          defaultRatePaise: 6000,
        ),
        userId: userId,
      ),
    );
  }

  Widget _buildNumpadState() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                _QuantityDisplay(value: _displayValue),
                const SizedBox(height: 10),
                _buildAuxiliaryCards(),
                const SizedBox(height: 10),
                _SessionToggle(
                  selected: _session,
                  onChanged: (s) {
                    try { HapticFeedback.selectionClick(); } catch (_) {}
                    setState(() => _session = s);
                  },
                ),
                const SizedBox(height: 10),
                CustomNumpad(onKeyTap: _handleKey),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 12),
            child: _SaveButton(onTap: _handleSave),
          ),
        ),
      ],
    );
  }

  Widget _buildAuxiliaryCards() {
    final scale = MediaQuery.textScalerOf(context).scale(1.0);
    final width = MediaQuery.of(context).size.width;
    final isStacked = scale > 1.3 || width < 360;

    Widget buildRateCard() {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.mintCardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x1A065F46), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'RATE (RS/KG) *',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xB3064E3B),
                    letterSpacing: 0.5,
                  ),
                ),
                Icon(Icons.edit_outlined, size: 13, color: Color(0xB3064E3B)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Text(
                  'Rs',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF065F46),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: TextField(
                    controller: _rateController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkForest,
                      letterSpacing: -0.3,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    Widget buildLoadTagCard() {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.mintCardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x1A065F46), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'LOAD TAG *',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xB3064E3B),
                    letterSpacing: 0.5,
                  ),
                ),
                Icon(Icons.local_shipping_outlined, size: 13, color: Color(0xB3064E3B)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _loadTagController,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkForest,
                      letterSpacing: -0.3,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (isStacked) {
      return Column(
        children: [
          SizedBox(width: double.infinity, child: buildRateCard()),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: buildLoadTagCard()),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: buildRateCard()),
        const SizedBox(width: 10),
        Expanded(child: buildLoadTagCard()),
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
  const _MilkEntryAppBar({
    required this.cowLabel,
    required this.selectedDate,
    required this.onDateTap,
    this.showDateChip = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.creamBg,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Close button with 48px tap area & 40px visual container
          SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: InkWell(
                borderRadius: BorderRadius.circular(9999),
                onTap: () {
                  try { HapticFeedback.lightImpact(); } catch (_) {}
                  FocusScope.of(context).unfocus();
                  if (ModalRoute.of(context)?.isCurrent == true) {
                    Navigator.of(context).pop();
                  }
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.cardWhite,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0x7CE7E5E4), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: AppColors.darkForest,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Center Buyer Name Stack with Ellipsis Protection
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'MILK BUYER',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xB3065F46),
                    letterSpacing: 0.5,
                    height: 1.2,
                  ),
                ),
                Text(
                  cowLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkForest,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Right Date Badge Pill
          if (showDateChip)
            InkWell(
              onTap: onDateTap,
              borderRadius: BorderRadius.circular(9999),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0x99D8F3DC),
                  borderRadius: BorderRadius.circular(9999),
                  border: Border.all(color: const Color(0xCCA7F3D0), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.darkForest),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('yyyy-MM-dd').format(selectedDate),
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        color: AppColors.darkForest,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            const SizedBox(width: 48),
        ],
      ),
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
      constraints: const BoxConstraints(minHeight: 125.5),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x0D064E3B), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0D1B4332),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            top: -10,
            child: Opacity(
              opacity: 0.03,
              child: const Icon(
                Icons.scale_rounded,
                size: 110,
                color: AppColors.darkForest,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'WEIGHT METRIC',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0x99065F46),
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF8ED),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFD8F3DC), width: 1),
                    ),
                    child: const Text(
                      'KG',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkForest,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: intPart,
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              color: AppColors.darkForest,
                              fontSize: 48,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -1.2,
                              height: 1.0,
                            ),
                          ),
                          if (hasDecimal)
                            TextSpan(
                              text: decPart,
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                color: Color(0xFFA8A29E),
                                fontSize: 48,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -1.2,
                                height: 1.0,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'kg',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        color: Color(0xFFA8A29E),
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Touchpad entry ready',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFA8A29E),
                ),
              ),
            ],
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
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xE6FFFFFF),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: const Color(0xCCE7E5E4), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
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
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1B4332) : Colors.transparent,
            borderRadius: BorderRadius.circular(9999),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF1B4332).withValues(alpha: 0.30),
                      blurRadius: 8,
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
                size: 16,
                color: isSelected ? Colors.white : const Color(0xFF57534E),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  color: isSelected ? Colors.white : const Color(0xFF57534E),
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
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
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      height: 56,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1B4332),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9999),
          ),
          shadowColor: const Color(0xFF1B4332).withValues(alpha: 0.35),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.20),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              AppStrings.saveEntry,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BuyerListItem {
  final DodiModel dodi;
  final bool isBinned;
  _BuyerListItem({required this.dodi, required this.isBinned});
}

