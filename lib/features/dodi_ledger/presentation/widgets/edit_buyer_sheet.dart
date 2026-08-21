import 'package:flutter/material.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:flutter_native_contact_picker/model/contact.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_toast.dart';
import '../../../../core/utils/money_utils.dart';
import '../../data/models/dodi_model.dart';
import '../providers/dodi_provider.dart';

class EditBuyerSheet extends StatefulWidget {
  final DodiModel dodi;
  final int userId;

  const EditBuyerSheet({
    super.key,
    required this.dodi,
    required this.userId,
  });

  @override
  State<EditBuyerSheet> createState() => _EditBuyerSheetState();
}

class _EditBuyerSheetState extends State<EditBuyerSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _rateController;
  final FlutterNativeContactPicker _contactPicker = FlutterNativeContactPicker();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.dodi.name);
    _phoneController = TextEditingController(text: widget.dodi.phone ?? '');
    _rateController = TextEditingController(
      text: MoneyUtils.formatPaiseToRupees(widget.dodi.defaultRatePaise),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  Future<void> _pickContact() async {
    try {
      final Contact? contact = await _contactPicker.selectContact();
      if (contact != null) {
        final phoneNumbers = contact.phoneNumbers;
        if (phoneNumbers != null && phoneNumbers.isNotEmpty) {
          final rawPhone = phoneNumbers.first;
          final cleanPhone = rawPhone.replaceAll(RegExp(r'\D'), '');
          setState(() {
            _phoneController.text = cleanPhone;
            final fullName = contact.fullName;
            if (_nameController.text.trim().isEmpty && fullName != null && fullName.trim().isNotEmpty) {
              _nameController.text = fullName.trim();
            }
          });
        } else {
          if (!mounted) return;
          AppToast.showError(context, 'Selected contact does not have a phone number.');
        }
      }
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(context, 'Could not access phone contacts.');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    final dodiProvider = Provider.of<DodiProvider>(context, listen: false);
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final ratePaise = MoneyUtils.rupeesToPaise(_rateController.text);
    
    setState(() => _saving = true);

    final success = await dodiProvider.updateDodi(
      dodiId: widget.dodi.id!,
      userId: widget.userId,
      name: name,
      phone: phone.isEmpty ? null : phone,
      ratePaise: ratePaise,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (success) {
      Navigator.of(context).pop();
      AppToast.showSuccess(context, '✅ Buyer details updated successfully.');
    } else {
      final err = Provider.of<DodiProvider>(context, listen: false).errorMessage;
      AppToast.showError(context, err ?? 'Failed to update buyer.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgGrey,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      margin: EdgeInsets.only(top: mq.padding.top + 40),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 24, 20, mq.viewInsets.bottom + 20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Edit Buyer Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.textGrey),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Name Field
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: AppColors.textDark),
                  textCapitalization: TextCapitalization.words,
                  decoration: AppTheme.filledInputDecoration(
                    labelText: 'Buyer Name *',
                    prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a name' : null,
                ),
                const SizedBox(height: 16),
                // Phone Field (manual entry + contact picker option)
                TextFormField(
                  controller: _phoneController,
                  style: const TextStyle(color: AppColors.textDark),
                  keyboardType: TextInputType.phone,
                  decoration: AppTheme.filledInputDecoration(
                    labelText: 'Phone Number (Optional)',
                    prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.contacts_rounded, color: AppColors.deepGreen, size: 22),
                      onPressed: _pickContact,
                      tooltip: 'Select from phone contacts',
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null; // Optional
                    final digitsOnly = v.replaceAll(RegExp(r'\D'), '');
                    if (digitsOnly.length < 7 || digitsOnly.length > 15) {
                      return 'Enter a valid phone number (7-15 digits)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Rate Field
                TextFormField(
                  controller: _rateController,
                  style: const TextStyle(color: AppColors.textDark),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: AppTheme.filledInputDecoration(
                    labelText: 'Default Rate (Rs/Kg) *',
                    prefix: const Text('Rs. ', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Please enter a rate';
                    if (double.tryParse(val.trim()) == null) return 'Enter a valid number';
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.deepGreen,
                      foregroundColor: AppColors.cardWhite,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: AppColors.cardWhite, strokeWidth: 2),
                          )
                        : const Text(
                            'Save Changes',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
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
