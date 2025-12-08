// lib/user/user_profile.dart
// User Profile Page - colored emerald ring around avatar with a subtle glow.
// Includes polished profile card, removed academic header, emerald-colored switch,
// circular close pill in edit sheet, improved edit form layout.

import 'dart:convert';
import 'dart:io';
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
        // Polished sheet with draggable behavior
        return SafeArea(
          child: DraggableScrollableSheet(
            initialChildSize: 0.72,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                ),
                child: Padding(
                  padding: MediaQuery.of(ctx).viewInsets,
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved successfully')),
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

  Widget _buildChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEBEEF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7FB),
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          final gridCols = constraints.maxWidth > 900 ? 3 : (constraints.maxWidth > 600 ? 2 : 1);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('Profile', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                              SizedBox(height: 6),
                              Text('Manage your personal information', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                        _GradientPill(
                          onPressed: () => _openEditSheet('Edit Profile', 'profile'),
                          child: Row(
                            children: const [
                              Icon(Icons.edit, size: 16),
                              SizedBox(width: 8),
                              Text('Edit Profile'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ---- Profile Card with colored emerald gradient RING + subtle glow ----
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 22,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                      child: Row(
                        children: [
                          // Outer ring implemented using an outer gradient circle and inner white circle to form a ring.
                          // Added a subtle glow via a soft boxShadow on the outer ring container.
                          Container(
                            margin: const EdgeInsets.only(right: 14),
                            width: 92,
                            height: 92,
                            alignment: Alignment.center,
                            child: Container(
                              width: 92,
                              height: 92,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: SweepGradient(
                                  startAngle: 0.0,
                                  endAngle: 6.283185307179586,
                                  colors: [
                                    emeraldStart,
                                    emeraldEnd,
                                    emeraldStart,
                                  ],
                                ),
                                // subtle colored glow
                                boxShadow: [
                                  BoxShadow(
                                    color: emeraldEnd.withOpacity(0.18),
                                    blurRadius: 18,
                                    spreadRadius: 4,
                                    offset: const Offset(0, 6),
                                  ),
                                  BoxShadow(
                                    color: emeraldStart.withOpacity(0.06),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Center(
                                // inner white circle that creates the ring effect
                                child: Container(
                                  width: 68,
                                  height: 68,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.06),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    backgroundColor: Colors.white,
                                    child: _buildAvatar(),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Name & email block
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  getDisplayName(),
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                ),
                                const SizedBox(height: 6),
                                Text(_data.profile['email'], style: TextStyle(color: Colors.grey[700])),
                              ],
                            ),
                          ),

                          // intentionally empty (status pill & menu removed)
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Academic Info — header removed (no Edit button)
                    _InfoCard(
                      title: null, // header removed
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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

                    const SizedBox(height: 18),

                    // Personal Info (keeps header)
                    _InfoCard(
                      title: 'Personal Information',
                      actionText: 'Edit',
                      onAction: () => _openEditSheet('Edit Personal Info', 'personal'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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

                    const SizedBox(height: 18),

                    // Settings
                    _InfoCard(
                      title: 'Account Settings',
                      child: Column(
                        children: [
                          // Emerald-colored switch that matches the Save/Close buttons
                          SwitchListTile(
                            title: const Text('Email Notifications'),
                            subtitle: const Text('Receive updates about activities'),
                            value: _data.settings['emailNotifications'] ?? true,

                            // Colors to match emerald palette used across the UI
                            activeColor: emeraldEnd, // thumb
                            activeTrackColor: emeraldStart.withOpacity(0.45), // track

                            onChanged: (v) async {
                              setState(() => _data.settings['emailNotifications'] = v);
                              await _repo.save(_data);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Notification preference saved')),
                                );
                              }
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
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black87),
    );
  }
}

// ----- Reusable info card: title nullable to allow header removal -----
class _InfoCard extends StatelessWidget {
  final String? title; // nullable to allow header removal
  final Widget child;
  final String? actionText;
  final VoidCallback? onAction;

  const _InfoCard({
    required this.title,
    required this.child,
    this.actionText,
    this.onAction,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 6))
        ],
      ),
      child: Column(
        children: [
          // Only render header when title is provided
          if (title != null)
            ListTile(
              title: Text(title!, style: const TextStyle(fontWeight: FontWeight.w700)),
              trailing: actionText != null
                  ? TextButton(
                      onPressed: onAction,
                      style: TextButton.styleFrom(foregroundColor: emeraldStart),
                      child: Text(actionText!),
                    )
                  : null,
            ),
          if (title != null) const Divider(height: 0),
          // If title is null but actionText != null (our academic case), place Edit at top-right
          if (title == null && actionText != null)
            Padding(
              padding: const EdgeInsets.only(top: 12.0, right: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: onAction,
                    style: TextButton.styleFrom(foregroundColor: emeraldStart),
                    child: Text(actionText!),
                  ),
                ],
              ),
            ),
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

// ----- Edit Form (improved layout + input styling) -----
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

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFF6F6FA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Make a responsive two-column layout inside the sheet.
    final width = MediaQuery.of(context).size.width;
    final cols = width > 800 ? 2 : 1;
    final entries = _controllers.entries.toList();

    List<Widget> fields = entries.map((e) {
      final label = _labelFromId(e.key);
      return TextFormField(
        controller: e.value,
        decoration: _fieldDecoration(label),
        validator: (v) {
          if (e.key == 'email') {
            if (v == null || v.trim().isEmpty) return 'Email required';
            if (!v.contains('@')) return 'Enter a valid email';
          }
          if ((e.key == 'firstName' || e.key == 'lastName') && (v == null || v.trim().isEmpty)) {
            return 'Required';
          }
          return null;
        },
      );
    }).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header row with small circular close pill
        Row(
          children: [
            Expanded(child: Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
            // Circular close button
            _SmallCircularClose(onPressed: () => Navigator.of(context).pop()),
          ],
        ),
        const SizedBox(height: 12),
        Form(
          key: _form,
          child: LayoutBuilder(builder: (context, box) {
            final double spacing = 12;
            final itemWidth = (box.maxWidth - spacing * (cols - 1)) / cols;
            return Wrap(
              runSpacing: 12,
              spacing: spacing,
              children: fields.map((w) {
                final widthValue = itemWidth.clamp(280.0, box.maxWidth).toDouble();
                return SizedBox(width: widthValue, child: w);
              }).toList(),
            );
          }),
        ),
        const SizedBox(height: 18),
        // Action buttons
        Row(
          children: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
            const Spacer(),
            _GradientPill(onPressed: _save, child: const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('Save', style: TextStyle(fontSize: 15)))),
          ],
        ),
      ],
    );
  }
}

/// Perfect circular close button for the edit-sheet header
class _SmallCircularClose extends StatelessWidget {
  final VoidCallback onPressed;
  const _SmallCircularClose({required this.onPressed, super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      shape: const CircleBorder(),
      color: Colors.transparent,
      child: Ink(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [emeraldStart, emeraldEnd]),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: emeraldEnd.withOpacity(0.14), blurRadius: 6, offset: const Offset(0, 3))],
        ),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: const Center(child: Icon(Icons.close, size: 18, color: Colors.white)),
        ),
      ),
    );
  }
}

class _GradientPill extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget child;

  const _GradientPill({required this.onPressed, required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [emeraldStart, emeraldEnd]),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: emeraldEnd.withOpacity(0.16), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: DefaultTextStyle(style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700), child: child),
          ),
        ),
      ),
    );
  }
}
