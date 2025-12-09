// lib/pages/signup_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

const Color kEmerald = Color(0xFF059669);
const Color kDarkTeal = Color(0xFF064E3B);
const Color kGold1 = Color(0xFFEAB308);

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> with SingleTickerProviderStateMixin {
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
  bool _showExtras = false;

  // Password strength state
  double _pwdStrength = 0.0;
  String _pwdStrengthLabel = 'Very weak';
  Color _pwdStrengthColor = Colors.red.shade400;
  List<String> _pwdSuggestions = [];

  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    passwordController.addListener(_updatePasswordStrength);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();
    _updatePasswordStrength();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _animController.dispose();
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
    final color = _colorForStrength(strength);
    final suggestions = _suggestionsForPassword(pwd);
    
    setState(() {
      _pwdStrength = strength;
      _pwdStrengthLabel = label;
      _pwdStrengthColor = color;
      _pwdSuggestions = suggestions;
    });
  }

  double _calculatePasswordStrength(String pwd) {
    if (pwd.isEmpty) return 0.0;
    
    double score = 0;
    
    // Length scoring
    if (pwd.length >= 12) {
      score += 0.35;
    } else if (pwd.length >= 8) {
      score += 0.20;
    } else {
      score += 0.05;
    }
    
    // Character variety
    final hasLower = RegExp(r'[a-z]').hasMatch(pwd);
    final hasUpper = RegExp(r'[A-Z]').hasMatch(pwd);
    final hasDigit = RegExp(r'\d').hasMatch(pwd);
    final hasSymbol = RegExp(r'[!@#$%^&*()_\-+=\[\]{};:"|<>,.?/\\]').hasMatch(pwd);
    
    final varietyCount = [hasLower, hasUpper, hasDigit, hasSymbol].where((e) => e).length;
    score += (varietyCount / 4) * 0.55;
    
    // Penalties
    if (pwd.length < 8) score *= 0.6;
    
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
    
    if (pwd.length < 8) {
      suggestions.add('Use at least 8 characters');
    }
    if (!RegExp(r'[A-Z]').hasMatch(pwd)) {
      suggestions.add('Add uppercase letter (A-Z)');
    }
    if (!RegExp(r'[a-z]').hasMatch(pwd)) {
      suggestions.add('Add lowercase letter (a-z)');
    }
    if (!RegExp(r'\d').hasMatch(pwd)) {
      suggestions.add('Include a number (0-9)');
    }
    if (!RegExp(r'[!@#$%^&*()_\-+=\[\]{};:"|<>,.?/\\]').hasMatch(pwd)) {
      suggestions.add('Include special char (!@#%)');
    }
    
    if (suggestions.isEmpty && pwd.length >= 8) {
      suggestions.add('Great password! Consider 12+ chars');
    }
    
    return suggestions.take(3).toList();
  }

  bool _isPasswordValid(String pwd) {
    if (pwd.length < 8) return false;
    
    final hasUpper = RegExp(r'[A-Z]').hasMatch(pwd);
    final hasLower = RegExp(r'[a-z]').hasMatch(pwd);
    final hasDigit = RegExp(r'\d').hasMatch(pwd);
    final hasSpecial = RegExp(r'[!@#$%^&*()_\-+=\[\]{};:"|<>,.?/\\]').hasMatch(pwd);
    
    return hasUpper && hasLower && hasDigit && hasSpecial;
  }

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

    if (!email.endsWith('@gmail.com') && email != 'admin@admin.com') {
      _showError('Email must be Gmail or admin account');
      return;
    }

    setState(() => _isSendingCode = true);

    try {
      final response = await ApiService.send2FA(email);
      
      if (!mounted) return;

      if (response['success'] == true) {
        setState(() {
          _codeSent = true;
          _resendCountdown = 60;
        });
        
        _showSuccess(response['message'] ?? 'Verification code sent!');
        
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
        _showError(response['message'] ?? 'Failed to send code');
      }
    } on TimeoutException catch (_) {
      _showError('Request timed out. Please try again.');
    } catch (e) {
      _showError('Failed to send code. Check your connection.');
    } finally {
      if (mounted) {
        setState(() => _isSendingCode = false);
      }
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (!acceptTerms) {
      _showError('Please accept the Terms & Privacy');
      return;
    }

    final password = passwordController.text;
    if (!_isPasswordValid(password)) {
      _showError('Password must contain uppercase, lowercase, number & special character');
      return;
    }

    if (!_codeSent || twoFaCodeController.text.trim().isEmpty) {
      _showError('Please request and enter verification code');
      return;
    }

    setState(() => _isSubmitting = true);

    final email = emailController.text.trim();
    final code = twoFaCodeController.text.trim();

    try {
      final data = {
        'first_name': firstNameController.text.trim(),
        'middle_name': middleNameController.text.trim(),
        'last_name': lastNameController.text.trim(),
        'suffix': suffixController.text.trim(),
        'email': email,
        'password': password,
        'confirmPassword': confirmPasswordController.text,
        'code': code,
        'role': 'user',
      };

      final response = await ApiService.signup(data);

      if (!mounted) return;

      if (response['success'] == true) {
        _showSuccess('Account created successfully!');
        
        if (response['user'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true);
          await prefs.setString('userEmail', email);
          
          final user = response['user'] as Map<String, dynamic>?;
          if (user != null) {
            await prefs.setString('userName', user['name'] ?? '');
            await prefs.setString('userId', user['id']?.toString() ?? '');
            await prefs.setString('userRole', (user['role'] ?? 'user').toString().toLowerCase());
          }
        }

        await Future.delayed(const Duration(milliseconds: 500));
        
        if (!mounted) return;
        
        if (response['redirect_url'] != null) {
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          Navigator.pushReplacementNamed(context, '/login');
        }
      } else {
        _showError(response['message'] ?? 'Signup failed. Please try again.');
      }
    } on TimeoutException catch (_) {
      _showError('Request timed out. Please try again.');
    } catch (e) {
      _showError('Connection error. Check your server.');
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
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0F766E),
              const Color(0xFF064E3B),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    _buildLogo(),
                    const SizedBox(height: 24),
                    _buildSignupCard(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF059669)],
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.book_rounded,
            size: 50,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Likhayag',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildSignupCard() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Create Account',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: kDarkTeal,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Join the Likhayag organization',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            
            _buildNameFields(),
            const SizedBox(height: 14),
            
            _buildEmailField(),
            const SizedBox(height: 14),
            
            _build2FASection(),
            const SizedBox(height: 14),
            
            _buildPasswordField(),
            const SizedBox(height: 14),
            
            _buildConfirmPasswordField(),
            const SizedBox(height: 14),
            
            _buildTermsCheckbox(),
            const SizedBox(height: 16),
            
            _buildCreateButton(),
            const SizedBox(height: 16),
            
            _buildDivider(),
            const SizedBox(height: 16),
            
            _buildSignInLink(),
          ],
        ),
      ),
    );
  }

  Widget _buildNameFields() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: firstNameController,
                decoration: _fieldDecoration(
                  label: 'First name',
                  prefix: Icons.person,
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (RegExp(r'\d').hasMatch(v)) return 'No numbers';
                  return null;
                },
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
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (RegExp(r'\d').hasMatch(v)) return 'No numbers';
                  return null;
                },
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _showExtras = !_showExtras),
            icon: Icon(
              _showExtras ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: kEmerald,
            ),
            label: Text(
              _showExtras ? 'Hide extras' : 'Add middle/suffix',
              style: const TextStyle(color: kEmerald, fontSize: 13),
            ),
          ),
        ),
        if (_showExtras) ...[
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: middleNameController,
                  decoration: _fieldDecoration(
                    label: 'Middle (opt)',
                    prefix: Icons.badge,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: suffixController,
                  decoration: _fieldDecoration(
                    label: 'Suffix (opt)',
                    prefix: Icons.subdirectory_arrow_left,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: emailController,
      keyboardType: TextInputType.emailAddress,
      decoration: _fieldDecoration(
        label: 'Email',
        prefix: Icons.email_outlined,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Email required';
        if (!RegExp(r"^[\w\.-]+@[\w\.-]+\.\w+$").hasMatch(value)) {
          return 'Invalid email';
        }
        if (!value.endsWith('@gmail.com') && value != 'admin@admin.com') {
          return 'Must be Gmail or admin account';
        }
        return null;
      },
    );
  }

  Widget _build2FASection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.security, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Email Verification Required',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.blue.shade700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'We\'ll send a code to verify your email',
            style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
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
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  enabled: _codeSent,
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: (_isSendingCode || _resendCountdown > 0)
                    ? null
                    : _sendVerificationCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kEmerald,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isSendingCode
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _resendCountdown > 0
                            ? '$_resendCountdown'
                            : (_codeSent ? 'Resend' : 'Send'),
                        style: const TextStyle(color: Colors.white),
                      ),
              ),
            ],
          ),
          if (_codeSent)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _resendCountdown > 0
                    ? 'Resend in $_resendCountdown seconds'
                    : 'Code sent! Check your email',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: passwordController,
          obscureText: obscurePassword,
          decoration: _fieldDecoration(
            label: 'Password',
            prefix: Icons.lock_outline,
            suffix: IconButton(
              icon: Icon(
                obscurePassword ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: () => setState(() => obscurePassword = !obscurePassword),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Password required';
            if (!_isPasswordValid(value)) {
              return 'Need uppercase, lowercase, number & special char';
            }
            return null;
          },
        ),
        const SizedBox(height: 8),
        
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _pwdStrength,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(_pwdStrengthColor),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _pwdStrengthLabel,
              style: TextStyle(
                color: _pwdStrengthColor,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
        
        if (_pwdSuggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _pwdSuggestions.map((s) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _pwdStrengthColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline, size: 12, color: _pwdStrengthColor),
                    const SizedBox(width: 4),
                    Text(s, style: const TextStyle(fontSize: 11)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildConfirmPasswordField() {
    return TextFormField(
      controller: confirmPasswordController,
      obscureText: obscureConfirmPassword,
      decoration: _fieldDecoration(
        label: 'Confirm password',
        prefix: Icons.lock_outline,
        suffix: IconButton(
          icon: Icon(
            obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
          ),
          onPressed: () =>
              setState(() => obscureConfirmPassword = !obscureConfirmPassword),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Confirm password';
        if (value != passwordController.text) return 'Passwords don\'t match';
        return null;
      },
    );
  }

  Widget _buildTermsCheckbox() {
    return Row(
      children: [
        Checkbox(
          value: acceptTerms,
          onChanged: (v) => setState(() => acceptTerms = v ?? false),
          activeColor: kEmerald,
        ),
        const Expanded(
          child: Text(
            "I agree to the Terms & Privacy",
            style: TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
          ),
        ),
      ],
    );
  }

  Widget _buildCreateButton() {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: kGold1,
          disabledBackgroundColor: kGold1.withOpacity(0.6),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Text(
                'CREATE ACCOUNT',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'or',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ),
        Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
      ],
    );
  }

  Widget _buildSignInLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Already have an account? ",
          style: TextStyle(color: Colors.grey[700], fontSize: 14),
        ),
        GestureDetector(
          onTap: () => Navigator.pushReplacementNamed(context, '/login'),
          child: const Text(
            "Sign in",
            style: TextStyle(
              color: kEmerald,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    IconData? prefix,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: prefix == null ? null : Icon(prefix, color: kEmerald),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF7F7F8),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kEmerald, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
    );
  }
}