import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/event_services.dart';
import '../../services/storage_services.dart';
import '../../models/event.dart';

class CreateEditEventScreen extends StatefulWidget {
  final String? eventId; // if null, mode is Create. If has value, mode is Edit.

  const CreateEditEventScreen({super.key, this.eventId});

  @override
  State<CreateEditEventScreen> createState() => _CreateEditEventScreenState();
}

class _CreateEditEventScreenState extends State<CreateEditEventScreen> {
  final EventService _eventService = EventService();
  final StorageService _storageService = StorageService();
  final ImagePicker _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isInitFetching = false;

  Event? _currentEvent;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  DateTime? _startTime;
  DateTime? _endTime;
  String _status = 'active';
  String _category = 'Other';
  File? _selectedImage;
  String? _uploadedImageUrl;

  @override
  void initState() {
    super.initState();
    if (widget.eventId != null) {
      _fetchEventData();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    _capacityController.dispose();
    _noteController.dispose();
    super.dispose();
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
        _currentEvent = Event.fromFirestore(data, doc.id);

        _titleController.text = _currentEvent!.title;
        _descController.text = _currentEvent!.description;
        _locationController.text = _currentEvent!.location;
        _capacityController.text = _currentEvent!.capacity.toString();
        _noteController.text = _currentEvent!.note;

        _startTime = _currentEvent!.startTime;
        _endTime = _currentEvent!.endTime;
        // Normalize legacy status values (e.g. 'published', 'draft') to valid dropdown options
        final rawStatus = _currentEvent!.status;
        _status = (rawStatus == 'active' || rawStatus == 'inactive')
            ? rawStatus
            : 'active';
        _uploadedImageUrl = _currentEvent!.image.isNotEmpty
            ? _currentEvent!.image
            : null;
        _category = _currentEvent!.category;
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

  Future<void> _pickImage() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
      });
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
      // Upload image if a new one was selected
      String imageUrl = _uploadedImageUrl ?? '';
      if (_selectedImage != null) {
        final uploadedUrl = await _storageService.uploadImage(
          _selectedImage!,
          'events',
        );
        if (uploadedUrl != null) {
          imageUrl = uploadedUrl;
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Image upload failed. Saving without new image.'),
              ),
            );
          }
        }
      }

      if (widget.eventId == null) {
        // Create
        final event = Event(
          id: '',
          title: _titleController.text,
          description: _descController.text,
          clubId: '', // managed by EventService
          location: _locationController.text,
          startTime: _startTime!,
          endTime: _endTime!,
          capacity: int.tryParse(_capacityController.text) ?? 0,
          participantCount: 0,
          image: imageUrl,
          createdBy: '', // managed by EventService
          status: _status,
          note: _noteController.text,
          category: _category,
        );
        await _eventService.createEvent(event);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event created successfully!')),
          );
        }
      } else {
        // Update
        if (_currentEvent != null) {
          final event = Event(
            id: _currentEvent!.id,
            title: _titleController.text,
            description: _descController.text,
            clubId: _currentEvent!.clubId,
            location: _locationController.text,
            startTime: _startTime!,
            endTime: _endTime!,
            capacity: int.tryParse(_capacityController.text) ?? 0,
            participantCount: _currentEvent!.participantCount,
            image: imageUrl,
            createdBy: _currentEvent!.createdBy,
            createdAt: _currentEvent!.createdAt,
            status: _status,
            note: _noteController.text,
            category: _category,
          );
          await _eventService.updateEvent(event);
        }
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
      backgroundColor: Colors.grey.shade50,
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
              // ─── Banner Image Picker ───
              _buildImagePicker(),
              const SizedBox(height: 20),

              // ─── Event Title ───
              _buildLabel('Event Title'),
              _buildTextField(
                controller: _titleController,
                hintText: 'e.g. AI Prompting Workshop',
                validator: (value) =>
                    value!.isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 16),

              // ─── Description ───
              _buildLabel('Description'),
              _buildTextField(
                controller: _descController,
                hintText: 'Describe what the event is about...',
                maxLines: 4,
                validator: (value) =>
                    value!.isEmpty ? 'Description is required' : null,
              ),
              const SizedBox(height: 16),

              // ─── Note ───
              _buildLabel('Note (Optional)'),
              _buildTextField(
                controller: _noteController,
                hintText:
                    'Additional notes, special instructions, or reminders...',
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // ─── Category ───
              _buildLabel('Category'),
              _buildCategoryDropdown(),
              const SizedBox(height: 16),

              // ─── Location ───
              _buildLabel('Location'),
              _buildTextField(
                controller: _locationController,
                hintText: 'e.g. Main Auditorium',
                validator: (value) =>
                    value!.isEmpty ? 'Location is required' : null,
              ),
              const SizedBox(height: 16),

              // ─── Start / End Time ───
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Start Time'),
                        _buildDateTimePicker(
                          selectedTime: _startTime,
                          onTap: () => _selectDateTime(true),
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
                        _buildDateTimePicker(
                          selectedTime: _endTime,
                          onTap: () => _selectDateTime(false),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ─── Capacity ───
              _buildLabel('Capacity (Max Participants)'),
              _buildTextField(
                controller: _capacityController,
                hintText: 'e.g. 100',
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Capacity is required';
                  }
                  if (int.tryParse(value) == null) return 'Must be a number';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ─── Status ───
              _buildLabel('Status'),
              _buildStatusDropdown(),
              const SizedBox(height: 40),

              // ─── Save Button ───
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

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.orange.withValues(alpha: 0.4),
            width: 1.5,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: _buildImageContent(),
      ),
    );
  }

  Widget _buildImageContent() {
    if (_selectedImage != null) {
      // Show newly picked local image
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.file(_selectedImage!, fit: BoxFit.cover),
          _buildImageOverlay(),
        ],
      );
    } else if (_uploadedImageUrl != null && _uploadedImageUrl!.isNotEmpty) {
      // Show existing network image (edit mode)
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.network(_uploadedImageUrl!, fit: BoxFit.cover),
          _buildImageOverlay(),
        ],
      );
    } else {
      // Show placeholder
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            size: 48,
            color: Colors.orange.shade300,
          ),
          const SizedBox(height: 12),
          Text(
            'Tap to upload banner / poster image',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'Recommended: 16:9 ratio',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
          ),
        ],
      );
    }
  }

  Widget _buildImageOverlay() {
    return Positioned(
      bottom: 10,
      right: 10,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit, size: 14, color: Colors.white),
            SizedBox(width: 6),
            Text('Change', style: TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _status,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.orange),
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(12),
          items: const [
            DropdownMenuItem(
              value: 'active',
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 18),
                  SizedBox(width: 10),
                  Text('Active'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'inactive',
              child: Row(
                children: [
                  Icon(Icons.cancel, color: Colors.grey, size: 18),
                  SizedBox(width: 10),
                  Text('Inactive'),
                ],
              ),
            ),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _status = val);
          },
        ),
      ),
    );
  }

  static const List<Map<String, dynamic>> _categoryOptions = [
    {'value': 'Academic', 'icon': Icons.school, 'color': Colors.blue},
    {'value': 'Career', 'icon': Icons.work, 'color': Colors.indigo},
    {'value': 'Entertainment', 'icon': Icons.music_note, 'color': Colors.purple},
    {'value': 'Club', 'icon': Icons.groups, 'color': Colors.teal},
    {'value': 'Sports', 'icon': Icons.sports_soccer, 'color': Colors.green},
    {'value': 'Volunteer', 'icon': Icons.volunteer_activism, 'color': Colors.pink},
    {'value': 'Other', 'icon': Icons.category, 'color': Colors.grey},
  ];

  Widget _buildCategoryDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _category,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.orange),
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(12),
          items: _categoryOptions.map((option) {
            return DropdownMenuItem<String>(
              value: option['value'] as String,
              child: Row(
                children: [
                  Icon(option['icon'] as IconData, color: option['color'] as Color, size: 18),
                  const SizedBox(width: 10),
                  Text(option['value'] as String),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _category = val);
          },
        ),
      ),
    );
  }

  Widget _buildDateTimePicker({
    required DateTime? selectedTime,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 16, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                selectedTime != null
                    ? '${selectedTime.day}/${selectedTime.month} ${selectedTime.hour}:${selectedTime.minute.toString().padLeft(2, '0')}'
                    : 'Select Date',
                style: TextStyle(
                  color: selectedTime != null ? Colors.black87 : Colors.black38,
                  fontSize: 13,
                ),
              ),
            ),
          ],
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      validator: validator,
    );
  }
}
