import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Menampilkan modal dialog interaktif untuk memberikan rating & feedback tiket yang berstatus RESOLVED
Future<void> showRatingDialog(
  BuildContext context,
  dynamic ticket, {
  VoidCallback? onSuccess,
}) async {
  final ticketId = ticket['id'] ?? ticket['ticketId'];
  final TextEditingController feedbackController = TextEditingController();

  await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      int selectedRating = 5;
      bool isSubmitting = false;
      String? errorMessage;

      return StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            elevation: 8,
            backgroundColor: Colors.white,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFFDE68A),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.star_rounded,
                        size: 40,
                        color: Color(0xFFF59E0B),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    Text(
                      'rating_title'.tr(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Subtitle
                    Text(
                      'rating_subtitle'.tr(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Interactive 5 Star Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final starValue = index + 1;
                        final isFilled = starValue <= selectedRating;
                        return InkWell(
                          onTap: isSubmitting
                              ? null
                              : () {
                                  setDialogState(() {
                                    selectedRating = starValue;
                                  });
                                },
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: Icon(
                              isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                              size: 40,
                              color: isFilled
                                  ? const Color(0xFFFFB800)
                                  : const Color(0xFFCBD5E1),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 8),

                    // Rating description label
                    Text(
                      _getRatingLabel(selectedRating),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFF59E0B),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Error message if any
                    if (errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          errorMessage!,
                          style: const TextStyle(
                            color: Color(0xFFDC2626),
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],

                    // Multiline feedback input
                    TextField(
                      controller: feedbackController,
                      maxLines: 3,
                      minLines: 2,
                      enabled: !isSubmitting,
                      decoration: InputDecoration(
                        hintText: 'feedback_hint'.tr(),
                        hintStyle: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 13,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.all(14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFF48CEA4),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Action buttons
                    Row(
                      children: [
                        // Cancel button
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isSubmitting
                                ? null
                                : () => Navigator.of(dialogContext).pop(false),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'cancel'.tr(),
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Submit review button
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    setDialogState(() {
                                      isSubmitting = true;
                                      errorMessage = null;
                                    });

                                    try {
                                      final prefs =
                                          await SharedPreferences.getInstance();
                                      final token = prefs.getString('jwt_token') ?? '';

                                      final url = Uri.parse(
                                        'http://10.0.2.2:8080/api/tickets/$ticketId/feedback',
                                      );

                                      final response = await http.post(
                                        url,
                                        headers: {
                                          'Authorization': 'Bearer $token',
                                          'Content-Type': 'application/json',
                                        },
                                        body: jsonEncode({
                                          'rating': selectedRating,
                                          'feedback': feedbackController.text.trim(),
                                        }),
                                      );

                                      if (response.statusCode == 200) {
                                        if (dialogContext.mounted) {
                                          Navigator.of(dialogContext).pop(true);
                                        }

                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('feedback_success'.tr()),
                                              backgroundColor: const Color(0xFF48CEA4),
                                              behavior: SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                            ),
                                          );
                                          onSuccess?.call();
                                        }
                                      } else {
                                        setDialogState(() {
                                          isSubmitting = false;
                                          errorMessage =
                                              'Gagal mengirim ulasan (${response.statusCode})';
                                        });
                                      }
                                    } catch (e) {
                                      setDialogState(() {
                                        isSubmitting = false;
                                        errorMessage = 'Terjadi kesalahan: $e';
                                      });
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF48CEA4),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    'submit_review'.tr(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );

  feedbackController.dispose();
}

String _getRatingLabel(int rating) {
  switch (rating) {
    case 1:
      return '⭐ Sangat Tidak Puas';
    case 2:
      return '⭐⭐ Tidak Puas';
    case 3:
      return '⭐⭐⭐ Cukup';
    case 4:
      return '⭐⭐⭐⭐ Puas';
    case 5:
      return '⭐⭐⭐⭐⭐ Sangat Puas';
    default:
      return '';
  }
}
