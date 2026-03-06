import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/event_services.dart';

class CreateEditEventScreen extends StatefulWidget {
  final String? eventId; // if null, mode is Create. If has value, mode is Edit.

  const CreateEditEventScreen({super.key, this.eventId});

  @override
  State<CreateEditEventScreen> createState() => _CreateEditEventScreenState();
}

class _CreateEditEventScreenState extends State<CreateEditEventScreen> {
  final EventService _eventService = EventService();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isInitFetching = false;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController();

  DateTime? _startTime;
  DateTime? _endTime;

  @override
  void initState() {
    super.initState();
    if (widget.eventId != null) {
      _fetchEventData();
    }
  }

  Future<void> _fetchEventData() async {
    setState(() => _isInitFetching = true);
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .get();
      if (doc.exists) {
        var data = doc.data() as Map<String, dynamic>;
        _titleController.text = data['title'] ?? '';
        _descController.text = data['description'] ?? '';
        _locationController.text = data['location'] ?? '';
        _capacityController.text = (data['capacity'] ?? 0).toString();

        if (data['startTime'] != null) {
          _startTime = (data['startTime'] as Timestamp).toDate();
        }
        if (data['endTime'] != null) {
          _endTime = (data['endTime'] as Timestamp).toDate();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading event: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isInitFetching = false);
      }
    }
  }

  Future<void> _selectDateTime(bool isStart) async {
    DateTime initialDate = DateTime.now();
    if (isStart && _startTime != null) initialDate = _startTime!;
    if (!isStart && _endTime != null) initialDate = _endTime!;

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (pickedDate != null && mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDate),
      );
      if (pickedTime != null && mounted) {
        setState(() {
          DateTime finalDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          if (isStart) {
            _startTime = finalDateTime;
          } else {
            _endTime = finalDateTime;
          }
        });
      }
    }
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select start and end times')),
      );
      return;
    }
    if (_endTime!.isBefore(_startTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time cannot be before start time')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.eventId == null) {
        // Create
        await _eventService.createEvent(
          title: _titleController.text,
          description: _descController.text,
          location: _locationController.text,
          startTime: _startTime!,
          endTime: _endTime!,
          capacity: int.tryParse(_capacityController.text) ?? 0,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event created successfully!')),
          );
        }
      } else {
        // Update
        await _eventService.updateEvent(
          eventId: widget.eventId!,
          title: _titleController.text,
          description: _descController.text,
          location: _locationController.text,
          startTime: _startTime!,
          endTime: _endTime!,
          capacity: int.tryParse(_capacityController.text) ?? 0,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event updated successfully!')),
          );
        }
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitFetching) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: Colors.orange)),
      );
    }

    bool isEditing = widget.eventId != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edit Event' : 'Create Event',
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel('Event Title'),
              _buildTextField(
                controller: _titleController,
                hintText: 'e.g. AI Prompting Workshop',
                validator: (value) =>
                    value!.isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 16),

              _buildLabel('Description'),
              _buildTextField(
                controller: _descController,
                hintText: 'Describe what the event is about...',
                maxLines: 4,
                validator: (value) =>
                    value!.isEmpty ? 'Description is required' : null,
              ),
              const SizedBox(height: 16),

              _buildLabel('Location'),
              _buildTextField(
                controller: _locationController,
                hintText: 'e.g. Main Auditorium',
                validator: (value) =>
                    value!.isEmpty ? 'Location is required' : null,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Start Time'),
                        InkWell(
                          onTap: () => _selectDateTime(true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                  color: Colors.orange,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _startTime != null
                                        ? '${_startTime!.day}/${_startTime!.month} ${_startTime!.hour}:${_startTime!.minute.toString().padLeft(2, '0')}'
                                        : 'Select Date',
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('End Time'),
                        InkWell(
                          onTap: () => _selectDateTime(false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                  color: Colors.orange,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _endTime != null
                                        ? '${_endTime!.day}/${_endTime!.month} ${_endTime!.hour}:${_endTime!.minute.toString().padLeft(2, '0')}'
                                        : 'Select Date',
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _buildLabel('Capacity (Max Participants)'),
              _buildTextField(
                controller: _capacityController,
                hintText: 'e.g. 100',
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'Capacity is required';
                  if (int.tryParse(value) == null) return 'Must be a number';
                  return null;
                },
              ),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveEvent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          isEditing ? 'Save Changes' : 'Create Event',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
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

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.black87),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.black38),
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      validator: validator,
    );
  }
}
