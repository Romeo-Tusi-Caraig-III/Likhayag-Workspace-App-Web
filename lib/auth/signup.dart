// lib/auth/signup.dart
import 'package:flutter/material.dart';

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

  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  bool acceptTerms = false;

  // password strength state
  double _pwdStrength = 0.0; // 0.0 - 1.0
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
    passwordController.removeListener(_updatePasswordStrength);
    firstNameController.dispose();
    lastNameController.dispose();
    middleNameController.dispose();
    suffixController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
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

  /// Basic heuristic to return strength between 0.0 and 1.0
  double _calculatePasswordStrength(String pwd) {
    if (pwd.isEmpty) return 0.0;

    double score = 0;

    // length contribution
    if (pwd.length >= 12) score += 0.35;
    else if (pwd.length >= 8) score += 0.20;
    else if (pwd.length >= 6) score += 0.08;
    else score += 0.02;

    // variety checks
    final hasLower = RegExp(r'[a-z]').hasMatch(pwd);
    final hasUpper = RegExp(r'[A-Z]').hasMatch(pwd);
    final hasDigit = RegExp(r'\d').hasMatch(pwd);
    final hasSymbol = RegExp(r'[^A-Za-z0-9]').hasMatch(pwd);

    final varietyCount = [hasLower, hasUpper, hasDigit, hasSymbol].where((e) => e).length;

    // each variety adds some
    score += (varietyCount / 4) * 0.55; // up to 0.55

    // penalty for common short patterns (simple heuristics)
    if (pwd.length < 6) score *= 0.6;
    if (RegExp(r'^[0-9]+$').hasMatch(pwd)) score *= 0.5; // only digits

    // clamp
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

  /// Provide actionable suggestions based on what's missing from the password.
  List<String> _suggestionsForPassword(String pwd) {
    final suggestions = <String>[];

    if (pwd.length < 12) {
      suggestions.add('Use 12+ characters');
    } else if (pwd.length < 8) {
      // this branch is unlikely because 12+ checked first, but keep fallback
      suggestions.add('Use at least 8 characters');
    }

    if (!RegExp(r'[A-Z]').hasMatch(pwd)) suggestions.add('Add an uppercase letter (A)');
    if (!RegExp(r'[a-z]').hasMatch(pwd)) suggestions.add('Add a lowercase letter (a)');
    if (!RegExp(r'\d').hasMatch(pwd)) suggestions.add('Include a number (0-9)');
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(pwd)) suggestions.add('Include a symbol (!@#\$%)');

    // If password is fairly long and contains variety, prioritize uniqueness suggestion:
    if (pwd.length >= 12 &&
        RegExp(r'[A-Z]').hasMatch(pwd) &&
        RegExp(r'[a-z]').hasMatch(pwd) &&
        RegExp(r'\d').hasMatch(pwd) &&
        RegExp(r'[^A-Za-z0-9]').hasMatch(pwd) &&
        suggestions.isEmpty) {
      suggestions.add('Looks good — consider a passphrase for extra safety');
    }

    // Limit suggestions to 4 most useful
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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (!acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept the Terms & Privacy')),
      );
      return;
    }

    final fullName = [
      firstNameController.text.trim(),
      middleNameController.text.trim(),
      lastNameController.text.trim(),
      suffixController.text.trim(),
    ].where((s) => s.isNotEmpty).join(' ');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Account created for $fullName!')),
    );

    Navigator.pushReplacementNamed(context, '/dashboard');
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
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Text(
                                'Name.App',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 6),
                              Icon(Icons.bookmark, color: Colors.white70, size: 22),
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
                          style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                        ),
                        const SizedBox(height: 18),

                        Form(
                          key: _formKey,
                          child: Column(
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
                                      validator: (v) =>
                                          (v == null || v.isEmpty) ? 'Required' : null,
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
                                      validator: (v) =>
                                          (v == null || v.isEmpty) ? 'Required' : null,
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
                                        prefix: Icons.subdirectory_arrow_left,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 14),

                              TextFormField(
                                controller: emailController,
                                decoration: _fieldDecoration(
                                  label: 'Email',
                                  prefix: Icons.email_outlined,
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) return 'Email required';
                                  final emailRegex = RegExp(r"^[\w\.-]+@[\w\.-]+\.\w+$");
                                  if (!emailRegex.hasMatch(value)) return 'Invalid email';
                                  return null;
                                },
                              ),

                              const SizedBox(height: 14),

                              // Password field with strength indicator + suggestions
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                        onPressed: () => setState(
                                            () => obscurePassword = !obscurePassword),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) return 'Password required';
                                      if (value.length < 6) return 'Min 6 characters';
                                      if (_pwdStrength < 0.25) return 'Password is too weak';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  // strength bar + label
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: LinearProgressIndicator(
                                            value: _pwdStrength,
                                            minHeight: 8,
                                            backgroundColor: Colors.grey.shade200,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              _colorForStrength(_pwdStrength),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        _pwdStrengthLabel,
                                        style: TextStyle(
                                          color: _colorForStrength(_pwdStrength),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // Suggestions displayed as chips
                                  if (_pwdSuggestions.isNotEmpty)
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: _pwdSuggestions.map((s) {
                                          return Chip(
                                            label: Text(s, style: const TextStyle(fontSize: 12)),
                                            backgroundColor: Colors.grey.shade100,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                              side: BorderSide(
                                                color: _colorForStrength(_pwdStrength).withOpacity(0.15),
                                              ),
                                            ),
                                            avatar: Icon(
                                              Icons.info_outline,
                                              size: 16,
                                              color: _colorForStrength(_pwdStrength),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                ],
                              ),

                              const SizedBox(height: 14),

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
                                  if (value == null || value.isEmpty) return 'Confirm your password';
                                  if (value != passwordController.text) return 'Passwords do not match';
                                  return null;
                                },
                              ),

                              const SizedBox(height: 14),

                              Row(
                                children: [
                                  Checkbox(
                                    value: acceptTerms,
                                    onChanged: (v) => setState(() => acceptTerms = v ?? false),
                                    activeColor: const Color(0xFF059669),
                                  ),
                                  const Text(
                                    "I agree to the Terms & Privacy",
                                    style: TextStyle(
                                        fontSize: 13, color: Color(0xFF4B5563)),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 10),

                              // CREATE ACCOUNT BUTTON — updated to emerald green with white text
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _submit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF059669), // emerald
                                    foregroundColor: Colors.white, // white text
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    "Create account",
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 18),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text("Already have an account? ",
                                      style: TextStyle(
                                          color: Color(0xFF6B7280))),
                                  GestureDetector(
                                    onTap: () =>
                                        Navigator.pushNamed(context, '/login'),
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
