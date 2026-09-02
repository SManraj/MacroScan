import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dietingapp2026/screens/sign_up_screen.dart';
import 'package:dietingapp2026/screens/forgot_password_screen.dart';
import 'package:dietingapp2026/screens/main_screen.dart';
import 'package:dietingapp2026/screens/signup_screens/profile_info_screen.dart';

import '../auth_service.dart';
import '../database_service.dart';
import '../widgets/app_widgets.dart';

import '../widgets/custom_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _passwordError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);
    try {
      await authService.value.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        const credentialCodes = {
          'wrong-password',
          'user-not-found',
          'invalid-credential',
          'invalid-email',
          'INVALID_LOGIN_CREDENTIALS',
        };
        if (credentialCodes.contains(e.code)) {
          setState(() {
            _passwordError = 'Incorrect email or password';
            _passwordController.clear();
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message ?? 'Login failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xl),

                // App Logo
                Center(
                  child: Image.asset(
                    'assets/images/thepear.png',
                    height: 125,
                    fit: BoxFit.contain,
                    semanticLabel: 'MacroScan AI logo',
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                Text(
                  'MacroScan',
                  style: tt.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),

                Text(
                  'Sign in to continue tracking your nutrition',
                  style: tt.bodyMedium?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xxxl),

                // Email Field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'Enter your email',
                    prefixIcon: Icon(
                      Icons.email_outlined,
                      semanticLabel: 'Email',
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains('@') ||
                        value.contains('@mailinator.com') ||
                        value.contains('@10minutemail.com') ||
                        value.contains('@email.com')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                // Password Field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _handleLogin(),
                  onChanged: (_) {
                    if (_passwordError != null) {
                      setState(() => _passwordError = null);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter your password',
                    errorText: _passwordError,
                    prefixIcon: const Icon(
                      Icons.lock_outlined,
                      semanticLabel: 'Password',
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        semanticLabel: _obscurePassword
                            ? 'Show password'
                            : 'Hide password',
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.sm),

                // Forgot Password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ForgotPasswordScreen(),
                        ),
                      );
                    },
                    child: Text(
                      'Forgot Password?',
                      style: TextStyle(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Login Button
                // PrimaryButton(
                //   onPressed: _handleLogin,
                //   isLoading: _isLoading,
                //   child: const Text(
                //     'Sign In',
                //     style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                //   ),
                // ),
                CustomButton(
                  text: 'Sign In',
                  // Disables taps while a sign-in request is in flight so the
                  // user can't double-submit. The button stays visible (no
                  // built-in spinner — see note in chat about adding one).
                  onPressed: _isLoading ? null : _handleLogin,
                  width: double.infinity,
                ),
                const SizedBox(height: AppSpacing.lg),

                // Divider with "Or"
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: cs.onSurface.withValues(alpha: 0.2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: Text(
                        'or',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: cs.onSurface.withValues(alpha: 0.2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // Google Sign In
                CustomButton(
                  text: 'Sign in with Google',
                  width: double.infinity,
                  backgroundColor: Colors.white,
                  textColor: Colors.black87,
                  icon: Image.network(
                    // Official Google G logo (HTTPS, Google CDN, the URL
                    // Google recommends for Sign-in With Google branding).
                    'https://developers.google.com/identity/images/g-logo.png',
                    width: 20,
                    height: 20,
                    fit: BoxFit.contain,
                    // Fallback if the network image is unavailable so the
                    // button never renders as a broken-image placeholder.
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.g_mobiledata,
                      size: 24,
                      semanticLabel: 'Google',
                    ),
                  ),
                  onPressed: _isLoading
                      ? null
                      : () async {
                          setState(() => _isLoading = true);
                          try {
                            final credential = await authService.value
                                .signInWithGoogle();
                            if (credential == null) return;

                            final uid = credential.user!.uid;
                            final email = credential.user!.email ?? '';

                            // Check if the user has completed profile setup
                            // in PostgreSQL. getUserProfile throws if the
                            // row doesn't exist (new user).
                            bool needsProfileSetup;
                            try {
                              final profile =
                                  await DatabaseService.getUserProfile(
                                    uid: uid,
                                  );
                              final fname = profile['f_name'] as String?;
                              needsProfileSetup =
                                  fname == null || fname.trim().isEmpty;
                            } catch (_) {
                              // Row missing — create it then send them to
                              // profile setup.
                              await DatabaseService.createUserProfile(
                                uid: uid,
                                email: email,
                              );
                              needsProfileSetup = true;
                            }

                            if (!context.mounted) return;

                            if (needsProfileSetup) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ProfileInfoScreen(
                                    preventBack: true,
                                  ),
                                ),
                              );
                            } else {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const MainScreen(),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    e.toString().replaceFirst(
                                      'Exception: ',
                                      '',
                                    ),
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _isLoading = false);
                          }
                        },
                ),

                // Sign Up Link
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account?",
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SignUpScreen(),
                          ),
                        );
                      },
                      child: Text(
                        'Register',
                        style: TextStyle(
                          color: cs.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
