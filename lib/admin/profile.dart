// lib/admin/profile.dart
// Fixed Admin Profile page with proper class structure

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Emerald gradient colors
const Color emeraldStart = Color(0xFF10B981);
const Color emeraldEnd = Color(0xFF059669);

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
          child: Padding(
            padding: padding,
            child: DefaultTextStyle(
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              child: child,
            ),
          ),
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
          'lastName': 'User',
          'firstName': 'Admin',
          'middleName': '',
          'suffix': '',
          'email': 'admin@school.edu',
          'status': 'Administrator',
        },
        academic: {
          'school': 'School Name',
          'strand': 'N/A',
          'gradeLevel': 'N/A',
          'schoolYear': '2024 - 2025',
          'lrn': 'N/A',
          'adviserSection': 'N/A',
        },
        personal: {
          'phone': '+63 912 345 6789',
          'dob': 'January 15, 1990',
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
  static const String storageKey = 'adminProfileData_v1';

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
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late SharedPreferences _prefs;
  late ProfileRepository _repo;
  late ProfileData _data;
  bool _loading = true;

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
    final first = (p['firstName'] ?? '').toString();
    final last = (p['lastName'] ?? '').toString();
    if (first.isEmpty && last.isEmpty) return 'Admin User';
    return '$first $last';
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle_outline, color: Colors.white),
                SizedBox(width: 12),
                Text('Saved successfully'),
              ],
            ),
            backgroundColor: emeraldEnd,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Map<String, dynamic> _getFormInitial(String key) {
    if (key == 'profile') return Map<String, dynamic>.from(_data.profile);
    if (key == 'academic') return Map<String, dynamic>.from(_data.academic);
    if (key == 'personal') return Map<String, dynamic>.from(_data.personal);
    return {};
  }

  Widget _fieldCard(String label, String value) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 6))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F1722))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF6F7FB),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: emeraldEnd),
              const SizedBox(height: 16),
              const Text('Loading profile...', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: false,
        automaticallyImplyLeading: true,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          Text('Profile', style: TextStyle(color: Color(0xFF0F1722), fontWeight: FontWeight.w800, fontSize: 28)),
          SizedBox(height: 4),
          Text('Manage your personal information', style: TextStyle(color: Colors.grey, fontSize: 13)),
        ]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0, top: 6.0),
            child: GradientPill(
              onPressed: () => _openEditSheet('Edit Profile', 'profile'),
              child: Row(children: const [Icon(Icons.edit, size: 16), SizedBox(width: 8), Text('Edit Profile')]),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top profile card (avatar + name/email/status)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 8))],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildAvatarRing(),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(getDisplayName(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                            const SizedBox(height: 6),
                            Text(_data.profile['email'] ?? '', style: TextStyle(color: Colors.grey[600])),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [emeraldStart, emeraldEnd]),
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: [BoxShadow(color: emeraldEnd.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 6))],
                              ),
                              child: Text(_data.profile['status'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Personal info section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Personal Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    TextButton.icon(
                      onPressed: () => _openEditSheet('Edit Personal Info', 'personal'),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit'),
                      style: TextButton.styleFrom(foregroundColor: emeraldEnd),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                _fieldCard('Phone', _data.personal['phone'] ?? ''),
                const SizedBox(height: 12),
                _fieldCard('Date of Birth', _data.personal['dob'] ?? ''),
                const SizedBox(height: 12),
                _fieldCard('Address', _data.personal['address'] ?? ''),
                const SizedBox(height: 12),
                _fieldCard('Emergency Contact', _data.personal['emergency'] ?? ''),

                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarRing() {
    const double outer = 80;
    const double ring = 72;
    const double inner = 60;

    return SizedBox(
      width: outer,
      height: outer,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: outer,
            height: outer,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: emeraldEnd.withOpacity(0.16), blurRadius: 24, spreadRadius: 6, offset: const Offset(0, 6)),
                BoxShadow(color: emeraldStart.withOpacity(0.06), blurRadius: 10, spreadRadius: 2),
              ],
            ),
          ),
          Container(
            width: ring,
            height: ring,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                startAngle: 0.0,
                endAngle: 6.283185307179586,
                colors: [
                  emeraldStart,
                  emeraldEnd,
                  emeraldStart.withOpacity(0.95),
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
          ),
          Container(
            width: inner,
            height: inner,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: ClipOval(child: _buildAvatarChild()),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarChild() {
    final first = (_data.profile['firstName'] ?? '').toString();
    final last = (_data.profile['lastName'] ?? '').toString();
    String initials = '';
    if (first.isNotEmpty) initials += first[0];
    if (last.isNotEmpty) initials += last[0];
    return Center(
      child: Text(
        initials.isEmpty ? 'A' : initials,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F1722)),
      ),
    );
  }
}

class EditForm extends StatefulWidget {
  final String title;
  final Map<String, dynamic> initialData;
  final void Function(Map<String, dynamic>) onSave;
  final String formKey;

  const EditForm({required this.title, required this.initialData, required this.onSave, required this.formKey, super.key});

  @override
  State<EditForm> createState() => _EditFormState();
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
      case 'lastName': return 'Last Name';
      case 'firstName': return 'First Name';
      case 'middleName': return 'Middle Name';
      case 'suffix': return 'Suffix';
      case 'email': return 'Email';
      case 'status': return 'Status';
      case 'school': return 'Senior High School';
      case 'strand': return 'Strand';
      case 'gradeLevel': return 'Grade Level';
      case 'schoolYear': return 'School Year';
      case 'lrn': return 'LRN';
      case 'adviserSection': return 'Adviser / Section';
      case 'phone': return 'Phone';
      case 'dob': return 'Date of Birth';
      case 'address': return 'Address';
      case 'emergency': return 'Emergency Contact';
      case 'newPassword': return 'New Password';
      case 'confirmPassword': return 'Confirm Password';
      default: return id;
    }
  }
}