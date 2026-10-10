import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _userName = 'Pengguna';
  String _userRole = 'USER';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _userName = prefs.getString('user_name') ?? 'Pengguna';
        _userRole = prefs.getString('user_role') ?? 'USER';
      });
    }
  }

  Future<void> _handleLogout() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'logout_confirm_title'.tr(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        content: Text(
          'logout_confirm_desc'.tr(),
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'cancel'.tr(),
              style: const TextStyle(color: Color(0xFF94A3B8)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('logout'.tr()),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_name');
    await prefs.remove('user_role');

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLocale = context.locale;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'settings'.tr(),
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Color(0xFF1E293B),
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Profile Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor:
                          const Color(0xFF48CEA4).withValues(alpha: 0.15),
                      child: const Icon(
                        Icons.person,
                        size: 32,
                        color: Color(0xFF48CEA4),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _userName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _userRole,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Section: Preferences
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  'preferences'.tr(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.language,
                      color: Color(0xFF3B82F6),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'change_language'.tr(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  subtitle: Text(
                    currentLocale.languageCode == 'id'
                        ? 'indonesian'.tr()
                        : 'english'.tr(),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  trailing: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: currentLocale.languageCode,
                      icon: const Icon(
                        Icons.keyboard_arrow_down,
                        color: Color(0xFF64748B),
                      ),
                      borderRadius: BorderRadius.circular(12),
                      items: const [
                        DropdownMenuItem(
                          value: 'id',
                          child: Text(
                            '🇮🇩 ID',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'en',
                          child: Text(
                            '🇬🇧 EN',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ),
                      ],
                      onChanged: (newLang) {
                        if (newLang != null) {
                          context.setLocale(Locale(newLang));
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Section: Account
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  'account'.tr(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE11D48).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.logout,
                      color: Color(0xFFE11D48),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'logout'.tr(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFE11D48),
                    ),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Color(0xFFCBD5E1),
                  ),
                  onTap: _handleLogout,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
