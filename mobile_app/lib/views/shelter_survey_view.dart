import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:field_app/models/safe_shelter.dart';
import 'package:field_app/models/sync_queue_item.dart';
import 'package:field_app/core/database.dart';
import 'package:field_app/services/sync_service.dart';

class ShelterSurveyView extends StatefulWidget {
  final SafeShelter? shelter;

  const ShelterSurveyView({super.key, this.shelter});

  @override
  State<ShelterSurveyView> createState() => _ShelterSurveyViewState();
}

class _ShelterSurveyViewState extends State<ShelterSurveyView> {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseService();
  final _syncService = SyncService();

  late TextEditingController _capacityStatusController;
  late TextEditingController _waterAvailableController;
  late TextEditingController _foodAvailableController;
  late TextEditingController _medicalKitsController;
  late TextEditingController _generatorFuelController;
  late TextEditingController _accessRoadStatusController;
  late TextEditingController _surveyNotesController;
  late TextEditingController _surveyorIdController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _capacityStatusController = TextEditingController(
      text: widget.shelter?.capacityStatus ?? 'LOW',
    );
    _waterAvailableController = TextEditingController(
      text: widget.shelter?.waterAvailableLiters.toString() ?? '0',
    );
    _foodAvailableController = TextEditingController(
      text: widget.shelter?.foodAvailableKg.toString() ?? '0',
    );
    _medicalKitsController = TextEditingController(
      text: widget.shelter?.medicalKitsAvailable.toString() ?? '0',
    );
    _generatorFuelController = TextEditingController(
      text: widget.shelter?.generatorFuelLiters.toString() ?? '0',
    );
    _accessRoadStatusController = TextEditingController(
      text: widget.shelter?.accessRoadStatus ?? 'CLEAR',
    );
    _surveyNotesController = TextEditingController(
      text: widget.shelter?.fieldSurveyNotes ?? '',
    );
    _surveyorIdController = TextEditingController(
      text: widget.shelter?.surveyorId ?? '',
    );
  }

  @override
  void dispose() {
    _capacityStatusController.dispose();
    _waterAvailableController.dispose();
    _foodAvailableController.dispose();
    _medicalKitsController.dispose();
    _generatorFuelController.dispose();
    _accessRoadStatusController.dispose();
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
      if (widget.shelter != null) {
        final updatedShelter = widget.shelter!;
        updatedShelter.capacityStatus = _capacityStatusController.text;
        updatedShelter.waterAvailableLiters =
            int.tryParse(_waterAvailableController.text) ?? 0;
        updatedShelter.foodAvailableKg =
            int.tryParse(_foodAvailableController.text) ?? 0;
        updatedShelter.medicalKitsAvailable =
            int.tryParse(_medicalKitsController.text) ?? 0;
        updatedShelter.generatorFuelLiters =
            int.tryParse(_generatorFuelController.text) ?? 0;
        updatedShelter.accessRoadStatus = _accessRoadStatusController.text;
        updatedShelter.fieldSurveyNotes = _surveyNotesController.text;
        updatedShelter.surveyorId = _surveyorIdController.text;
        updatedShelter.lastFieldVisit = DateTime.now();
        updatedShelter.isSynced = false;

        // Save to local Isar database
        await _db.saveShelter(updatedShelter);

        // Step 2: Queue Injection (Create sync queue item)
        final syncItem = SyncQueueItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          operationType: 'UPDATE_SHELTER',
          payload: jsonEncode(updatedShelter.toJson()),
          status: 'pending',
          createdAt: DateTime.now(),
          retryCount: 0,
        );
        await _db.saveSyncQueueItem(syncItem);

        // Step 3: Auto-Push Broker (Check connectivity and push if online)
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
                  const Text('Shelter survey saved locally and queued for sync'),
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
          'Shelter Resource Survey',
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
              // Shelter Info Card
              if (widget.shelter != null)
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
                        widget.shelter!.shelterName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF000000),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow('District', widget.shelter!.districtName),
                      _buildInfoRow('Total Capacity', '${widget.shelter!.totalCapacity}'),
                      _buildInfoRow('Available Capacity', '${widget.shelter!.availableCapacity}'),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              // Capacity Status
              const Text(
                'Capacity Status',
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
                    value: _capacityStatusController.text,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      hintText: 'Select capacity status',
                      hintStyle: TextStyle(color: Color(0xFF9E9E9E)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'LOW', child: Text('LOW')),
                      DropdownMenuItem(value: 'MEDIUM', child: Text('MEDIUM')),
                      DropdownMenuItem(value: 'HIGH', child: Text('HIGH')),
                      DropdownMenuItem(value: 'CRITICAL', child: Text('CRITICAL')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _capacityStatusController.text = value ?? 'LOW';
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select capacity status';
                      }
                      return null;
                    },
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Resource Inputs
              const Text(
                'Current Resources',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF000000),
                ),
              ),
              const SizedBox(height: 8),

              _buildTextField(_waterAvailableController, 'Water Available (Liters)', TextInputType.number),
              const SizedBox(height: 16),
              _buildTextField(_foodAvailableController, 'Food Available (Kg)', TextInputType.number),
              const SizedBox(height: 16),
              _buildTextField(_medicalKitsController, 'Medical Kits Available', TextInputType.number),
              const SizedBox(height: 16),
              _buildTextField(_generatorFuelController, 'Generator Fuel (Liters)', TextInputType.number),

              const SizedBox(height: 24),

              // Access Road Status
              const Text(
                'Access Road Status',
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
                    value: _accessRoadStatusController.text,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      hintText: 'Select road status',
                      hintStyle: TextStyle(color: Color(0xFF9E9E9E)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'CLEAR', child: Text('CLEAR')),
                      DropdownMenuItem(value: 'BLOCKED', child: Text('BLOCKED')),
                      DropdownMenuItem(value: 'DAMAGED', child: Text('DAMAGED')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _accessRoadStatusController.text = value ?? 'CLEAR';
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select road status';
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
                          'COMMIT SHELTER SURVEY',
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

  Widget _buildTextField(TextEditingController controller, String label, TextInputType keyboardType) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 12),
          floatingLabelStyle: const TextStyle(color: Color(0xFF000000)),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter $label';
          }
          return null;
        },
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
            width: 140,
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
