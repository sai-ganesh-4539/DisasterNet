import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:field_app/models/habitation.dart';
import 'package:field_app/models/sync_queue_item.dart';
import 'package:field_app/core/database.dart';
import 'package:field_app/services/sync_service.dart';

class HabitationSurveyView extends StatefulWidget {
  final Habitation? habitation;

  const HabitationSurveyView({super.key, this.habitation});

  @override
  State<HabitationSurveyView> createState() => _HabitationSurveyViewState();
}

class _HabitationSurveyViewState extends State<HabitationSurveyView> {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseService();
  final _syncService = SyncService();

  late TextEditingController _pathStatusController;
  late TextEditingController _surveyNotesController;
  late TextEditingController _surveyorIdController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _pathStatusController = TextEditingController(
      text: widget.habitation?.pathStatus ?? 'CLEAR',
    );
    _surveyNotesController = TextEditingController(
      text: widget.habitation?.fieldSurveyNotes ?? '',
    );
    _surveyorIdController = TextEditingController(
      text: widget.habitation?.surveyorId ?? '',
    );
  }

  @override
  void dispose() {
    _pathStatusController.dispose();
    _surveyNotesController.dispose();
    _surveyorIdController.dispose();
    super.dispose();
  }

  Future<void> _submitSurvey() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Step 1: Form → Cache (Local Storage)
      if (widget.habitation != null) {
        final updatedHabitation = widget.habitation!;
        updatedHabitation.pathStatus = _pathStatusController.text;
        updatedHabitation.fieldSurveyNotes = _surveyNotesController.text;
        updatedHabitation.surveyorId = _surveyorIdController.text;
        updatedHabitation.lastFieldVisit = DateTime.now();
        updatedHabitation.isSynced = false;

        // Save to local Isar database
        await _db.saveHabitation(updatedHabitation);

        // Step 2: Queue Injection (Create sync queue item)
        final syncItem = SyncQueueItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          operationType: 'UPDATE_HABITATION',
          payload: jsonEncode(updatedHabitation.toJson()),
          status: 'pending',
          createdAt: DateTime.now(),
          retryCount: 0,
        );
        await _db.saveSyncQueueItem(syncItem);

        // Step 3: Auto-Push Broker (Check connectivity and push if online)
        if (!_syncService.isInitialized) {
          await _syncService.initialize('FIELD-NODE');
        }
        final isConnected = await _syncService.checkConnectivity();
        if (isConnected) {
          await _syncService.processSyncQueue();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  _buildStatusIcon('success'),
                  const SizedBox(width: 12),
                  const Text('Survey saved locally and queued for sync'),
                ],
              ),
              backgroundColor: const Color(0xFF388E3C),
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                _buildStatusIcon('error'),
                const SizedBox(width: 12),
                Text('Error: $e'),
              ],
            ),
            backgroundColor: const Color(0xFFD32F2F),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildStatusIcon(String type) {
    switch (type) {
      case 'success':
        return Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFFFFFFF),
          ),
          child: const Icon(Icons.check, color: Color(0xFF388E3C), size: 14),
        );
      case 'error':
        return Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            shape: BoxShape.rectangle,
            color: Color(0xFFFFFFFF),
          ),
          child: const Icon(Icons.close, color: Color(0xFFD32F2F), size: 14),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        title: const Text(
          'Habitation Field Survey',
          style: TextStyle(
            color: Color(0xFF000000),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFFFFFFFF),
        foregroundColor: const Color(0xFF000000),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF000000)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Habitation Info Card
              if (widget.habitation != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFFFF),
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.habitation!.villageName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF000000),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow('District', widget.habitation!.districtName),
                      _buildInfoRow('Total Population', '${widget.habitation!.totalPopulation}'),
                      _buildInfoRow('Priority Score', '${widget.habitation!.priorityScore.toStringAsFixed(1)}%'),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              // Path Status
              const Text(
                'Path Status',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF000000),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButtonFormField<String>(
                    initialValue: _pathStatusController.text,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      hintText: 'Select path status',
                      hintStyle: TextStyle(color: Color(0xFF9E9E9E)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'CLEAR', child: Text('CLEAR')),
                      DropdownMenuItem(value: 'BLOCKED', child: Text('BLOCKED')),
                      DropdownMenuItem(value: 'DAMAGED', child: Text('DAMAGED')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _pathStatusController.text = value ?? 'CLEAR';
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select path status';
                      }
                      return null;
                    },
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Survey Notes
              const Text(
                'Survey Notes',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF000000),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: TextFormField(
                  controller: _surveyNotesController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(12),
                    hintText: 'Enter detailed survey observations...',
                    hintStyle: TextStyle(color: Color(0xFF9E9E9E)),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter survey notes';
                    }
                    return null;
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Surveyor ID
              const Text(
                'Surveyor ID',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF000000),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: TextFormField(
                  controller: _surveyorIdController,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    hintText: 'Enter your surveyor ID',
                    hintStyle: TextStyle(color: Color(0xFF9E9E9E)),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter surveyor ID';
                    }
                    return null;
                  },
                ),
              ),

              const SizedBox(height: 32),

              // Submit Button - Monochromatic with 4px radius
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitSurvey,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF000000),
                    foregroundColor: const Color(0xFFFFFFFF),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Color(0xFFFFFFFF),
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'COMMIT SURVEY DATA',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF757575),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF000000),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
