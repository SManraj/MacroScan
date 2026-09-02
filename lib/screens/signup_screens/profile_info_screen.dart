import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io';
import 'package:dietingapp2026/auth_service.dart';
import 'package:dietingapp2026/database_service.dart';
import 'package:dietingapp2026/services/cache_service.dart';
import 'package:dietingapp2026/screens/main_screen.dart';
import 'package:dietingapp2026/widgets/app_widgets.dart';
import '../static/colors.dart';

import 'package:dietingapp2026/widgets/custom_button.dart';

class ProfileInfoScreen extends StatefulWidget {
  /// When true, the system back gesture/button is blocked so the user cannot
  /// skip profile setup (used for new Google sign-in accounts).
  final bool preventBack;

  const ProfileInfoScreen({super.key, this.preventBack = false});

  @override
  State<ProfileInfoScreen> createState() => _ProfileInfoScreenState();
}

class _ProfileInfoScreenState extends State<ProfileInfoScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _ageController = TextEditingController();

  String? _selectedSex;
  DateTime? _dateOfBirth;

  bool get _isIOS => Platform.isIOS;

  // _sexIcon getter
  IconData get _sexIcon {
    if (_selectedSex == 'male') return Icons.man_2_outlined;
    if (_selectedSex == 'female') return Icons.woman_2_outlined;
    return Icons.person_outline; // default when nothing selected
  }

  int? get _calculatedAge {
    if (_dateOfBirth == null) return null;
    final today = DateTime.now();
    int age = today.year - _dateOfBirth!.year;
    if (today.month < _dateOfBirth!.month ||
        (today.month == _dateOfBirth!.month && today.day < _dateOfBirth!.day)) {
      age--;
    }
    return age;
  }

  double? get _calculatedBMI {
    // convert height to inches total
    final totalInches = (_heightFt * 12) + _heightIn;
    if (totalInches == 0) return null;
    // BMI formula for imperial: (weight in lbs * 703) / (height in inches)^2
    return (_weightLbs * 703) / (totalInches * totalInches);
  }

  String get _bmiCategory {
    final bmi = _calculatedBMI;
    if (bmi == null) return '';
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25.0) return 'Normal';
    if (bmi < 30.0) return 'Overweight';
    return 'Obese';
  }

  Color get _bmiColor {
    final bmi = _calculatedBMI;
    if (bmi == null) return Colors.grey;
    if (bmi < 18.5) return Colors.blue;
    if (bmi < 25.0) return Colors.green;
    if (bmi < 30.0) return Colors.orange;
    return Colors.red;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadius.md),
        color: colorScheme.surface,
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], semanticLabel: label),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: Colors.grey[400],
            semanticLabel: 'Select $label',
          ),
        ],
      ),
    );
  }

  Widget _buildSexField() {
    if (_isIOS) {
      return GestureDetector(
        onTap: () {
          String tempSex = _selectedSex ?? 'male';
          showCupertinoModalPopup(
            context: context,
            builder: (context) => Container(
              height: 250,
              color: CupertinoColors.systemBackground.resolveFrom(context),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        child: const Text('Cancel'),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        'Sex',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      CupertinoButton(
                        child: const Text('Done'),
                        onPressed: () {
                          setState(() => _selectedSex = tempSex);
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: FixedExtentScrollController(
                        initialItem: _selectedSex == 'female' ? 1 : 0,
                      ),
                      itemExtent: 30,
                      onSelectedItemChanged: (index) {
                        tempSex = index == 0 ? 'male' : 'female';
                      },
                      children: const [
                        Center(
                          child: Text('Male', style: TextStyle(fontSize: 20)),
                        ),
                        Center(
                          child: Text('Female', style: TextStyle(fontSize: 20)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        child: _buildReadOnlyField(
          label: 'Sex',
          value: _selectedSex == null
              ? 'Select'
              : _selectedSex![0].toUpperCase() + _selectedSex!.substring(1),
          icon: _sexIcon,
        ),
      );
    } else {
      return DropdownButtonFormField<String>(
        initialValue: _selectedSex,
        decoration: _inputDecoration('Sex', _sexIcon),
        items: const [
          DropdownMenuItem(value: 'male', child: Text('Male')),
          DropdownMenuItem(value: 'female', child: Text('Female')),
        ],
        onChanged: (val) => setState(() => _selectedSex = val),
      );
    }
  }

  int _weightLbs = 150;
  int _heightFt = 5;
  int _heightIn = 7;

  Widget _buildWeightField() {
    if (_isIOS) {
      return GestureDetector(
        onTap: () {
          int tempWeight = _weightLbs;
          showCupertinoModalPopup(
            context: context,
            builder: (context) => Container(
              height: 300,
              color: CupertinoColors.systemBackground.resolveFrom(context),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        child: const Text('Cancel'),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        'Weight',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      CupertinoButton(
                        child: const Text('Done'),
                        onPressed: () {
                          setState(() => _weightLbs = tempWeight);
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: FixedExtentScrollController(
                        initialItem: _weightLbs - 50,
                      ),
                      itemExtent: 40,
                      onSelectedItemChanged: (index) => tempWeight = 50 + index,
                      children: List.generate(
                        401, // 50 to 450 lbs
                        (index) => Center(
                          child: Text(
                            '${50 + index} lbs',
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        child: _buildReadOnlyField(
          label: 'Weight',
          value: '$_weightLbs lbs',
          icon: Icons.monitor_weight_outlined,
        ),
      );
    } else {
      return TextFormField(
        keyboardType: TextInputType.number,
        decoration: _inputDecoration(
          'Weight (lbs)',
          Icons.monitor_weight_outlined,
        ),
        onChanged: (val) => _weightLbs = int.tryParse(val) ?? _weightLbs,
      );
    }
  }

  Widget _buildHeightField() {
    if (_isIOS) {
      return GestureDetector(
        onTap: () {
          int tempFt = _heightFt;
          int tempIn = _heightIn;
          showCupertinoModalPopup(
            context: context,
            builder: (context) => Container(
              height: 300,
              color: CupertinoColors.systemBackground.resolveFrom(context),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        child: const Text('Cancel'),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        'Height',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      CupertinoButton(
                        child: const Text('Done'),
                        onPressed: () {
                          setState(() {
                            _heightFt = tempFt;
                            _heightIn = tempIn;
                          });
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        // Feet picker
                        Expanded(
                          child: CupertinoPicker(
                            scrollController: FixedExtentScrollController(
                              initialItem: _heightFt - 3,
                            ),
                            itemExtent: 40,
                            onSelectedItemChanged: (index) =>
                                tempFt = 3 + index,
                            children: List.generate(
                              6, // 3ft to 8ft
                              (index) => Center(
                                child: Text(
                                  '${3 + index} ft',
                                  style: const TextStyle(fontSize: 18),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Inches picker
                        Expanded(
                          child: CupertinoPicker(
                            scrollController: FixedExtentScrollController(
                              initialItem: _heightIn,
                            ),
                            itemExtent: 40,
                            onSelectedItemChanged: (index) => tempIn = index,
                            children: List.generate(
                              12, // 0 to 11 inches
                              (index) => Center(
                                child: Text(
                                  '$index in',
                                  style: const TextStyle(fontSize: 18),
                                ),
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
        },
        child: _buildReadOnlyField(
          label: 'Height',
          value: '$_heightFt ft $_heightIn in',
          icon: Icons.height,
        ),
      );
    } else {
      return Row(
        children: [
          Expanded(
            child: TextFormField(
              keyboardType: TextInputType.number,
              decoration: _inputDecoration('Feet', Icons.height),
              onChanged: (val) => _heightFt = int.tryParse(val) ?? _heightFt,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              keyboardType: TextInputType.number,
              decoration: _inputDecoration('Inches', Icons.height),
              onChanged: (val) => _heightIn = int.tryParse(val) ?? _heightIn,
            ),
          ),
        ],
      );
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return PopScope(
      canPop: !widget.preventBack,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Your Profile'),
          centerTitle: true,
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.lg),

                Text(
                  'Tell us about yourself',
                  style: tt.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'This helps us personalize your nutrition goals.',
                  style: tt.bodyMedium?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),

                SectionHeader(title: 'NAME'),
                const SizedBox(height: AppSpacing.sm),

                // First & Last Name on same row
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstNameController,
                        keyboardType: TextInputType.name,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'First Name',
                          prefixIcon: Icon(
                            Icons.person_outline,
                            semanticLabel: 'First name',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: TextFormField(
                        controller: _lastNameController,
                        keyboardType: TextInputType.name,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Last Name',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),

                SectionHeader(title: 'BIOLOGICAL SEX'),
                const SizedBox(height: AppSpacing.sm),

                _buildSexField(),
                const SizedBox(height: AppSpacing.xl),

                SectionHeader(title: 'DATE OF BIRTH'),
                const SizedBox(height: AppSpacing.sm),

                // Age
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: _isIOS
                          ? GestureDetector(
                              onTap: () {
                                DateTime tempDate =
                                    _dateOfBirth ?? DateTime(2000);
                                showCupertinoModalPopup(
                                  context: context,
                                  builder: (context) => Container(
                                    height: 300,
                                    color: CupertinoColors.systemBackground
                                        .resolveFrom(context),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            CupertinoButton(
                                              child: const Text('Cancel'),
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                            ),
                                            const Text(
                                              'Date of Birth',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            CupertinoButton(
                                              child: const Text('Done'),
                                              onPressed: () {
                                                setState(
                                                  () => _dateOfBirth = tempDate,
                                                );
                                                Navigator.pop(context);
                                              },
                                            ),
                                          ],
                                        ),
                                        Expanded(
                                          child: CupertinoDatePicker(
                                            mode: CupertinoDatePickerMode.date,
                                            initialDateTime:
                                                _dateOfBirth ?? DateTime(2000),
                                            maximumDate: DateTime.now(),
                                            minimumDate: DateTime(1900),
                                            onDateTimeChanged: (date) =>
                                                tempDate = date,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              child: _buildReadOnlyField(
                                label: 'Date of Birth',
                                value: _dateOfBirth == null
                                    ? 'Select'
                                    : '${_dateOfBirth!.month}/${_dateOfBirth!.day}/${_dateOfBirth!.year}',
                                icon: Icons.cake_outlined,
                              ),
                            )
                          : TextFormField(
                              readOnly: true,
                              decoration: _inputDecoration(
                                'Date of Birth',
                                Icons.cake_outlined,
                              ),
                              controller: TextEditingController(
                                text: _dateOfBirth == null
                                    ? ''
                                    : '${_dateOfBirth!.month}/${_dateOfBirth!.day}/${_dateOfBirth!.year}',
                              ),
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _dateOfBirth ?? DateTime(2000),
                                  firstDate: DateTime(1900),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) {
                                  setState(() => _dateOfBirth = picked);
                                }
                              },
                            ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    if (_calculatedAge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '$_calculatedAge',
                              style: tt.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: cs.primary,
                              ),
                            ),
                            Text(
                              'years',
                              style: tt.labelSmall?.copyWith(
                                color: cs.primary.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),

                SectionHeader(title: 'HEIGHT & WEIGHT'),
                const SizedBox(height: AppSpacing.sm),

                // Height & Weight on same row
                Row(
                  children: [
                    Expanded(child: _buildHeightField()),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: _buildWeightField()),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // BMI display
                if (_calculatedBMI != null)
                  AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _bmiColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Icon(
                            Icons.monitor_heart_outlined,
                            color: _bmiColor,
                            size: 20,
                            semanticLabel: 'BMI',
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Body Mass Index',
                                style: tt.bodySmall?.copyWith(
                                  color: cs.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                              Text(
                                _bmiCategory,
                                style: tt.labelMedium?.copyWith(
                                  color: _bmiColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: _bmiColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text(
                            _calculatedBMI!.toStringAsFixed(1),
                            style: tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: _bmiColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: AppSpacing.xxl),

                // Save button
                CustomButton(
                  text: 'Save Profile',
                  width: double.infinity,
                  onPressed: () async {
                    // Validate fields
                    if (_firstNameController.text.isEmpty ||
                        _lastNameController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please fill in all fields'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    if (_dateOfBirth == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please select your date of birth'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    if (_selectedSex == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please select your sex'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    final user = authService.value.currentUser;
                    if (user == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'You\'re not signed in. Please sign in again to save your profile.',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    final uid = user.uid;

                    try {
                      final bmi = _calculatedBMI ?? 0.0;

                      await DatabaseService.updateUserProfile(
                        uid: uid,
                        firstName: _firstNameController.text.trim(),
                        lastName: _lastNameController.text.trim(),
                        dateOfBirth: _dateOfBirth!,
                        sex: _selectedSex!,
                        weightLbs: _weightLbs,
                        heightFt: _heightFt,
                        heightIn: _heightIn,
                        bmi: bmi,
                      );

                      // Profile changed — drop cached profile + goals (the goals
                      // endpoint embeds current weight) so they reload fresh.
                      await CacheService.instance.invalidateProfile(uid);
                      await CacheService.instance.invalidateGoals(uid);

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Profile saved!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MainScreen(),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
