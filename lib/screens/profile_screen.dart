import 'package:flutter/material.dart';
import '../auth_service.dart';
import '../database_service.dart';
import '../widgets/app_widgets.dart';
import '../widgets/loading_view.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profileData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile({bool forceRefresh = false}) async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final uid = authService.value.currentUser!.uid;
      final data = await DatabaseService.getUserProfile(
        uid: uid,
        forceRefresh: forceRefresh,
      );
      setState(() {
        _profileData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  int? _calculateAge(String? dateOfBirth) {
    if (dateOfBirth == null) return null;
    final dob = DateTime.parse(dateOfBirth);
    final today = DateTime.now();
    int age = today.year - dob.year;
    if (today.month < dob.month ||
        (today.month == dob.month && today.day < dob.day)) {
      age--;
    }
    return age;
  }

  double? _calculateBMI(int? weightLbs, int? heightFt, int? heightIn) {
    if (weightLbs == null || heightFt == null || heightIn == null) return null;
    final totalInches = (heightFt * 12) + heightIn;
    if (totalInches == 0) return null;
    return (weightLbs * 703) / (totalInches * totalInches);
  }

  Color _bmiColor(double bmi) {
    if (bmi < 18.5) return Colors.blue;
    if (bmi < 25.0) return Colors.green;
    if (bmi < 30.0) return Colors.orange;
    return Colors.red;
  }

  String _bmiCategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25.0) return 'Normal';
    if (bmi < 30.0) return 'Overweight';
    return 'Obese';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: LoadingView());
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back,
                semanticLabel: 'Back'),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: EmptyState(
            icon: Icons.error_outline,
            message: 'Failed to load profile',
            subMessage: _error,
            action: FilledButton(
              onPressed: () => _loadProfile(forceRefresh: true),
              child: const Text('Retry'),
            ),
          ),
        ),
      );
    }

    final p = _profileData!;
    final firstName = p['f_name'] ?? '';
    final lastName = p['l_name'] ?? '';
    final fullName = '$firstName $lastName'.trim();
    final sex = p['sex'] as String?;
    final dob = p['date_of_birth'] as String?;
    final age = _calculateAge(dob);
    final weightLbs = p['weight_lbs'] != null
        ? int.tryParse(p['weight_lbs'].toString())
        : null;
    final heightFt = p['height_ft'] != null
        ? int.tryParse(p['height_ft'].toString())
        : null;
    final heightIn = p['height_in'] != null
        ? int.tryParse(p['height_in'].toString())
        : null;
    final bmi = _calculateBMI(weightLbs, heightFt, heightIn);

    String formattedDOB = '';
    if (dob != null) {
      final date = DateTime.parse(dob);
      formattedDOB = '${date.month}/${date.day}/${date.year}';
    }

    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        automaticallyImplyLeading: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xxl),

              // Avatar and name
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: cs.primaryContainer,
                      child: Text(
                        fullName.isNotEmpty
                            ? fullName[0].toUpperCase()
                            : '?',
                        style: tt.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      fullName.isNotEmpty ? fullName : 'No name set',
                      style: tt.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (p['email'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        p['email'] as String,
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              // Personal Info section
              SectionHeader(title: 'PERSONAL INFO'),
              const SizedBox(height: AppSpacing.sm),

              InfoRow(
                icon: sex == 'male'
                    ? Icons.man_2_outlined
                    : Icons.woman_2_outlined,
                label: 'Sex',
                value: sex != null
                    ? sex[0].toUpperCase() + sex.substring(1)
                    : 'Not set',
              ),
              const SizedBox(height: AppSpacing.sm),

              InfoRow(
                icon: Icons.cake_outlined,
                label: 'Date of Birth',
                value: formattedDOB.isNotEmpty ? formattedDOB : 'Not set',
              ),
              const SizedBox(height: AppSpacing.sm),

              InfoRow(
                icon: Icons.calendar_today_outlined,
                label: 'Age',
                value: age != null ? '$age years old' : 'Not set',
              ),

              const SizedBox(height: AppSpacing.xl),
              SectionHeader(title: 'BODY METRICS'),
              const SizedBox(height: AppSpacing.sm),

              InfoRow(
                icon: Icons.height,
                label: 'Height',
                value: heightFt != null && heightIn != null
                    ? '$heightFt ft $heightIn in'
                    : 'Not set',
              ),
              const SizedBox(height: AppSpacing.sm),

              InfoRow(
                icon: Icons.monitor_weight_outlined,
                label: 'Weight',
                value: weightLbs != null ? '$weightLbs lbs' : 'Not set',
              ),

              if (bmi != null) ...[
                const SizedBox(height: AppSpacing.sm),
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
                          color: _bmiColor(bmi).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Icon(
                          Icons.monitor_heart_outlined,
                          color: _bmiColor(bmi),
                          size: 20,
                          semanticLabel: 'BMI',
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('BMI',
                                style: tt.bodyMedium?.copyWith(
                                  color:
                                      cs.onSurface.withValues(alpha: 0.7),
                                )),
                            const SizedBox(height: 2),
                            Text(
                              _bmiCategory(bmi),
                              style: tt.labelSmall?.copyWith(
                                color: _bmiColor(bmi),
                                fontWeight: FontWeight.w600,
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
                          color: _bmiColor(bmi).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          bmi.toStringAsFixed(1),
                          style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: _bmiColor(bmi),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}
