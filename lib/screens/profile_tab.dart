import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/notification_prefs_provider.dart';
import '../services/api_service.dart';
import '../widgets/popup_notification.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  static InputDecoration _inputDeco(String label, IconData icon) =>
      InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF5D4037), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      );

  static Widget _handle() => Container(
    width: 40,
    height: 4,
    margin: const EdgeInsets.only(top: 12, bottom: 24),
    decoration: BoxDecoration(
      color: Colors.grey[300],
      borderRadius: BorderRadius.circular(2),
    ),
  );

  static Widget _sheetWrap({required Widget child}) => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [_handle(), child]),
  );

  // ── Edit Profile ────────────────────────────────────────────────────────────
  void _showEditProfile(BuildContext context, AuthProvider auth) {
    final nameCtrl = TextEditingController(text: auth.user?['name'] ?? '');
    final emailCtrl = TextEditingController(text: auth.user?['email'] ?? '');
    final api = ApiService();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _sheetWrap(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Edit Profil',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameCtrl,
                decoration: _inputDeco('Nama Lengkap', Icons.person_outline),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDeco('Email', Icons.email_outlined),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5D4037),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty ||
                        emailCtrl.text.trim().isEmpty) {
                      PopupNotification.show(
                        ctx,
                        title: 'Error',
                        message: 'Nama dan email wajib diisi.',
                        type: PopupType.warning,
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    final res = await api.updateProfile(
                      nameCtrl.text.trim(),
                      emailCtrl.text.trim(),
                    );
                    if (res['success'] == true) {
                      await auth.fetchUser();
                      PopupNotification.show(
                        context,
                        title: 'Berhasil!',
                        message: 'Profil berhasil diperbarui.',
                        type: PopupType.success,
                      );
                    } else {
                      PopupNotification.show(
                        context,
                        title: 'Gagal',
                        message: res['message'] ?? 'Terjadi kesalahan.',
                        type: PopupType.error,
                      );
                    }
                  },
                  child: const Text(
                    'Simpan Perubahan',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Change Password ─────────────────────────────────────────────────────────
  void _showChangePassword(BuildContext context) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final api = ApiService();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        bool showCurrent = false, showNew = false, showConfirm = false;
        return StatefulBuilder(
          builder: (ctx2, setModal) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx2).viewInsets.bottom,
            ),
            child: _sheetWrap(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ganti Password',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: currentCtrl,
                    obscureText: !showCurrent,
                    decoration: _inputDeco('Password Lama', Icons.lock_outline)
                        .copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                              showCurrent
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              size: 20,
                            ),
                            onPressed: () =>
                                setModal(() => showCurrent = !showCurrent),
                          ),
                        ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: newCtrl,
                    obscureText: !showNew,
                    decoration:
                        _inputDeco(
                          'Password Baru (min. 6 karakter)',
                          Icons.lock_outline,
                        ).copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                              showNew ? Icons.visibility_off : Icons.visibility,
                              size: 20,
                            ),
                            onPressed: () => setModal(() => showNew = !showNew),
                          ),
                        ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: confirmCtrl,
                    obscureText: !showConfirm,
                    decoration:
                        _inputDeco(
                          'Konfirmasi Password Baru',
                          Icons.lock_outline,
                        ).copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                              showConfirm
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              size: 20,
                            ),
                            onPressed: () =>
                                setModal(() => showConfirm = !showConfirm),
                          ),
                        ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5D4037),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        if (currentCtrl.text.isEmpty ||
                            newCtrl.text.isEmpty ||
                            confirmCtrl.text.isEmpty) {
                          PopupNotification.show(
                            ctx2,
                            title: 'Error',
                            message: 'Semua kolom wajib diisi.',
                            type: PopupType.warning,
                          );
                          return;
                        }
                        if (newCtrl.text != confirmCtrl.text) {
                          PopupNotification.show(
                            ctx2,
                            title: 'Error',
                            message: 'Konfirmasi password tidak cocok.',
                            type: PopupType.warning,
                          );
                          return;
                        }
                        if (newCtrl.text.length < 6) {
                          PopupNotification.show(
                            ctx2,
                            title: 'Error',
                            message: 'Password minimal 6 karakter.',
                            type: PopupType.warning,
                          );
                          return;
                        }
                        Navigator.pop(ctx2);
                        final res = await api.changePassword(
                          currentCtrl.text,
                          newCtrl.text,
                        );
                        if (res['success'] == true) {
                          PopupNotification.show(
                            context,
                            title: 'Berhasil!',
                            message: 'Password berhasil diperbarui.',
                            type: PopupType.success,
                          );
                        } else {
                          PopupNotification.show(
                            context,
                            title: 'Gagal',
                            message: res['message'] ?? 'Terjadi kesalahan.',
                            type: PopupType.error,
                          );
                        }
                      },
                      child: const Text(
                        'Ganti Password',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Notifications ────────────────────────────────────────────────────────────
  void _showNotifications(BuildContext context) {
    final notifProvider = context.read<NotificationPrefsProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        bool order = notifProvider.orderNotif;
        bool finance = notifProvider.financeNotif;
        bool system = notifProvider.systemNotif;
        return StatefulBuilder(
          builder: (ctx2, setModal) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx2).viewInsets.bottom,
            ),
            child: _sheetWrap(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Notifikasi',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Atur preferensi notifikasi Anda',
                      style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 20),
                    _notifTile(
                      'Notifikasi Pesanan',
                      'Pesanan masuk & selesai',
                      Icons.receipt_long_outlined,
                      order,
                      (v) => setModal(() => order = v),
                    ),
                    _notifTile(
                      'Notifikasi Keuangan',
                      'Catatan keuangan baru',
                      Icons.account_balance_wallet_outlined,
                      finance,
                      (v) => setModal(() => finance = v),
                    ),
                    _notifTile(
                      'Notifikasi Sistem',
                      'Pembaruan & info aplikasi',
                      Icons.info_outline,
                      system,
                      (v) => setModal(() => system = v),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5D4037),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          await notifProvider.save(
                            order: order,
                            finance: finance,
                            system: system,
                          );
                          Navigator.pop(ctx2);
                          PopupNotification.show(
                            context,
                            title: 'Disimpan',
                            message: 'Pengaturan notifikasi berhasil disimpan.',
                            type: PopupType.success,
                          );
                        },
                        child: const Text(
                          'Simpan Pengaturan',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
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
      },
    );
  }

  static Widget _notifTile(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.grey[50],
      borderRadius: BorderRadius.circular(12),
    ),
    child: SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: Icon(icon, color: const Color(0xFF5D4037)),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
      ),
      value: value,
      activeThumbColor: const Color(0xFF5D4037),
      onChanged: onChanged,
    ),
  );

  // ── Language ─────────────────────────────────────────────────────────────────
  void _showLanguage(BuildContext context) {
    final localeProvider = context.read<LocaleProvider>();
    final langs = [
      {'code': 'id', 'label': 'Bahasa Indonesia', 'flag': '🇮🇩'},
      {'code': 'en', 'label': 'English', 'flag': '🇺🇸'},
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String selected = localeProvider.languageCode;
        return StatefulBuilder(
          builder: (ctx2, setModal) => _sheetWrap(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pilih Bahasa',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                ...langs.map((l) {
                  final isSel = selected == l['code'];
                  return GestureDetector(
                    onTap: () => setModal(() => selected = l['code']!),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: isSel
                            ? const Color(0xFF5D4037).withOpacity(0.08)
                            : Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSel
                              ? const Color(0xFF5D4037)
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            l['flag']!,
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            l['label']!,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isSel
                                  ? const Color(0xFF5D4037)
                                  : Colors.black87,
                            ),
                          ),
                          const Spacer(),
                          if (isSel)
                            const Icon(
                              Icons.check_circle,
                              color: Color(0xFF5D4037),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5D4037),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      // Terapkan locale ke seluruh aplikasi via provider
                      await localeProvider.setLocale(selected);
                      Navigator.pop(ctx2);
                      PopupNotification.show(
                        context,
                        title: selected == 'en'
                            ? 'Language Changed'
                            : 'Bahasa Diperbarui',
                        message: selected == 'en'
                            ? 'App language changed to English.'
                            : 'Bahasa aplikasi diubah ke Bahasa Indonesia.',
                        type: PopupType.success,
                      );
                    },
                    child: const Text(
                      'Terapkan',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Help & Support ───────────────────────────────────────────────────────────
  void _showHelp(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _sheetWrap(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bantuan & Dukungan',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _helpTile(
              ctx,
              Icons.book_outlined,
              'Panduan Penggunaan',
              'Cara menggunakan fitur-fitur aplikasi',
            ),
            _helpTile(
              ctx,
              Icons.bug_report_outlined,
              'Laporkan Masalah',
              'Temukan bug? Laporkan ke kami',
            ),
            _helpTile(
              ctx,
              Icons.chat_bubble_outline,
              'Hubungi Kami',
              'Kontak support via WhatsApp atau email',
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  static Widget _helpTile(
    BuildContext ctx,
    IconData icon,
    String title,
    String subtitle,
  ) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      color: Colors.grey[50],
      borderRadius: BorderRadius.circular(12),
    ),
    child: ListTile(
      leading: Icon(icon, color: const Color(0xFF5D4037)),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: () {},
    ),
  );

  // ── Logout ───────────────────────────────────────────────────────────────────
  void _showLogoutConfirm(BuildContext context, AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _sheetWrap(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red[50],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.logout, color: Colors.red[600], size: 36),
            ),
            const SizedBox(height: 16),
            const Text(
              'Keluar dari Akun?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Anda akan keluar dan perlu login kembali.',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      'Batal',
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      auth.logout();
                    },
                    child: const Text(
                      'Ya, Keluar',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final user = auth.user;
        final String name = user?['name'] ?? 'Admin User';
        final String email = user?['email'] ?? 'admin@example.com';
        final bool isOwner = (user?['role'] ?? 'cashier') == 'owner';
        final localeProvider = context.watch<LocaleProvider>();
        final langLabel = localeProvider.isEnglish ? 'English' : 'Indonesia';

        return Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            automaticallyImplyLeading: false,
            title: const Text(
              'Profil',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                // Header
                Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                  child: Column(
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF8D6E63), Color(0xFF5D4037)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF5D4037).withOpacity(0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'A',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isOwner ? Colors.orange[50] : Colors.blue[50],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isOwner
                                  ? Icons.admin_panel_settings
                                  : Icons.point_of_sale,
                              size: 14,
                              color: isOwner
                                  ? Colors.orange[700]
                                  : Colors.blue[700],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isOwner ? 'Owner / Admin' : 'Kasir',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isOwner
                                    ? Colors.orange[700]
                                    : Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Menu
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      _menuItem(
                        context,
                        Icons.edit_outlined,
                        'Edit Profil',
                        'Ubah nama dan email',
                        () => _showEditProfile(context, auth),
                      ),
                      _div(),
                      _menuItem(
                        context,
                        Icons.lock_outline,
                        'Ganti Password',
                        'Perbarui kata sandi akun',
                        () => _showChangePassword(context),
                      ),
                      _div(),
                      _menuItem(
                        context,
                        Icons.notifications_outlined,
                        'Notifikasi',
                        'Atur preferensi notifikasi',
                        () => _showNotifications(context),
                      ),
                      _div(),
                      _menuItem(
                        context,
                        Icons.language_outlined,
                        'Bahasa',
                        'Pilih bahasa aplikasi',
                        () => _showLanguage(context),
                        trailing: langLabel,
                      ),
                      _div(),
                      _menuItem(
                        context,
                        Icons.help_outline,
                        'Bantuan & Dukungan',
                        'FAQ, panduan, dan kontak',
                        () => _showHelp(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  color: Colors.white,
                  child: _menuItem(
                    context,
                    Icons.logout,
                    'Keluar',
                    'Keluar dari akun Anda',
                    () => _showLogoutConfirm(context, auth),
                    isDestructive: true,
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _menuItem(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap, {
    String? trailing,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? Colors.red[600]! : const Color(0xFF5D4037);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDestructive
                    ? Colors.red[50]
                    : const Color(0xFF5D4037).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isDestructive ? Colors.red[600] : Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              Text(
                trailing,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              const SizedBox(width: 6),
            ],
            Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }

  Widget _div() =>
      Divider(height: 1, indent: 56, endIndent: 20, color: Colors.grey[100]);
}
