// lib/login_page.dart
// Updated with role-based routing

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/api_service.dart';

const Color kEmerald = Color(0xFF059669);

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _rememberMe = false;
  bool _showPassword = false;
  bool _isSubmitting = false;

  late final AnimationController _animController;
  late final Animation<double> _headerAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 700)
    );
    _headerAnim = CurvedAnimation(
      parent: _animController, 
      curve: Curves.easeOutQuart
    );
    _animController.forward();
    _loadRememberedEmail();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _loadRememberedEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rememberedEmail = prefs.getString('remembered_email');
      if (rememberedEmail != null && rememberedEmail.isNotEmpty) {
        setState(() {
          _emailController.text = rememberedEmail;
          _rememberMe = true;
        });
      }
    } catch (e) {
      debugPrint('Failed to load remembered email: $e');
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email';
    }
    final v = value.trim();
    final emailRegex = RegExp(r"^[^\s@]+@[^\s@]+\.[^\s@]+$");
    if (!emailRegex.hasMatch(v)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  Future<void> _onSignIn() async {
    if (!_formKey.currentState!.validate()) {
      if (_validateEmail(_emailController.text) != null) {
        FocusScope.of(context).requestFocus(_emailFocus);
      } else {
        FocusScope.of(context).requestFocus(_passwordFocus);
      }
      return;
    }

    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      debugPrint('🔐 Attempting login via ApiService...');
      final result = await ApiService.login(email, password);

      if (!mounted) return;

      debugPrint('Login result: $result');

      if (result['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        
        // Save remember me preference
        if (_rememberMe) {
          await prefs.setString('remembered_email', email);
        } else {
          await prefs.remove('remembered_email');
        }
        
        // Save login state and user info
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('userEmail', email);
        
        // Extract user data from response
        final user = result['user'] as Map<String, dynamic>?;
        if (user != null) {
          await prefs.setString('userName', user['name'] ?? '');
          await prefs.setString('userId', user['id']?.toString() ?? '');
          
          // Save user role
          final role = (user['role'] ?? 'user').toString().toLowerCase();
          await prefs.setString('userRole', role);
          
          debugPrint('✅ User role saved: $role');
          debugPrint('✅ User email: $email');
        }

        _showSuccess('Login successful!');
        
        // Small delay for user feedback
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        
        // Navigate to role-based home (will redirect to appropriate screen)
        Navigator.pushNamedAndRemoveUntil(
          context, 
          '/home', 
          (Route<dynamic> route) => false
        );

      } else {
        final message = result['message'] ?? 'Login failed';
        _showError(message);
      }
    } on TimeoutException catch (_) {
      _showError('Request timed out. Please check your connection.');
    } catch (e, st) {
      debugPrint('Login error: $e\n$st');
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

  void _onForgotPassword() {
    _showError('Forgot password not implemented yet');
  }

  void _onSignUp() {
    try {
      Navigator.pushNamed(context, '/signup');
    } catch (_) {
      _showError('Signup page not configured');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 18),
            child: Column(
              children: [
                SizeTransition(
                  axisAlignment: -1.0,
                  sizeFactor: _headerAnim,
                  child: _buildHeader(context),
                ),
                const SizedBox(height: 28),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 280,
                      maxWidth: 480,
                    ),
                    child: FractionallySizedBox(
                      widthFactor: 1.0,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Welcome back',
                              style: TextStyle(
                                color: kEmerald,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Sign in to continue to Likhayag',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),

                            const SizedBox(height: 18),

                            Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  _InputPill(
                                    controller: _emailController,
                                    hint: 'Email',
                                    prefix: const Icon(Icons.email_outlined),
                                    focusNode: _emailFocus,
                                    keyboardType: TextInputType.emailAddress,
                                    autofillHints: const [AutofillHints.email],
                                    validator: _validateEmail,
                                    textInputAction: TextInputAction.next,
                                    onFieldSubmitted: (_) =>
                                        FocusScope.of(context)
                                            .requestFocus(_passwordFocus),
                                  ),
                                  const SizedBox(height: 12),
                                  
                                  _InputPill(
                                    controller: _passwordController,
                                    hint: 'Password',
                                    prefix: const Icon(Icons.lock_outline),
                                    obscureText: !_showPassword,
                                    focusNode: _passwordFocus,
                                    autofillHints: const [AutofillHints.password],
                                    validator: _validatePassword,
                                    textInputAction: TextInputAction.done,
                                    onFieldSubmitted: (_) => _onSignIn(),
                                    suffix: IconButton(
                                      icon: Icon(
                                        _showPassword
                                            ? Icons.visibility
                                            : Icons.visibility_off,
                                        size: 20,
                                      ),
                                      onPressed: () => setState(() =>
                                          _showPassword = !_showPassword),
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      GestureDetector(
                                        onTap: () => setState(
                                            () => _rememberMe = !_rememberMe),
                                        child: Row(
                                          children: [
                                            AnimatedContainer(
                                              duration: const Duration(
                                                  milliseconds: 220),
                                              width: 36,
                                              height: 22,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 2),
                                              decoration: BoxDecoration(
                                                color: _rememberMe
                                                    ? kEmerald
                                                    : Colors.grey.shade300,
                                                borderRadius:
                                                    BorderRadius.circular(30),
                                              ),
                                              child: Align(
                                                alignment: _rememberMe
                                                    ? Alignment.centerRight
                                                    : Alignment.centerLeft,
                                                child: Container(
                                                  width: 16,
                                                  height: 16,
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              'Remember me',
                                              style: TextStyle(
                                                  color: Colors.grey[800]),
                                            ),
                                          ],
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: _onForgotPassword,
                                        style: TextButton.styleFrom(
                                            foregroundColor: kEmerald),
                                        child: const Text('Forgot password?'),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 12),

                                  SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: ElevatedButton(
                                      onPressed:
                                          _isSubmitting ? null : _onSignIn,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: kEmerald,
                                        disabledBackgroundColor:
                                            kEmerald.withOpacity(0.6),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                      ),
                                      child: _isSubmitting
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Text(
                                              'Sign In',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 22),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text("Don't have an account? "),
                                GestureDetector(
                                  onTap: _onSignUp,
                                  child: const Text(
                                    "Sign up",
                                    style: TextStyle(
                                      color: kEmerald,
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),
                Text(
                  'By continuing you agree to our Terms & Privacy',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SizedBox(
      height: 220,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF12D58E), Color(0xFF059669)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
            ),
          ),
          Positioned(
            right: -40,
            top: 10,
            child: Opacity(
              opacity: 0.12,
              child: Container(
                width: 160,
                height: 160,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Positioned(
            left: -30,
            top: 40,
            child: Opacity(
              opacity: 0.08,
              child: Container(
                width: 110,
                height: 110,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: -28,
            child: Center(
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Center(
                  child: SvgPicture.string(
                    '<svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253"></path></svg>',
                  ),
                ),
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            top: 32,
            child: Center(
              child: Text(
                'Likhayag',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InputPill extends StatelessWidget {
  const _InputPill({
    required this.controller,
    required this.hint,
    this.prefix,
    this.suffix,
    this.obscureText = false,
    this.validator,
    this.focusNode,
    this.autofillHints,
    this.keyboardType,
    this.textInputAction,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final Widget? prefix;
  final Widget? suffix;
  final bool obscureText;
  final String? Function(String?)? validator;
  final FocusNode? focusNode;
  final Iterable<String>? autofillHints;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.grey.shade200),
    );

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      validator: validator,
      autofillHints: autofillHints,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFFF7F8FA),
        hintText: hint,
        prefixIcon: prefix == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(left: 10, right: 6),
                child: IconTheme(
                  data: IconThemeData(color: Colors.grey[700]),
                  child: prefix!,
                ),
              ),
        suffixIcon: suffix,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        enabledBorder: border,
        focusedBorder:
            border.copyWith(borderSide: const BorderSide(color: kEmerald)),
        errorBorder:
            border.copyWith(borderSide: const BorderSide(color: Colors.red)),
        focusedErrorBorder:
            border.copyWith(borderSide: const BorderSide(color: Colors.red)),
      ),
    );
  }
}