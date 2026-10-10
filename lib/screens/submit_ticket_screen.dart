import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SubmitTicketScreen extends StatefulWidget {
  const SubmitTicketScreen({super.key});

  @override
  State<SubmitTicketScreen> createState() => _SubmitTicketScreenState();
}

class _SubmitTicketScreenState extends State<SubmitTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedCategoryId;
  final TextEditingController _descriptionController = TextEditingController();
  bool _isLoading = false;

  final List<Map<String, String>> _categories = [
    {'id': '1', 'name': 'Hardware'},
    {'id': '2', 'name': 'Software'},
    {'id': '3', 'name': 'Network'},
    {'id': '4', 'name': 'General IT'},
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_isLoading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null || token.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sesi login tidak valid. Silakan login ulang.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      final cleanToken = token.startsWith('Bearer ')
          ? token.substring(7).trim()
          : token.trim();

      final url = Uri.parse('http://10.0.2.2:8080/api/tickets');
      final body = jsonEncode({
        'description': _descriptionController.text.trim(),
        'categoryId': _selectedCategoryId,
      });

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $cleanToken',
          'Content-Type': 'application/json',
        },
        body: body,
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tiket berhasil dibuat!'),
            backgroundColor: Color(0xFF48CEA4),
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, true);
      } else {
        String errorMsg = 'Gagal membuat tiket (Status ${response.statusCode})';
        try {
          final resData = jsonDecode(response.body);
          if (resData is Map && resData.containsKey('error')) {
            errorMsg = resData['error'].toString();
          } else if (resData is Map && resData.containsKey('message')) {
            errorMsg = resData['message'].toString();
          }
        } catch (_) {
          if (response.body.trim().isNotEmpty) {
            errorMsg = response.body.trim();
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kesalahan jaringan: $e'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 3),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Color(0xFF1E293B),
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Submit New Ticket',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF48CEA4).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF48CEA4).withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Color(0xFF48CEA4),
                        size: 24,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Laporkan kendala IT Anda. Tim teknisi akan segera menindaklanjuti keluhan Anda.',
                          style: TextStyle(
                            color: Color(0xFF1E293B),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Form Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category Field
                      const Text(
                        'Category',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedCategoryId,
                        decoration: InputDecoration(
                          hintText: 'Select category',
                          hintStyle: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(
                            Icons.category_outlined,
                            color: Color(0xFF48CEA4),
                            size: 20,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFF48CEA4),
                              width: 1.5,
                            ),
                          ),
                        ),
                        items: _categories.map((cat) {
                          return DropdownMenuItem<String>(
                            value: cat['id'],
                            child: Text(
                              cat['name'] ?? '',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedCategoryId = val;
                          });
                        },
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return 'Silakan pilih kategori';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Issue Description Field
                      const Text(
                        'Issue Description',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descriptionController,
                        minLines: 5,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF1E293B),
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'Jelaskan kendala atau keluhan teknis Anda secara detail...',
                          hintStyle: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 14,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.all(16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFF48CEA4),
                              width: 1.5,
                            ),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Deskripsi masalah tidak boleh kosong';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF48CEA4),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _isLoading ? null : _handleSubmit,
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Submit Ticket',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
