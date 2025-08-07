import 'package:bloom/data/models/fund.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:bloom/data/services/eco_backend.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class FundCreateScreen extends ConsumerStatefulWidget {
  const FundCreateScreen({super.key});

  @override
  ConsumerState<FundCreateScreen> createState() => _FundCreateScreenState();
}

class _FundCreateScreenState extends ConsumerState<FundCreateScreen> {
  /*──── form 컨트롤러 ────*/
  final _title        = TextEditingController();
  final _subtitle     = TextEditingController();
  final _description  = TextEditingController();
  final _goalAmount   = TextEditingController();
  DateTime? _endDate;

  bool _isLoading = false;
  
  /*──── 이미지 관련 ────*/
  XFile? _selectedImage;
  Uint8List? _imageBytes;
  final ImagePicker _picker = ImagePicker();

  /*──── UID 체크 ────*/
  bool get _isOwner =>
      EcoBackend.instance.currentUser?.uid == 'ClOYnvB9npXjR95TKA4Ik88BS1q2';

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _description.dispose();
    _goalAmount.dispose();
    super.dispose();
  }

  /*──── UI ────*/
  @override
  Widget build(BuildContext context) {
    // if (!_isOwner) {
    //   return Scaffold(
    //     appBar: AppBar(title: const Text('Create Fund')),
    //     body: const Center(
    //       child: Text(
    //         '⚠️  You do not have permission to create a funding campaign.',
    //         style: TextStyle(fontSize: 16),
    //         textAlign: TextAlign.center,
    //       ),
    //     ),
    //   );
    // }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Fund'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildTextField(controller: _title, label: 'Title *'),
            const SizedBox(height: 12),
            _buildTextField(controller: _subtitle, label: 'Subtitle'),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _description,
              label: 'Description',
              minLines: 3,
              maxLines: 5,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _goalAmount,
              label: 'Goal Amount (points) *',
              keyboard: TextInputType.number,
            ),
            const SizedBox(height: 12),
            _buildDatePicker(context),
            const SizedBox(height: 12),
            _buildImagePicker(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
                    : const Text(
                  'Create Funding',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /*──── 위젯 헬퍼 ────*/
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboard = TextInputType.text,
    int minLines = 1,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      minLines: minLines,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.green),
        ),
      ),
    );
  }

  Widget _buildDatePicker(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _endDate ?? DateTime.now().add(const Duration(days: 7)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) setState(() => _endDate = picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 20),
            const SizedBox(width: 8),
            Text(
              _endDate == null
                  ? 'Select End Date *'
                  : DateFormat('yyyy-MM-dd').format(_endDate!),
              style: TextStyle(
                fontSize: 14,
                color: _endDate == null ? Colors.grey.shade600 : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // 이미지 선택 헤더
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.image, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Project Image',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.add_photo_alternate, size: 18),
                  label: const Text('Select Image'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.green,
                  ),
                ),
              ],
            ),
          ),
          
          // 선택된 이미지 또는 플레이스홀더
          Container(
            width: double.infinity,
            height: 200,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: _selectedImage != null && _imageBytes != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: kIsWeb
                        ? Image.memory(
                            _imageBytes!,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                          )
                        : Image.file(
                            File(_selectedImage!.path),
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                          ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.image_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No image selected',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap "Select Image" to choose a photo',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
          ),
          
          // 선택된 이미지가 있을 때 제거 버튼
          if (_selectedImage != null)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _removeImage,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Remove Image'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: BorderSide(color: Colors.red.shade300),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /*──── 이미지 선택 및 제거 ────*/
  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImage = image;
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      _snack('Failed to select image: $e', Colors.red);
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _imageBytes = null;
    });
  }

  /*──── 제출 처리 ────*/
  Future<void> _handleSubmit() async {
    if (_title.text.trim().isEmpty ||
        _goalAmount.text.trim().isEmpty ||
        _endDate == null) {
      _snack('Please fill all required fields', Colors.red);
      return;
    }

    final goal = int.tryParse(_goalAmount.text.replaceAll(',', ''));
    if (goal == null || goal <= 0) {
      _snack('Goal amount must be a positive number', Colors.red);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final params = CreateCampaignParams(
        title       : _title.text.trim(),
        subtitle    : _subtitle.text.trim(),
        description : _description.text.trim(),
        goalAmount  : goal,
        endDate     : _endDate!,
        company     : const CompanyInfo(id: 'eco', name: 'Eco Company'),
      );

      final res = await EcoBackend.instance.createCampaign(params);
      
      // 이미지가 선택되었다면 Firebase Storage에 업로드
      if (_selectedImage != null && _imageBytes != null) {
        try {
          final storageRef = FirebaseStorage.instance.ref(res.storagePath);
          
          if (kIsWeb) {
            // 웹에서는 putData 사용
            await storageRef.putData(_imageBytes!);
          } else {
            // 모바일에서는 putFile 사용
            await storageRef.putFile(File(_selectedImage!.path));
          }
          
          _snack('Funding project created with image!', Colors.green);
        } catch (uploadError) {
          print('Image upload failed: $uploadError');
          _snack('Project created but image upload failed', Colors.orange);
        }
      } else {
        _snack('Funding project created!', Colors.green);
      }

      if (mounted) Navigator.of(context).pop(res);
    } catch (e) {
      _snack('Failed to create: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
      ),
    );
  }
}
