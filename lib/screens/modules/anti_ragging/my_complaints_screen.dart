import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../config/constants.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/campus_data_service.dart';

class MyComplaintsScreen extends StatefulWidget {
  const MyComplaintsScreen({super.key});

  @override
  State<MyComplaintsScreen> createState() => _MyComplaintsScreenState();
}

class _MyComplaintsScreenState extends State<MyComplaintsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final data = context.watch<CampusDataService>();
    final user = auth.currentUser!;
    
    final myComplaints = data.complaints.where((c) => c.studentId == user.id).toList();
    final mySos = data.incidents.where((i) => i.userId.startsWith(user.id)).toList();

    final allReports = [
      ...myComplaints.map((c) => ReportItem(
        id: c.id,
        title: c.title,
        description: c.description,
        date: c.createdAt,
        status: c.status,
        type: 'Complaint',
        remarks: c.facultyComments,
        updatedBy: c.updatedBy,
      )),
      ...mySos.map((i) => ReportItem(
        id: i.id.length > 8 ? 'SOS-${i.id.substring(i.id.length - 6)}' : i.id,
        title: '${i.emergencyType ?? 'Emergency'} SOS Alert',
        description: 'Location: Lat ${i.location.lat.toStringAsFixed(4)}, Lng ${i.location.lng.toStringAsFixed(4)}',
        date: i.timestamp,
        status: i.status.name.contains('resolved') ? 'Resolved' : 'Active',
        type: 'SOS',
        remarks: null,
        updatedBy: null,
      ))
    ];

    final filteredReports = allReports
        .where((r) => _searchQuery.isEmpty || 
                      r.id.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                      r.title.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
        
    filteredReports.sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Complaints & Status'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim();
                });
              },
              decoration: InputDecoration(
                hintText: 'Enter Reference ID (e.g. COMP-1234) to track...',
                prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
          ),
          Expanded(
            child: filteredReports.isEmpty
                ? Center(
                    child: Text(
                      _searchQuery.isNotEmpty
                          ? 'No reports found matching "$_searchQuery".'
                          : 'You have not submitted any reports or alerts.',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: filteredReports.length,
                    itemBuilder: (ctx, idx) {
                      final c = filteredReports[idx];
                      final dateStr = DateFormat('MMM d, yyyy').format(c.date);
                      final isSos = c.type == 'SOS';
                      
                      Color statusColor = AppColors.warning;
                      if (c.status == 'Under Investigation' || c.status == 'Active') statusColor = AppColors.primary;
                      if (c.status == 'Resolved') statusColor = AppColors.safe;
                      if (c.status == 'Dismissed') statusColor = AppColors.textSecondary;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(isSos ? Icons.emergency : Icons.shield_outlined, 
                                           color: isSos ? AppColors.danger : AppColors.primary, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Ref ID: ${c.id}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                            fontSize: 16),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: statusColor),
                                    ),
                                    child: Text(
                                      c.status,
                                      style: TextStyle(
                                          color: statusColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                c.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                c.description,
                                style: const TextStyle(color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 16),
                              StatusTracker(status: c.status, isSos: isSos),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(Icons.event, size: 16, color: AppColors.textSecondary),
                                  const SizedBox(width: 4),
                                  Text('Incident Date: $dateStr',
                                      style: const TextStyle(
                                          color: AppColors.textSecondary, fontSize: 13)),
                                ],
                              ),
                              const SizedBox(height: 16),
                              if (c.remarks != null && c.remarks!.isNotEmpty) ...[
                                const Divider(height: 24),
                                Text(c.updatedBy != null ? 'Remarks by ${c.updatedBy}:' : 'Admin/Faculty Remarks:',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(
                                  c.remarks!,
                                  style: const TextStyle(color: AppColors.textSecondary),
                                ),
                              ]
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class ReportItem {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final String status;
  final String type;
  final String? remarks;
  final String? updatedBy;
  
  ReportItem({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.status,
    required this.type,
    this.remarks,
    this.updatedBy,
  });
}

class StatusTracker extends StatelessWidget {
  final String status;
  final bool isSos;

  const StatusTracker({super.key, required this.status, this.isSos = false});

  @override
  Widget build(BuildContext context) {
    final List<String> steps = isSos
        ? ['Active', 'Resolved']
        : ['Pending', 'Investigation', 'Resolved'];

    int currentStepIdx = 0;
    if (status == 'Under Investigation') currentStepIdx = 1;
    if (status == 'Resolved' || status == 'Dismissed') currentStepIdx = steps.length - 1;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            // It's a line
            final lineIndex = i ~/ 2;
            final isLineActive = lineIndex < currentStepIdx;
            
            Color lineColor = AppColors.primary;
            if (!isLineActive) lineColor = Colors.grey.shade300;

            return Expanded(
              child: Container(
                margin: const EdgeInsets.only(top: 11),
                height: 2,
                color: lineColor,
              ),
            );
          } else {
            // It's a node
            final index = i ~/ 2;
            final isActive = index <= currentStepIdx;
            
            Color stepColor = AppColors.primary;
            if (status == 'Dismissed' && index == steps.length - 1) {
              stepColor = AppColors.textSecondary;
            } else if (status == 'Resolved' && index == steps.length - 1) {
              stepColor = AppColors.safe;
            } else if (!isActive) {
              stepColor = Colors.grey.shade300;
            }
            
            String label = steps[index];
            if (status == 'Dismissed' && index == steps.length - 1) {
              label = 'Dismissed';
            }

            return Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive ? stepColor : Colors.white,
                    border: Border.all(
                      color: isActive ? stepColor : Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
                  child: isActive
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive ? AppColors.textPrimary : Colors.grey.shade500,
                  ),
                ),
              ],
            );
          }
        }),
      ),
    );
  }
}
