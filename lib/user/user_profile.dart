// lib/user/user_profile.dart
// Enhanced User Profile with emerald gradient theme and improved design

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color emeraldStart = Color(0xFF10B981);
const Color emeraldEnd = Color(0xFF059669);

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
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
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          child: DraggableScrollableSheet(
            initialChildSize: 0.75,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 12,
                      offset: Offset(0, -6),
                    ),
                  ],
                ),
                child: Padding(
                  padding: MediaQuery.of(ctx).viewInsets,
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: EditForm(
                      title: title,
                      initialData: _getFormInitial(formKey),
                      onSave: (updated) => Navigator.of(ctx).pop(updated),
                      formKey: formKey,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );

    if (result != null) {
      setState(() {
        if (formKey == 'profile') _data.profile = result;
        if (formKey == 'academic') _data.academic = result;
        if (formKey == 'personal') _data.personal = result;
      });

      await _repo.save(_data);
      if (mounted) {
        _showSnack('Saved successfully');
      }
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Map<String, dynamic> _getFormInitial(String key) {
    if (key == 'profile') return Map<String, dynamic>.from(_data.profile);
    if (key == 'academic') return Map<String, dynamic>.from(_data.academic);
    if (key == 'personal') return Map<String, dynamic>.from(_data.personal);
    return {};
  }

  Widget _buildChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF9F7FB),
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
      backgroundColor: const Color(0xFFF9F7FB),
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          final gridCols = constraints.maxWidth > 900 ? 3 : (constraints.maxWidth > 600 ? 2 : 1);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Profile Card with emerald ring
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          // Avatar with emerald ring
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const SweepGradient(
                                colors: [emeraldStart, emeraldEnd, emeraldStart],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: emeraldEnd.withOpacity(0.2),
                                  blurRadius: 16,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Container(
                                width: 72,
                                height: 72,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                ),
                                child: CircleAvatar(
                                  backgroundColor: Colors.white,
                                  child: _buildAvatar(),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Name & email
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  getDisplayName(),
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _data.profile['email'],
                                  style: TextStyle(color: Colors.grey[700], fontSize: 14),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(colors: [emeraldStart, emeraldEnd]),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: emeraldEnd.withOpacity(0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    _data.profile['status'],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Edit button
                          _GradientIconButton(
                            onPressed: () => _openEditSheet('Edit Profile', 'profile'),
                            icon: Icons.edit,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Academic Info
                    _InfoCard(
                      title: 'Academic Information',
                      actionText: 'Edit',
                      onAction: () => _openEditSheet('Edit Academic Info', 'academic'),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
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
                            _buildChip('School', _data.academic['school']),
                            _buildChip('Strand', _data.academic['strand']),
                            _buildChip('Grade Level', _data.academic['gradeLevel']),
                            _buildChip('School Year', _data.academic['schoolYear']),
                            _buildChip('LRN', _data.academic['lrn']),
                            _buildChip('Adviser/Section', _data.academic['adviserSection']),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Personal Info
                    _InfoCard(
                      title: 'Personal Information',
                      actionText: 'Edit',
                      onAction: () => _openEditSheet('Edit Personal Info', 'personal'),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
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
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Settings
                    _InfoCard(
                      title: 'Account Settings',
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: const Text('Email Notifications'),
                            subtitle: const Text('Receive updates about activities'),
                            value: _data.settings['emailNotifications'] ?? true,
                            activeColor: emeraldEnd,
                            activeTrackColor: emeraldStart.withOpacity(0.45),
                            onChanged: (v) async {
                              setState(() => _data.settings['emailNotifications'] = v);
                              await _repo.save(_data);
                              _showSnack('Notification preference saved');
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildAvatar() {
    final first = (_data.profile['firstName'] ?? '').toString();
    final last = (_data.profile['lastName'] ?? '').toString();
    String initials = '';
    if (first.isNotEmpty) initials += first[0];
    if (last.isNotEmpty) initials += last[0];

    return Text(
      initials.toUpperCase(),
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black87),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final Widget child;
  final String? actionText;
  final VoidCallback? onAction;

  const _InfoCard({
    required this.title,
    required this.child,
    this.actionText,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 6))
        ],
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            trailing: actionText != null
                ? TextButton(
                    onPressed: onAction,
                    style: TextButton.styleFrom(foregroundColor: emeraldStart),
                    child: Text(actionText!),
                  )
                : null,
          ),
          const Divider(height: 0),
          child,
        ],
      ),
    );
  }
}

// Supporting classes
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
          'lastName': 'Student',
          'firstName': 'User',
          'middleName': '',
          'suffix': '',
          'email': 'student@school.edu',
          'status': 'Active Student',
        },
        academic: {
          'school': 'School Name',
          'strand': 'STEM',
          'gradeLevel': 'Grade 12',
          'schoolYear': '2024 - 2025',
          'lrn': '0000-0000-0000',
          'adviserSection': 'TBA',
        },
        personal: {
          'phone': '+63 900 000 0000',
          'dob': 'January 1, 2000',
          'address': 'City, Province',
          'emergency': '+63 900 000 0000',
        },
        settings: {
          'emailNotifications': true,
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
  static const String storageKey = 'userProfileData_v1';
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

class EditForm extends StatefulWidget {
  final String title;
  final Map<String, dynamic> initialData;
  final void Function(Map<String, dynamic>) onSave;
  final String formKey;

  const EditForm({
    required this.title,
    required this.initialData,
    required this.onSave,
    required this.formKey,
    super.key,
  });

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
  }

  @override
  void dispose() {
    _controllers.values.forEach((c) => c.dispose());
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;

    final updated = <String, dynamic>{};
    _controllers.forEach((k, c) => updated[k] = c.text.trim());
    widget.onSave(updated);
  }

  String _labelFromId(String id) {
    const labels = {
      'lastName': 'Last Name',
      'firstName': 'First Name',
      'middleName': 'Middle Name',
      'suffix': 'Suffix',
      'email': 'Email',
      'status': 'Status',
      'school': 'School',
      'strand': 'Strand',
      'gradeLevel': 'Grade Level',
      'schoolYear': 'School Year',
      'lrn': 'LRN',
      'adviserSection': 'Adviser/Section',
      'phone': 'Phone',
      'dob': 'Date of Birth',
      'address': 'Address',
      'emergency': 'Emergency Contact',
    };
    return labels[id] ?? id;
  }

  @override
  Widget build(BuildContext context) {
    final entries = _controllers.entries.toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(widget.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
            _SmallCircularClose(onPressed: () => Navigator.of(context).pop()),
          ],
        ),
        const SizedBox(height: 16),
        Form(
          key: _form,
          child: Column(
            children: entries.map((e) {
              final label = _labelFromId(e.key);
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: TextFormField(
                  controller: e.value,
                  decoration: InputDecoration(
                    labelText: label,
                    filled: true,
                    fillColor: const Color(0xFFF6F6FA),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (v) {
                    if (e.key == 'email' && (v == null || !v.contains('@'))) {
                      return 'Valid email required';
                    }
                    if ((e.key == 'firstName' || e.key == 'lastName') && (v == null || v.trim().isEmpty)) {
                      return 'Required';
                    }
                    return null;
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _GradientButton(
                onPressed: _save,
                child: const Text('Save', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SmallCircularClose extends StatelessWidget {
  final VoidCallback onPressed;
  const _SmallCircularClose({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [emeraldStart, emeraldEnd]),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: const Icon(Icons.close, size: 20, color: Colors.white),
        onPressed: onPressed,
      ),
    );
  }
}

class _GradientIconButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;

  const _GradientIconButton({required this.onPressed, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [emeraldStart, emeraldEnd]),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: emeraldEnd.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 20),
        onPressed: onPressed,
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget child;

  const _GradientButton({required this.onPressed, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [emeraldStart, emeraldEnd]),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: emeraldEnd.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 6)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Center(
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