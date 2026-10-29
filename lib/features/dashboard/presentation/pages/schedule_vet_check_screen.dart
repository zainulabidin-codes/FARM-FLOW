import 'package:flutter/material.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_toast.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../cows/presentation/providers/cow_provider.dart';
import '../../data/models/vet_check_models.dart';
import '../providers/vet_check_provider.dart';

class ScheduleVetCheckScreen extends StatefulWidget {
  final int? userId;
  final int? cowId;
  final String? cowName;
  final String? cowTag;
  final String? shed;
  final List<VetDoctor>? doctors;
  final List<String>? presetReasons;

  const ScheduleVetCheckScreen({
    super.key,
    this.userId,
    this.cowId,
    this.cowName,
    this.cowTag,
    this.shed,
    this.doctors,
    this.presetReasons,
  });

  @override
  State<ScheduleVetCheckScreen> createState() => _ScheduleVetCheckScreenState();
}

class _ScheduleVetCheckScreenState extends State<ScheduleVetCheckScreen> {
  int? _selectedDoctorId;
  final Set<String> _selectedReasons = {};
  late List<String> _presetReasons;
  bool _scheduleFollowUp = false;

  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  DateTime? _followUpDate;

  // Selected cow state
  int? _selectedCowId;
  String? _selectedCowName;
  String? _selectedCowTag;
  String? _selectedShed;

  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _selectedTime = const TimeOfDay(hour: 10, minute: 30);
    _followUpDate = DateTime.now().add(const Duration(days: 7));

    _selectedCowId = widget.cowId;
    _selectedCowName = widget.cowName;
    _selectedCowTag = widget.cowTag;
    _selectedShed = widget.shed ?? 'A';

    _presetReasons = widget.presetReasons != null
        ? List<String>.from(widget.presetReasons!)
        : [
            'Routine Health Check',
            'Vaccination',
            'Mastitis Screen',
            'Pregnancy Check',
            'Deworming',
            'Injury / Lameness',
            'Post-Calving Check',
          ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initDefaultSelection();
    });
  }

  void _initDefaultSelection() {
    final cowProvider = Provider.of<CowProvider>(context, listen: false);
    final activeCows = cowProvider.cows.where((c) => c.isDeleted == 0).toList();

    if ((_selectedCowId == null || _selectedCowTag == null || _selectedCowTag == '---') && activeCows.isNotEmpty) {
      final firstCow = activeCows.first;
      setState(() {
        _selectedCowId = firstCow.id;
        _selectedCowName = firstCow.name ?? 'Cow #${firstCow.tagNumber}';
        _selectedCowTag = firstCow.tagNumber;
        _selectedShed = 'A';
      });
    }

    final vetProvider = Provider.of<VetCheckProvider>(context, listen: false);
    final docs = widget.doctors ?? vetProvider.doctors;
    if (_selectedDoctorId == null && docs.isNotEmpty) {
      final primary = docs.firstWhere((d) => d.isPrimary, orElse: () => docs.first);
      setState(() {
        _selectedDoctorId = primary.id;
      });
    }
  }

  int? get _currentDoctorId {
    if (_selectedDoctorId != null) return _selectedDoctorId;
    final vetProvider = Provider.of<VetCheckProvider>(context, listen: false);
    final docs = widget.doctors ?? vetProvider.doctors;
    if (docs.isNotEmpty) {
      return docs.firstWhere((d) => d.isPrimary, orElse: () => docs.first).id;
    }
    return null;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  int get _effectiveUserId {
    if (widget.userId != null) return widget.userId!;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    return auth.currentUser?.id ?? 1;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
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
        _selectedDate = picked;
        if (_scheduleFollowUp) {
          _followUpDate = picked.add(const Duration(days: 7));
        }
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
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
        _selectedTime = picked;
      });
    }
  }

  void _showChangeCowBottomSheet() {
    final cowProvider = Provider.of<CowProvider>(context, listen: false);
    final activeCows = cowProvider.cows.where((c) => c.isDeleted == 0).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        if (activeCows.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.info_outline, size: 48, color: AppColors.textGrey),
                const SizedBox(height: 12),
                const Text(
                  'No Cows in Herd',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please add a cow first before scheduling a checkup.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textGrey),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.darkForest,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Select Cow for Vet Check',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkForest,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: activeCows.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final cow = activeCows[index];
                      final isSelected = _selectedCowId == cow.id;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isSelected ? AppColors.darkForest : AppColors.sageTint,
                          child: Icon(
                            Icons.pets,
                            color: isSelected ? Colors.white : AppColors.deepGreen,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          cow.name?.isNotEmpty == true ? cow.name! : 'Cow #${cow.tagNumber}',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                            color: AppColors.darkForest,
                          ),
                        ),
                        subtitle: Text(
                          'Tag #${cow.tagNumber} • Status: ${cow.status}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: AppColors.darkForest)
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedCowId = cow.id;
                            _selectedCowName = cow.name ?? 'Cow #${cow.tagNumber}';
                            _selectedCowTag = cow.tagNumber;
                            _selectedShed = 'A';
                          });
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddDoctorDialog() {
    final nameCtrl = TextEditingController();
    final qualCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    bool isPrimary = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text(
                'Add Vet Doctor',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkForest,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      key: const Key('pick_doctor_from_contacts_button'),
                      onPressed: () async {
                        try {
                          final picker = FlutterNativeContactPicker();
                          final contact = await picker.selectContact();
                          if (contact != null) {
                            if (contact.fullName != null && contact.fullName!.isNotEmpty) {
                              nameCtrl.text = contact.fullName!;
                            }
                            final phone = contact.selectedPhoneNumber ??
                                (contact.phoneNumbers?.isNotEmpty == true
                                    ? contact.phoneNumbers!.first
                                    : null);
                            if (phone != null && phone.isNotEmpty) {
                              phoneCtrl.text = phone;
                            }
                            setDialogState(() {});
                          }
                        } catch (e) {
                          if (mounted) {
                            AppToast.showInfo(context, 'Could not access contacts: $e');
                          }
                        }
                      },
                      icon: const Icon(Icons.contacts_rounded, size: 18, color: AppColors.darkForest),
                      label: const Text(
                        'Select from Contacts',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkForest,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.darkForest.withValues(alpha: 0.3)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Doctor Name *',
                        hintText: 'e.g. Dr. John Doe',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: qualCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Qualification / Specialization',
                        hintText: 'e.g. DVM • Large Animal Specialist',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number *',
                        hintText: 'e.g. +92 300 1234567',
                      ),
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Set as Primary Vet',
                        style: TextStyle(fontSize: 14, fontFamily: 'Plus Jakarta Sans'),
                      ),
                      value: isPrimary,
                      activeColor: AppColors.darkForest,
                      onChanged: (val) => setDialogState(() => isPrimary = val ?? false),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textGrey)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    final phone = phoneCtrl.text.trim();
                    if (name.isEmpty || phone.isEmpty) {
                      AppToast.showError(context, 'Please enter doctor name and phone number.');
                      return;
                    }

                    final newDoctor = VetDoctor(
                      userId: _effectiveUserId,
                      name: name,
                      qualification: qualCtrl.text.trim(),
                      phone: phone,
                      isPrimary: isPrimary,
                    );

                    final vetProvider = Provider.of<VetCheckProvider>(context, listen: false);
                    final added = await vetProvider.addDoctor(newDoctor);

                    if (dialogCtx.mounted) {
                      Navigator.pop(dialogCtx);
                    }
                    if (!mounted) return;
                    if (added != null && added.id != null) {
                      setState(() {
                        _selectedDoctorId = added.id;
                      });
                      AppToast.showSuccess(context, 'Doctor added successfully!');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.darkForest,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Add Doctor'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteDoctor(VetDoctor doctor) {
    if (doctor.id == null) return;
    final displayName = doctor.name.startsWith('Dr') ? doctor.name : 'Dr. ${doctor.name}';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Doctor?',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontWeight: FontWeight.w700,
            color: AppColors.darkForest,
          ),
        ),
        content: Text(
          'Are you sure you want to permanently delete $displayName from your vet list?',
          style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 14,
            color: AppColors.textGrey,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textGrey)),
          ),
          ElevatedButton(
            key: const Key('confirm_delete_doctor_btn'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warningRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final vetProvider = Provider.of<VetCheckProvider>(context, listen: false);
              final success = await vetProvider.deleteDoctor(doctor.id!, _effectiveUserId);
              if (!mounted) return;
              if (success) {
                if (_selectedDoctorId == doctor.id) {
                  final remaining = vetProvider.doctors;
                  setState(() {
                    if (remaining.isNotEmpty) {
                      final primary = remaining.firstWhere((d) => d.isPrimary, orElse: () => remaining.first);
                      _selectedDoctorId = primary.id;
                    } else {
                      _selectedDoctorId = null;
                    }
                  });
                }
                AppToast.showSuccess(context, 'Doctor permanently deleted');
              } else {
                AppToast.showError(context, vetProvider.error ?? 'Failed to delete doctor');
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddCustomReasonDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Add Preset Reason',
          style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. Hoof Trimming',
            labelText: 'Reason',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textGrey)),
          ),
          ElevatedButton(
            onPressed: () {
              final val = ctrl.text.trim();
              if (val.isNotEmpty) {
                setState(() {
                  if (!_presetReasons.contains(val)) {
                    _presetReasons.add(val);
                  }
                  _selectedReasons.add(val);
                });
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.darkForest,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _makeCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          AppToast.showWarning(context, 'Could not launch dialer for $phone');
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.showWarning(context, 'Could not launch call: $e');
      }
    }
  }

  Future<void> _onConfirmSchedule() async {
    if (_isSubmitting) return;

    final effectiveDoctorId = _selectedDoctorId ?? _currentDoctorId;
    final vetProvider = Provider.of<VetCheckProvider>(context, listen: false);
    final availableDoctors = widget.doctors ?? vetProvider.doctors;

    // Doctor validation
    if (effectiveDoctorId == null || availableDoctors.isEmpty) {
      AppToast.showError(context, 'Please select a vet doctor for the checkup.');
      return;
    }

    final selectedDoctor = availableDoctors.firstWhere(
      (d) => d.id == effectiveDoctorId,
      orElse: () => availableDoctors.first,
    );

    // Reason validation
    final customReason = _reasonController.text.trim();
    if (_selectedReasons.isEmpty && customReason.isEmpty) {
      AppToast.showError(context, 'Please select or enter at least one reason for the visit.');
      return;
    }

    // Cow validation
    final cowProvider = Provider.of<CowProvider>(context, listen: false);
    final activeCows = cowProvider.cows.where((c) => c.isDeleted == 0).toList();
    int? effectiveCowId = _selectedCowId;
    String effectiveCowTag = _selectedCowTag ?? '';
    String effectiveCowName = _selectedCowName ?? '';

    if (effectiveCowId == null || effectiveCowTag.isEmpty || effectiveCowTag == '---') {
      if (activeCows.isNotEmpty) {
        final c = activeCows.first;
        effectiveCowId = c.id;
        effectiveCowTag = c.tagNumber;
        effectiveCowName = c.name ?? 'Cow #${c.tagNumber}';
      } else {
        AppToast.showError(context, 'Please register or select a cow first.');
        return;
      }
    }

    final reasonsList = [
      ..._selectedReasons,
      if (customReason.isNotEmpty && !_selectedReasons.contains(customReason)) customReason,
    ];

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final timeStr = _selectedTime.format(context);
    final followUpDateStr = _scheduleFollowUp && _followUpDate != null
        ? DateFormat('yyyy-MM-dd').format(_followUpDate!)
        : null;

    final appointment = VetAppointment(
      userId: _effectiveUserId,
      cowId: effectiveCowId!,
      doctorId: selectedDoctor.id ?? 1,
      scheduledDate: dateStr,
      scheduledTime: timeStr,
      reasons: reasonsList,
      customNotes: customReason.isNotEmpty ? customReason : null,
      feedbackNotes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      hasFollowUp: _scheduleFollowUp,
      followUpDate: followUpDateStr,
      status: 'SCHEDULED',
      cowTag: effectiveCowTag,
      cowName: effectiveCowName,
      doctorName: selectedDoctor.name,
      doctorPhone: selectedDoctor.phone,
    );

    setState(() => _isSubmitting = true);

    try {
      final appointmentId = await vetProvider.scheduleAppointment(
        appointment,
        cowTag: effectiveCowTag,
        doctorName: selectedDoctor.name,
      );

      if (mounted) {
        if (appointmentId != null) {
          AppToast.showSuccess(context, 'Vet check scheduled successfully!');
          Navigator.of(context).pop(true);
        } else {
          AppToast.showError(context, vetProvider.error ?? 'Failed to schedule appointment.');
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vetProvider = Provider.of<VetCheckProvider>(context);
    final availableDoctors = widget.doctors ?? vetProvider.doctors;

    final formattedDateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final formattedTimeStr = _selectedTime.format(context);

    final displayCowName = _selectedCowName?.isNotEmpty == true
        ? _selectedCowName!
        : (_selectedCowTag != null && _selectedCowTag != '---' ? 'Cow #$_selectedCowTag' : 'No Cow Selected');
    final displayCowTag = _selectedCowTag ?? '---';
    final displayShed = _selectedShed ?? 'A';

    return Scaffold(
      backgroundColor: AppColors.creamBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  InkWell(
                    key: const Key('vet_check_close_button'),
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
                  const Expanded(
                    child: Text(
                      'Schedule Vet Check',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkForest,
                      ),
                    ),
                  ),
                  InkWell(
                    key: const Key('vet_check_header_date_button'),
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.mintCardBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.deepGreen),
                          const SizedBox(width: 6),
                          Text(
                            formattedDateStr,
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
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Active Patient Card
                    Container(
                      key: const Key('vet_patient_card'),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: AppTheme.softShadow,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: const BoxDecoration(
                              color: AppColors.sageTint,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: AppIcons.cowHoof(size: 24, color: AppColors.deepGreen),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const CircleAvatar(radius: 3, backgroundColor: AppColors.sageGreen),
                                    const SizedBox(width: 6),
                                    Text(
                                      'ACTIVE PATIENT',
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
                                const SizedBox(height: 2),
                                Text(
                                  displayCowName,
                                  style: const TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.darkForest,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Milking Tag #$displayCowTag • Shed $displayShed',
                                  style: const TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontSize: 12,
                                    color: AppColors.textGrey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          InkWell(
                            key: const Key('vet_change_cow_button'),
                            onTap: _showChangeCowBottomSheet,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.backspaceBg,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Text(
                                'Change',
                                style: TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.darkForest,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Date & Time Picker Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: AppTheme.softShadow,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              key: const Key('vet_date_picker_tile'),
                              onTap: _pickDate,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.creamBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'DATE',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textGrey,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.calendar_today, size: 14, color: AppColors.darkForest),
                                        const SizedBox(width: 6),
                                        Text(
                                          formattedDateStr,
                                          style: const TextStyle(
                                            fontFamily: 'Plus Jakarta Sans',
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.darkForest,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              key: const Key('vet_time_picker_tile'),
                              onTap: _pickTime,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.creamBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'TIME',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textGrey,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.access_time_rounded, size: 14, color: AppColors.darkForest),
                                        const SizedBox(width: 6),
                                        Text(
                                          formattedTimeStr,
                                          style: const TextStyle(
                                            fontFamily: 'Plus Jakarta Sans',
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.darkForest,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Select Vet Doctor
                    Row(
                      children: [
                        const Text(
                          'Select Vet Doctor',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkForest,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (availableDoctors.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.mintCardBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${availableDoctors.length} Available',
                              style: const TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.deepGreen,
                              ),
                            ),
                          ),
                        const Spacer(),
                        InkWell(
                          key: const Key('vet_add_new_doctor_button'),
                          onTap: _showAddDoctorDialog,
                          borderRadius: BorderRadius.circular(8),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Text(
                              '+ Add New',
                              style: TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.deepGreen,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (availableDoctors.isEmpty)
                      Container(
                        key: const Key('vet_empty_doctors_container'),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: AppTheme.softShadow,
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(
                                color: AppColors.mintCardBg,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.medical_services_outlined, size: 28, color: AppColors.deepGreen),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No Vet Doctors Added',
                              style: TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.darkForest,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Add your farm\'s vet or select from contacts to schedule a checkup.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 13,
                                color: AppColors.textGrey,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              key: const Key('vet_empty_add_doctor_button'),
                              onPressed: _showAddDoctorDialog,
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text(
                                'Add a New Doctor',
                                style: TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.darkForest,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...availableDoctors.map((doc) {
                        final isSelected = (_selectedDoctorId ?? _currentDoctorId) == doc.id;
                        return GestureDetector(
                          key: Key('vet_doctor_card_${doc.id}'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => _selectedDoctorId = doc.id),
                          onLongPress: () => _confirmDeleteDoctor(doc),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: isSelected ? AppColors.darkForest : Colors.grey.shade200,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected ? AppColors.darkForest : Colors.grey.shade400,
                                      width: isSelected ? 6 : 1.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              doc.name,
                                              style: const TextStyle(
                                                fontFamily: 'Plus Jakarta Sans',
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.darkForest,
                                              ),
                                            ),
                                          ),
                                          if (doc.isPrimary) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.mintCardBg,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Text(
                                                'Primary Vet',
                                                style: TextStyle(
                                                  fontFamily: 'Plus Jakarta Sans',
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.deepGreen,
                                                ),
                                              ),
                                            ),
                                          ]
                                        ],
                                      ),
                                      if (doc.qualification.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          doc.qualification,
                                          style: const TextStyle(
                                            fontFamily: 'Plus Jakarta Sans',
                                            fontSize: 13,
                                            color: AppColors.textGrey,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.phone, size: 12, color: AppColors.deepGreen),
                                          const SizedBox(width: 4),
                                          Text(
                                            doc.phone,
                                            style: const TextStyle(
                                              fontFamily: 'Plus Jakarta Sans',
                                              fontSize: 12,
                                              color: AppColors.textGrey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                InkWell(
                                  key: Key('vet_doctor_call_${doc.id}'),
                                  onTap: () => _makeCall(doc.phone),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppColors.darkForest : AppColors.backspaceBg,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.phone,
                                      size: 18,
                                      color: isSelected ? Colors.white : AppColors.darkForest,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    const SizedBox(height: 24),

                    // Reason for Appointment
                    Row(
                      children: [
                        const Text(
                          'Reason for Appointment',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkForest,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '*',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.red.shade400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Select a preset reason or describe manually below',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 13,
                        color: AppColors.textGrey,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ..._presetReasons.map((reason) {
                          final isSelected = _selectedReasons.contains(reason);
                          return GestureDetector(
                            key: Key('vet_reason_tag_$reason'),
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedReasons.remove(reason);
                                } else {
                                  _selectedReasons.add(reason);
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.darkForest : AppColors.backspaceBg,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isSelected) ...[
                                    const CircleAvatar(radius: 3, backgroundColor: Colors.white),
                                    const SizedBox(width: 6),
                                  ],
                                  Text(
                                    reason,
                                    style: TextStyle(
                                      fontFamily: 'Plus Jakarta Sans',
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                      color: isSelected ? Colors.white : AppColors.textDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        InkWell(
                          key: const Key('vet_add_preset_reason_button'),
                          onTap: _showAddCustomReasonDialog,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.darkForest,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add, size: 14, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'Add',
                                  style: TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Write Reason / Notes Manually',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkForest,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const Key('vet_manual_reason_input'),
                      controller: _reasonController,
                      maxLines: 4,
                      minLines: 3,
                      style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Describe specific symptoms, checkup requirements, or write custom reason...',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontFamily: 'Plus Jakarta Sans'),
                        filled: true,
                        fillColor: AppColors.creamBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(color: AppColors.darkForest),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'You can pick from preset tags, write your own reason, or do both.',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 11,
                        color: AppColors.textGrey,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Post-Checkup Feedback
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: AppTheme.softShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: AppColors.mintCardBg,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.medical_services_outlined, size: 20, color: AppColors.deepGreen),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Post-Checkup Feedback & Notes',
                                      style: TextStyle(
                                        fontFamily: 'Plus Jakarta Sans',
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.darkForest,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Enter what the vet said, diagnosis, prescription, or feedback',
                                      style: TextStyle(
                                        fontFamily: 'Plus Jakarta Sans',
                                        fontSize: 12,
                                        color: AppColors.textGrey,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            key: const Key('vet_feedback_notes_input'),
                            controller: _notesController,
                            maxLines: 4,
                            minLines: 3,
                            style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Enter doctor feedback, prescribed medication, withdrawal period, or instructions...',
                              hintStyle: TextStyle(color: Colors.grey.shade400, fontFamily: 'Plus Jakarta Sans'),
                              filled: true,
                              fillColor: AppColors.creamBg,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide(color: Colors.grey.shade200),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide(color: Colors.grey.shade200),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: const BorderSide(color: AppColors.darkForest),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Divider(height: 1, color: Color(0xFFE5E5EA)),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Schedule Follow-up Visit',
                                    style: TextStyle(
                                      fontFamily: 'Plus Jakarta Sans',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.darkForest,
                                    ),
                                  ),
                                  Text(
                                    'Set reminder for next inspection',
                                    style: TextStyle(
                                      fontFamily: 'Plus Jakarta Sans',
                                      fontSize: 12,
                                      color: AppColors.textGrey,
                                    ),
                                  ),
                                ],
                              ),
                              Switch(
                                key: const Key('vet_follow_up_switch'),
                                value: _scheduleFollowUp,
                                onChanged: (val) {
                                  setState(() {
                                    _scheduleFollowUp = val;
                                    if (val && _followUpDate == null) {
                                      _followUpDate = _selectedDate.add(const Duration(days: 7));
                                    }
                                  });
                                },
                                activeThumbColor: Colors.white,
                                activeTrackColor: AppColors.darkForest,
                                inactiveTrackColor: AppColors.backspaceBg,
                              ),
                            ],
                          ),
                          if (_scheduleFollowUp && _followUpDate != null) ...[
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _followUpDate!,
                                  firstDate: _selectedDate,
                                  lastDate: _selectedDate.add(const Duration(days: 365)),
                                );
                                if (picked != null) {
                                  setState(() => _followUpDate = picked);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.mintCardBg,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.event_repeat, size: 16, color: AppColors.deepGreen),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Follow-up Date: ${DateFormat('yyyy-MM-dd').format(_followUpDate!)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.deepGreen,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            key: const Key('vet_confirm_schedule_button'),
            onPressed: _isSubmitting ? null : _onConfirmSchedule,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.darkForest,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Confirm & Schedule Checkup',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
