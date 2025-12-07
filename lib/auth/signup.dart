// lib/auth/signup.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Emerald color constant
const Color kEmerald = Color(0xFF059669);

/// API Base URL - must match login_page.dart
const String API_BASE = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://10.0.2.2:5000',
);

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController middleNameController = TextEditingController();
  final TextEditingController suffixController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final TextEditingController twoFaCodeController = TextEditingController();

  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  bool acceptTerms = false;
  bool _isSubmitting = false;
  bool _isSendingCode = false;
  bool _codeSent = false;
  int _resendCountdown = 0;
  Timer? _countdownTimer;

  // Password strength state
  double _pwdStrength = 0.0;
  String _pwdStrengthLabel = '';
  List<String> _pwdSuggestions = [];

  @override
  void initState() {
    super.initState();
    passwordController.addListener(_updatePasswordStrength);
    _updatePasswordStrength();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    passwordController.removeListener(_updatePasswordStrength);
    firstNameController.dispose();
    lastNameController.dispose();
    middleNameController.dispose();
    suffixController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    twoFaCodeController.dispose();
    super.dispose();
  }

  void _updatePasswordStrength() {
    final pwd = passwordController.text;
    final strength = _calculatePasswordStrength(pwd);
    final label = _labelForStrength(strength);
    final suggestions = _suggestionsForPassword(pwd);
    setState(() {
      _pwdStrength = strength;
      _pwdStrengthLabel = label;
      _pwdSuggestions = suggestions;
    });
  }

  double _calculatePasswordStrength(String pwd) {
    if (pwd.isEmpty) return 0.0;

    double score = 0;

    if (pwd.length >= 12) {
      score += 0.35;
    } else if (pwd.length >= 8) {
      score += 0.20;
    } else if (pwd.length >= 6) {
      score += 0.08;
    } else {
      score += 0.02;
    }

    final hasLower = RegExp(r'[a-z]').hasMatch(pwd);
    final hasUpper = RegExp(r'[A-Z]').hasMatch(pwd);
    final hasDigit = RegExp(r'\d').hasMatch(pwd);
    final hasSymbol = RegExp(r'[^A-Za-z0-9]').hasMatch(pwd);

    final varietyCount =
        [hasLower, hasUpper, hasDigit, hasSymbol].where((e) => e).length;
    score += (varietyCount / 4) * 0.55;

    if (pwd.length < 6) score *= 0.6;
    if (RegExp(r'^[0-9]+$').hasMatch(pwd)) score *= 0.5;

    return score.clamp(0.0, 1.0);
  }

  String _labelForStrength(double s) {
    if (s <= 0.2) return 'Very weak';
    if (s <= 0.45) return 'Weak';
    if (s <= 0.7) return 'Fair';
    if (s <= 0.9) return 'Strong';
    return 'Very strong';
  }

  Color _colorForStrength(double s) {
    if (s <= 0.2) return Colors.red.shade400;
    if (s <= 0.45) return Colors.deepOrange.shade400;
    if (s <= 0.7) return Colors.amber.shade600;
    if (s <= 0.9) return Colors.green.shade600;
    return Colors.green.shade800;
  }

  List<String> _suggestionsForPassword(String pwd) {
    final suggestions = <String>[];

    if (pwd.length < 12) {
      suggestions.add('Use 12+ characters');
    }
    if (!RegExp(r'[A-Z]').hasMatch(pwd)) {
      suggestions.add('Add an uppercase letter (A)');
    }
    if (!RegExp(r'[a-z]').hasMatch(pwd)) {
      suggestions.add('Add a lowercase letter (a)');
    }
    if (!RegExp(r'\d').hasMatch(pwd)) {
      suggestions.add('Include a number (0-9)');
    }
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(pwd)) {
      suggestions.add('Include a symbol (!@#\$%)');
    }

    if (pwd.length >= 12 &&
        RegExp(r'[A-Z]').hasMatch(pwd) &&
        RegExp(r'[a-z]').hasMatch(pwd) &&
        RegExp(r'\d').hasMatch(pwd) &&
        RegExp(r'[^A-Za-z0-9]').hasMatch(pwd) &&
        suggestions.isEmpty) {
      suggestions.add('Looks good — consider a passphrase for extra safety');
    }

    return suggestions.take(4).toList();
  }

  InputDecoration _fieldDecoration({
    required String label,
    String? hint,
    IconData? prefix,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefix == null ? null : Icon(prefix),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF7F7F8),
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }

  /// Send 2FA verification code
  Future<void> _sendVerificationCode() async {
    final email = emailController.text.trim();
    
    if (email.isEmpty) {
      _showError('Please enter your email first');
      return;
    }

    if (!RegExp(r"^[\w\.-]+@[\w\.-]+\.\w+$").hasMatch(email)) {
      _showError('Please enter a valid email');
      return;
    }

    setState(() => _isSendingCode = true);

    try {
      final response = await http.post(
        Uri.parse('$API_BASE/api/2fa/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        setState(() {
          _codeSent = true;
          _resendCountdown = 60;
        });
        
        _showSuccess(data['message'] ?? 'Verification code sent to your email');
        
        // Start countdown timer
        _countdownTimer?.cancel();
        _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted) {
            timer.cancel();
            return;
          }
          setState(() {
            if (_resendCountdown > 0) {
              _resendCountdown--;
            } else {
              timer.cancel();
            }
          });
        });
      } else {
        _showError(data['message'] ?? 'Failed to send verification code');
      }
    } on TimeoutException catch (_) {
      _showError('Request timed out. Please try again.');
    } catch (e) {
      _showError('Failed to send code. Please check your connection.');
    } finally {
      if (mounted) {
        setState(() => _isSendingCode = false);
      }
    }
  }

  /// Submit signup form
  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (!acceptTerms) {
      _showError('Please accept the Terms & Privacy');
      return;
    }

    if (!_codeSent || twoFaCodeController.text.trim().isEmpty) {
      _showError('Please request and enter the verification code');
      return;
    }

    setState(() => _isSubmitting = true);

    final email = emailController.text.trim();
    final password = passwordController.text;
    final code = twoFaCodeController.text.trim();

    try {
      final response = await http.post(
        Uri.parse('$API_BASE/api/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'first_name': firstNameController.text.trim(),
          'middle_name': middleNameController.text.trim(),
          'last_name': lastNameController.text.trim(),
          'suffix': suffixController.text.trim(),
          'email': email,
          'password': password,
          'confirmPassword': confirmPasswordController.text,
          'code': code,
          'role': 'user',
        }),
      ).timeout(const Duration(seconds: 20));

      if (!mounted) return;

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 && data['success'] == true) {
        _showSuccess('Account created successfully!');
        
        // Save login state if auto-login is enabled
        if (data['user'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true);
          await prefs.setString('userEmail', email);
          
          final user = data['user'] as Map<String, dynamic>?;
          if (user != null) {
            await prefs.setString('userName', user['name'] ?? '');
            await prefs.setString('userId', user['id']?.toString() ?? '');
          }
        }

        await Future.delayed(const Duration(milliseconds: 500));
        
        if (!mounted) return;
        
        // Navigate to login or dashboard
        try {
          if (data['redirect_url'] != null) {
            Navigator.pushReplacementNamed(context, '/dashboard');
          } else {
            Navigator.pushReplacementNamed(context, '/login');
          }
        } catch (_) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      } else {
        _showError(data['message'] ?? 'Signup failed. Please try again.');
      }
    } on TimeoutException catch (_) {
      _showError('Request timed out. Please try again.');
    } catch (e) {
      _showError('Connection error. Please check your server is running.');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const maxWidth = 480.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F4),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // TOP HEADER CARD
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF059669), Color(0xFF064E3B)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: -10,
                          left: -20,
                          child: Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: -20,
                          right: -20,
                          child: Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Likhayag',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 6),
                              Icon(Icons.bookmark,
                                  color: Colors.white70, size: 22),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // FORM CARD
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Create account',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF064E3B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Join the Likhayag organization',
                          style: TextStyle(
                              fontSize: 13, color: Color(0xFF6B7280)),
                        ),
                        const SizedBox(height: 18),

                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              // Name fields
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: firstNameController,
                                      decoration: _fieldDecoration(
                                        label: 'First name',
                                        prefix: Icons.person,
                                      ),
                                      validator: (v) => (v == null || v.isEmpty)
                                          ? 'Required'
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: lastNameController,
                                      decoration: _fieldDecoration(
                                        label: 'Last name',
                                        prefix: Icons.person_outline,
                                      ),
                                      validator: (v) => (v == null || v.isEmpty)
                                          ? 'Required'
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: middleNameController,
                                      decoration: _fieldDecoration(
                                        label: 'Middle (optional)',
                                        prefix: Icons.badge,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: suffixController,
                                      decoration: _fieldDecoration(
                                        label: 'Suffix (optional)',
                                        prefix:
                                            Icons.subdirectory_arrow_left,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 14),

                              // Email field
                              TextFormField(
                                controller: emailController,
                                decoration: _fieldDecoration(
                                  label: 'Email',
                                  prefix: Icons.email_outlined,
                                ),
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Email required';
                                  }
                                  final emailRegex =
                                      RegExp(r"^[\w\.-]+@[\w\.-]+\.\w+$");
                                  if (!emailRegex.hasMatch(value)) {
                                    return 'Invalid email';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 14),

                              // 2FA Code section
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: Colors.blue.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.security,
                                            color: Colors.blue.shade700,
                                            size: 20),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Email Verification Required',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.blue.shade700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'We\'ll send a verification code to your email',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            controller: twoFaCodeController,
                                            decoration: InputDecoration(
                                              labelText: 'Verification Code',
                                              hintText: 'Enter code',
                                              filled: true,
                                              fillColor: Colors.white,
                                              contentPadding:
                                                  const EdgeInsets
                                                      .symmetric(
                                                      vertical: 12,
                                                      horizontal: 12),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        10),
                                                borderSide: BorderSide.none,
                                              ),
                                            ),
                                            enabled: _codeSent,
                                            validator: (v) =>
                                                (v == null || v.isEmpty)
                                                    ? 'Required'
                                                    : null,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton(
                                          onPressed: (_isSendingCode ||
                                                  _resendCountdown > 0)
                                              ? null
                                              : _sendVerificationCode,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: kEmerald,
                                            padding: const EdgeInsets
                                                .symmetric(
                                                horizontal: 16,
                                                vertical: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                          child: _isSendingCode
                                              ? const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : Text(
                                                  _resendCountdown > 0
                                                      ? '$_resendCountdown'
                                                      : (_codeSent
                                                          ? 'Resend'
                                                          : 'Send'),
                                                  style: const TextStyle(
                                                      color: Colors.white),
                                                ),
                                        ),
                                      ],
                                    ),
                                    if (_codeSent)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 8),
                                        child: Text(
                                          _resendCountdown > 0
                                              ? 'Resend in $_resendCountdown seconds'
                                              : 'Code sent! Check your email',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.green.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 14),

                              // Password field with strength indicator
                              Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: [
                                  TextFormField(
                                    controller: passwordController,
                                    obscureText: obscurePassword,
                                    decoration: _fieldDecoration(
                                      label: 'Password',
                                      prefix: Icons.lock_outline,
                                      suffix: IconButton(
                                        icon: Icon(obscurePassword
                                            ? Icons.visibility
                                            : Icons.visibility_off),
                                        onPressed: () => setState(() =>
                                            obscurePassword =
                                                !obscurePassword),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Password required';
                                      }
                                      if (value.length < 8) {
                                        return 'Min 8 characters';
                                      }
                                      if (_pwdStrength < 0.25) {
                                        return 'Password is too weak';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  
                                  // Strength bar
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          child: LinearProgressIndicator(
                                            value: _pwdStrength,
                                            minHeight: 8,
                                            backgroundColor:
                                                Colors.grey.shade200,
                                            valueColor:
                                                AlwaysStoppedAnimation<
                                                    Color>(
                                              _colorForStrength(
                                                  _pwdStrength),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        _pwdStrengthLabel,
                                        style: TextStyle(
                                          color: _colorForStrength(
                                              _pwdStrength),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // Suggestions
                                  if (_pwdSuggestions.isNotEmpty)
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children:
                                            _pwdSuggestions.map((s) {
                                          return Chip(
                                            label: Text(s,
                                                style: const TextStyle(
                                                    fontSize: 12)),
                                            backgroundColor:
                                                Colors.grey.shade100,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              side: BorderSide(
                                                color: _colorForStrength(
                                                        _pwdStrength)
                                                    .withOpacity(0.15),
                                              ),
                                            ),
                                            avatar: Icon(
                                              Icons.info_outline,
                                              size: 16,
                                              color: _colorForStrength(
                                                  _pwdStrength),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                ],
                              ),

                              const SizedBox(height: 14),

                              // Confirm password
                              TextFormField(
                                controller: confirmPasswordController,
                                obscureText: obscureConfirmPassword,
                                decoration: _fieldDecoration(
                                  label: 'Confirm password',
                                  prefix: Icons.lock_outline,
                                  suffix: IconButton(
                                    icon: Icon(obscureConfirmPassword
                                        ? Icons.visibility
                                        : Icons.visibility_off),
                                    onPressed: () => setState(() =>
                                        obscureConfirmPassword =
                                            !obscureConfirmPassword),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Confirm your password';
                                  }
                                  if (value != passwordController.text) {
                                    return 'Passwords do not match';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 14),

                              // Terms checkbox
                              Row(
                                children: [
                                  Checkbox(
                                    value: acceptTerms,
                                    onChanged: (v) =>
                                        setState(() => acceptTerms = v ?? false),
                                    activeColor: const Color(0xFF059669),
                                  ),
                                  const Expanded(
                                    child: Text(
                                      "I agree to the Terms & Privacy",
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF4B5563)),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 10),

                              // Create account button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed:
                                      _isSubmitting ? null : _submit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        const Color(0xFF059669),
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor:
                                        const Color(0xFF059669)
                                            .withOpacity(0.6),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: _isSubmitting
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child:
                                              CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          "Create account",
                                          style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white),
                                        ),
                                ),
                              ),

                              const SizedBox(height: 18),

                              // Sign in link
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  const Text(
                                      "Already have an account? ",
                                      style: TextStyle(
                                          color: Color(0xFF6B7280))),
                                  GestureDetector(
                                    onTap: () => Navigator.pushNamed(
                                        context, '/login'),
                                    child: const Text(
                                      "Sign in",
                                      style: TextStyle(
                                        color: Color(0xFF059669),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  Center(
                    child: Text(
                      "By continuing you agree to our Terms & Privacy",
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.35),
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}