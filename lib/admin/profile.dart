import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(ProfileApp());

/// Emerald gradient colors (user-provided)
const Color emeraldStart = Color(0xFF10B981); // #10B981
const Color emeraldEnd = Color(0xFF059669); // #059669

/// Small reusable gradient pill button
class GradientPill extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final double elevation;

  const GradientPill({
    required this.onPressed,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    this.borderRadius = const BorderRadius.all(Radius.circular(28)),
    this.elevation = 6,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: elevation,
      borderRadius: borderRadius,
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [emeraldStart, emeraldEnd]),
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(color: emeraldEnd.withOpacity(0.18), blurRadius: 10, offset: const Offset(0, 6)),
          ],
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: borderRadius,
          child: Padding(padding: padding, child: DefaultTextStyle(style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700), child: child)),
        ),
      ),
    );
  }
}

/// A compact gradient button with optional icon
class GradientIconPill extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  const GradientIconPill({required this.onPressed, required this.icon, required this.label, super.key});

  @override
  Widget build(BuildContext context) {
    return GradientPill(
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

class ProfileApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(seedColor: emeraldStart).copyWith(secondary: emeraldEnd);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Profile',
      theme: ThemeData(
        colorScheme: colorScheme,
        primaryColor: emeraldStart,
        scaffoldBackgroundColor: const Color(0xFFF9F7FB),
        useMaterial3: true,
        textTheme: ThemeData.light().textTheme.apply(fontFamily: 'Roboto'),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        // Use CardThemeData (Material 3 / newer SDKs expect CardThemeData)
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      home: ProfilePage(),
    );
  }
}

class ProfileData {
  Map<String, dynamic> profile;
  Map<String, dynamic> academic;
  Map<String, dynamic> personal;
  Map<String, dynamic> settings;

  ProfileData({
    required this.profile,
    required this.academic,
    required this.personal,
    required this.settings,
  });

  factory ProfileData.defaultData() => ProfileData(
        profile: {
          'lastName': 'Last Name',
          'firstName': 'First Name',
          'middleName': '',
          'suffix': '',
          'email': 'student@university.edu',
          'status': 'Active Student',
        },
        academic: {
          'school': 'School Name',
          'strand': 'STEM',
          'gradeLevel': 'Grade 12',
          'schoolYear': '2022 - 2023',
          'lrn': '0000-0000-0000',
          'adviserSection': 'Mrs. Smith / Section A',
        },
        personal: {
          'phone': '+63 912 345 6789',
          'dob': 'January 15, 2003',
          'address': 'Manila, Philippines',
          'emergency': '+63 998 765 4321',
        },
        settings: {
          'emailNotifications': true,
          'twoFactor': false,
        },
      );

  factory ProfileData.fromJson(Map<String, dynamic> json) => ProfileData(
        profile: Map<String, dynamic>.from(json['profile']),
        academic: Map<String, dynamic>.from(json['academic']),
        personal: Map<String, dynamic>.from(json['personal']),
        settings: Map<String, dynamic>.from(json['settings']),
      );

  Map<String, dynamic> toJson() => {
        'profile': profile,
        'academic': academic,
        'personal': personal,
        'settings': settings,
      };
}

class ProfileRepository {
  static const String storageKey = 'studentProfileData_v5';

  final SharedPreferences prefs;
  ProfileRepository(this.prefs);

  ProfileData load() {
    try {
      final raw = prefs.getString(storageKey);
      if (raw == null) return ProfileData.defaultData();
      final jsonData = json.decode(raw) as Map<String, dynamic>;
      return ProfileData.fromJson(jsonData);
    } catch (e) {
      return ProfileData.defaultData();
    }
  }

  Future<void> save(ProfileData data) async {
    await prefs.setString(storageKey, json.encode(data.toJson()));
  }
}

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late SharedPreferences _prefs;
  late ProfileRepository _repo;
  late ProfileData _data;
  bool _loading = true;

  // Local path to the image provided in the container (for demo).
  final String providedImagePath = '/mnt/data/278f207a-dd02-4580-a6de-aa2e2f847c1d.png';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    _repo = ProfileRepository(_prefs);
    _data = _repo.load();
    setState(() => _loading = false);
  }

  String getDisplayName() {
    final p = _data.profile;
    final middle = (p['middleName'] ?? '').toString();
    final suffix = (p['suffix'] ?? '').toString();
    final middleDisplay = middle.isNotEmpty
        ? (middle.trim().length == 1 ? '${middle.trim()}.' : middle.trim())
        : '';
    final suffixDisplay = suffix.isNotEmpty ? ', ${suffix.trim()}' : '';
    final mid = middleDisplay.isNotEmpty ? ' $middleDisplay' : '';
    return '${p['lastName']}, ${p['firstName']}$mid$suffixDisplay';
  }

  Future<void> _openEditSheet(String title, String formKey) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return Padding(
          padding: MediaQuery.of(ctx).viewInsets,
          child: EditForm(
            title: title,
            initialData: _getFormInitial(formKey),
            onSave: (updated) => Navigator.of(ctx).pop(updated),
            formKey: formKey,
          ),
        );
      },
    );

    if (result != null) {
      setState(() {
        if (formKey == 'profile') _data.profile = result;
        if (formKey == 'academic') _data.academic = result;
        if (formKey == 'personal') _data.personal = result;
        if (formKey == 'password') {
          // Password change simulated (no backend).
        }
      });

      await _repo.save(_data);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved successfully')));
    }
  }

  Map<String, dynamic> _getFormInitial(String key) {
    if (key == 'profile') return Map<String, dynamic>.from(_data.profile);
    if (key == 'academic') return Map<String, dynamic>.from(_data.academic);
    if (key == 'personal') return Map<String, dynamic>.from(_data.personal);
    return {};
  }

  Widget _buildChip(String label, String value) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEBEEF2)),
      ),
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F1722))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Profile', style: TextStyle(color: Color(0xFF0F1722), fontWeight: FontWeight.w800, fontSize: 18)),
            SizedBox(height: 2),
            Text('Manage your personal and academic information', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14.0),
            child: GradientPill(
              onPressed: () => _openEditSheet('Edit Profile', 'profile'),
              child: Row(children: const [Icon(Icons.edit, size: 16), SizedBox(width: 8), Text('Edit Profile')]),
            ),
          )
        ],
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        final gridCols = constraints.maxWidth > 900 ? 3 : (constraints.maxWidth > 600 ? 2 : 1);

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top profile card
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 18, offset: const Offset(0, 8))
                    ]),
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // avatar with gradient ring
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [emeraldStart, emeraldEnd]),
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: emeraldEnd.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 6))],
                          ),
                          child: CircleAvatar(
                            radius: 36,
                            backgroundColor: Colors.white,
                            child: ClipOval(child: SizedBox(width: 64, height: 64, child: _buildAvatarChild())),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(getDisplayName(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                            const SizedBox(height: 6),
                            Text(_data.profile['email'], style: TextStyle(color: Colors.grey[600])),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [emeraldStart, emeraldEnd]),
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: [BoxShadow(color: emeraldEnd.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 6))],
                              ),
                              child: Text(_data.profile['status'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                            ),
                          ]),
                        ),
                        Column(children: [
                          // A subtle outlined edit button (keeps secondary actions small)
                          OutlinedButton(
                            onPressed: () => _openEditSheet('Edit Profile', 'profile'),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: emeraldStart),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              foregroundColor: emeraldStart,
                              backgroundColor: Colors.white,
                            ),
                            child: const Padding(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6), child: Text('Edit')),
                          ),
                        ]),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Academic card
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 6))
                    ]),
                    child: Column(children: [
                      ListTile(
                        title: const Text('Senior High School Information', style: TextStyle(fontWeight: FontWeight.w700)),
                        trailing: TextButton(
                          onPressed: () => _openEditSheet('Edit Academic Info', 'academic'),
                          style: TextButton.styleFrom(foregroundColor: emeraldStart),
                          child: const Text('Edit'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                        child: GridView(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: gridCols,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 3.2,
                          ),
                          children: [
                            _buildChip('Senior High School', _data.academic['school']),
                            _buildChip('Strand / Track', _data.academic['strand']),
                            _buildChip('Grade Level', _data.academic['gradeLevel']),
                            _buildChip('School Year', _data.academic['schoolYear']),
                            _buildChip('LRN', _data.academic['lrn']),
                            _buildChip('Adviser / Section', _data.academic['adviserSection']),
                          ],
                        ),
                      )
                    ]),
                  ),

                  const SizedBox(height: 18),

                  // Personal card
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 6))
                    ]),
                    child: Column(children: [
                      ListTile(
                        title: const Text('Personal Information', style: TextStyle(fontWeight: FontWeight.w700)),
                        trailing: TextButton(
                          onPressed: () => _openEditSheet('Edit Personal Info', 'personal'),
                          style: TextButton.styleFrom(foregroundColor: emeraldStart),
                          child: const Text('Edit'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                        child: GridView(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: gridCols,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 3.2,
                          ),
                          children: [
                            _buildChip('Phone', _data.personal['phone']),
                            _buildChip('Date of Birth', _data.personal['dob']),
                            _buildChip('Address', _data.personal['address']),
                            _buildChip('Emergency Contact', _data.personal['emergency']),
                          ],
                        ),
                      )
                    ]),
                  ),

                  const SizedBox(height: 18),

                  // Settings
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 6))
                    ]),
                    child: Column(children: [
                      const ListTile(title: Text('Account Settings', style: TextStyle(fontWeight: FontWeight.w700))),
                      SwitchListTile(
                        title: const Text('Email Notifications'),
                        subtitle: const Text('Receive updates about your activities'),
                        value: _data.settings['emailNotifications'] ?? true,
                        onChanged: (v) async {
                          setState(() => _data.settings['emailNotifications'] = v);
                          await _repo.save(_data);
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email notification preference saved')));
                        },
                      ),
                      ListTile(
                        title: const Text('Two-Factor Authentication'),
                        subtitle: const Text('Add an extra layer of security'),
                        trailing: OutlinedButton(
                          onPressed: () async {
                            setState(() => _data.settings['twoFactor'] = !(_data.settings['twoFactor'] ?? false));
                            await _repo.save(_data);
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Two-factor setting updated')));
                          },
                          style: OutlinedButton.styleFrom(side: BorderSide(color: emeraldStart)),
                          child: Text((_data.settings['twoFactor'] ?? false) ? 'Disable' : 'Enable', style: TextStyle(color: emeraldStart)),
                        ),
                      ),
                      ListTile(
                        title: const Text('Change Password'),
                        subtitle: const Text('Update your account password'),
                        trailing: TextButton(
                          onPressed: () => _openEditSheet('Change Password', 'password'),
                          child: const Text('Change'),
                        ),
                      ),
                    ]),
                  ),

                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildAvatarChild() {
    // Try to show image file if exists, otherwise initials icon
    try {
      final file = File(providedImagePath);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover, width: 64, height: 64);
      }
    } catch (_) {}

    final first = (_data.profile['firstName'] ?? '').toString();
    final last = (_data.profile['lastName'] ?? '').toString();
    String initials = '';
    if (first.isNotEmpty) initials += first[0];
    if (last.isNotEmpty) initials += last[0];
    return Center(child: Text(initials, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F1722))));
  }
}

class EditForm extends StatefulWidget {
  final String title;
  final Map<String, dynamic> initialData;
  final void Function(Map<String, dynamic>) onSave;
  final String formKey;

  const EditForm({required this.title, required this.initialData, required this.onSave, required this.formKey, super.key});

  @override
  _EditFormState createState() => _EditFormState();
}

class _EditFormState extends State<EditForm> {
  final _form = GlobalKey<FormState>();
  late Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = {};
    widget.initialData.forEach((k, v) {
      _controllers[k] = TextEditingController(text: v?.toString() ?? '');
    });

    // For password form, create the fields explicitly
    if (widget.formKey == 'password') {
      _controllers['newPassword'] = TextEditingController();
      _controllers['confirmPassword'] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _controllers.values.forEach((c) => c.dispose());
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;

    if (widget.formKey == 'password') {
      final p1 = _controllers['newPassword']!.text;
      final p2 = _controllers['confirmPassword']!.text;
      if (p1 != p2) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password changed')));
      Navigator.of(context).pop();
      return;
    }

    final updated = <String, dynamic>{};
    _controllers.forEach((k, c) => updated[k] = c.text);
    widget.onSave(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 16.0, right: 16.0, top: 12.0, bottom: MediaQuery.of(context).viewInsets.bottom + 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 4),
              const Text('', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ]),
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
          ]),
          const SizedBox(height: 8),
          Form(
            key: _form,
            child: Column(children: [
              ..._controllers.entries.map((e) {
                final id = e.key;
                final ctrl = e.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: TextFormField(
                    controller: ctrl,
                    obscureText: id.toLowerCase().contains('password'),
                    decoration: InputDecoration(labelText: _labelFromId(id)),
                    validator: (val) {
                      if (widget.formKey != 'password' && (val == null || val.trim().isEmpty)) return null;
                      if (id == 'confirmPassword' || id == 'newPassword') {
                        if (val == null || val.isEmpty) return 'Required';
                      }
                      return null;
                    },
                  ),
                );
              }).toList(),
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                const SizedBox(width: 8),
                GradientPill(onPressed: _save, child: const Text('Save')),
              ]),
              const SizedBox(height: 8),
            ]),
          ),
        ],
      ),
    );
  }

  String _labelFromId(String id) {
    switch (id) {
      case 'lastName':
        return 'Last Name';
      case 'firstName':
        return 'First Name';
      case 'middleName':
        return 'Middle Name';
      case 'suffix':
        return 'Suffix';
      case 'email':
        return 'Email';
      case 'status':
        return 'Status';
      case 'school':
        return 'Senior High School';
      case 'strand':
        return 'Strand';
      case 'gradeLevel':
        return 'Grade Level';
      case 'schoolYear':
        return 'School Year';
      case 'lrn':
        return 'LRN';
      case 'adviserSection':
        return 'Adviser / Section';
      case 'phone':
        return 'Phone';
      case 'dob':
        return 'Date of Birth';
      case 'address':
        return 'Address';
      case 'emergency':
        return 'Emergency Contact';
      case 'newPassword':
        return 'New Password';
      case 'confirmPassword':
        return 'Confirm Password';
      default:
        return id;
    }
  }
}
