import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/models.dart';
import '../../../services/auth_service.dart';
import '../../../services/campus_data_service.dart';
import '../../../config/constants.dart';

class AntiRaggingFormScreen extends StatefulWidget {
  const AntiRaggingFormScreen({super.key});

  @override
  State<AntiRaggingFormScreen> createState() => _AntiRaggingFormScreenState();
}

class _AntiRaggingFormScreenState extends State<AntiRaggingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  DateTime _incidentDate = DateTime.now();
  bool _isAnonymous = false;

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final user = context.read<AuthService>().currentUser;
    if (user == null) return;

    final data = context.read<CampusDataService>();

    final complaintId = 'COMP-${Random().nextInt(9000) + 1000}';
    final complaint = Complaint(
      id: complaintId,
      studentId: user.id,
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      incidentDate: _incidentDate,
      isAnonymous: _isAnonymous,
      status: 'Pending',
      createdAt: DateTime.now(),
    );

    data.addComplaint(complaint);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.safe),
            SizedBox(width: 8),
            Text('Complaint Registered'),
          ],
        ),
        content: Text(
          _isAnonymous
              ? 'Your complaint has been securely registered. Your identity is hidden from faculty and admin.\n\nReference ID: $complaintId'
              : 'Your complaint has been registered.\n\nReference ID: $complaintId',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop(); // Close dialog
              Navigator.of(context).pop(); // Close screen
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final data = context.watch<CampusDataService>();
    final user = auth.currentUser;

    final studentProfile = user != null ? data.studentByRollNumber(user.id) : null;
    final String studentName = studentProfile?.name ?? user?.name ?? 'Student';
    final String studentDept = studentProfile?.department ?? user?.department ?? 'CSE';
    final String studentYear = studentProfile?.year ?? '3rd Year';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Anti-Ragging Report'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Report an Incident',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your safety is our priority. You can choose to report this anonymously.',
                style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),

              // Dynamic Student Identity Card
              Card(
                color: _isAnonymous ? Colors.blueGrey.shade900 : Colors.blue.shade50,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        _isAnonymous ? Icons.security : Icons.person_pin_rounded,
                        color: _isAnonymous ? Colors.greenAccent : AppColors.primary,
                        size: 36,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isAnonymous ? '🕵️ ANONYMOUS MODE ACTIVE' : '👤 COMPLAINT DETAILS',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: _isAnonymous ? Colors.greenAccent : AppColors.primary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Reporter: ${_isAnonymous ? "Anonymous Student" : studentName}',
                              style: TextStyle(
                                color: _isAnonymous ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            if (!_isAnonymous) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Year: $studentYear | Dept: $studentDept',
                                style: const TextStyle(color: Colors.black54, fontSize: 13),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Incident Title',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                validator: (val) => val == null || val.isEmpty ? 'Required field' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descController,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: 'Detailed Description',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                validator: (val) => val == null || val.isEmpty ? 'Required field' : null,
              ),
              const SizedBox(height: 16),

              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date of Incident', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${_incidentDate.day}/${_incidentDate.month}/${_incidentDate.year}'),
                trailing: const Icon(Icons.calendar_today, color: AppColors.primary),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _incidentDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => _incidentDate = picked);
                  }
                },
              ),
              const Divider(),

              Container(
                margin: const EdgeInsets.symmetric(vertical: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isAnonymous ? AppColors.warning.withValues(alpha: 0.1) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isAnonymous ? AppColors.warning : Colors.grey.shade300,
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Report Anonymously',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isAnonymous
                                ? 'Your name and ID will be completely hidden from college staff.'
                                : 'Your profile details will be visible to investigators.',
                            style: TextStyle(
                              fontSize: 12,
                              color: _isAnonymous ? AppColors.warning : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isAnonymous,
                      activeColor: AppColors.warning,
                      onChanged: (val) => setState(() => _isAnonymous = val),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'SUBMIT REPORT',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
