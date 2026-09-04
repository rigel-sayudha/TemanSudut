import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../widgets/popup_notification.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/line_popup.dart';

class UserManagementTab extends StatefulWidget {
  const UserManagementTab({super.key});

  @override
  UserManagementTabState createState() => UserManagementTabState();
}

class UserManagementTabState extends State<UserManagementTab> {
  final ApiService _apiService = ApiService();
  List<dynamic> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  void refreshUsers() => _fetchUsers();

  Future<void> _fetchUsers({bool forceRefresh = false}) async {
    if (!mounted) return;
    // Try cache first
    if (!forceRefresh) {
      final cached = await CacheService.getMgmtUsers();
      if (cached != null && mounted) {
        setState(() {
          _users = cached;
          _isLoading = false;
        });
        // Silent background refresh
        _fetchUsers(forceRefresh: true);
        return;
      }
    }
    if (_users.isEmpty && mounted) {
      setState(() => _isLoading = true);
    }
    final users = await _apiService.getUsers();
    await CacheService.saveMgmtUsers(users);
    if (!mounted) return;
    setState(() {
      _users = users;
      _isLoading = false;
    });
  }

  void _showUserDialog({dynamic existingUser}) {
    final nameCtrl = TextEditingController(text: existingUser?['name'] ?? '');
    final emailCtrl = TextEditingController(text: existingUser?['email'] ?? '');
    final passCtrl = TextEditingController();
    String selectedRole = existingUser?['role'] ?? 'cashier';
    final isEdit = existingUser != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      isEdit ? 'Edit Karyawan' : 'Tambah Karyawan Baru',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 24),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Nama Lengkap',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: passCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: isEdit
                            ? 'Password (kosongkan jika tidak diubah)'
                            : 'Password',
                        prefixIcon: Icon(Icons.lock_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Peran (Role)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[400]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedRole,
                          isExpanded: true,
                          items: [
                            DropdownMenuItem(
                              value: 'cashier',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.point_of_sale,
                                    color: Colors.blue,
                                    size: 20,
                                  ),
                                  SizedBox(width: 12),
                                  Text('Kasir'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'owner',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.admin_panel_settings,
                                    color: Colors.orange,
                                    size: 20,
                                  ),
                                  SizedBox(width: 12),
                                  Text('Owner / Admin'),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            setSheetState(() => selectedRole = val!);
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
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
                          if (nameCtrl.text.isEmpty || emailCtrl.text.isEmpty) {
                            PopupNotification.show(
                              ctx,
                              title: 'Error',
                              message: 'Nama dan email wajib diisi.',
                              type: PopupType.warning,
                            );
                            return;
                          }
                          if (!isEdit && passCtrl.text.isEmpty) {
                            PopupNotification.show(
                              ctx,
                              title: 'Error',
                              message: 'Password wajib diisi untuk user baru.',
                              type: PopupType.warning,
                            );
                            return;
                          }

                          Navigator.pop(sheetCtx);

                          Map<String, dynamic> data = {
                            'name': nameCtrl.text,
                            'email': emailCtrl.text,
                            'role': selectedRole,
                          };
                          if (passCtrl.text.isNotEmpty) {
                            data['password'] = passCtrl.text;
                          }

                          LoadingOverlay.show(
                            context,
                            message: isEdit
                                ? 'Menyimpan perubahan...'
                                : 'Menambah karyawan...',
                          );
                          bool success;
                          if (isEdit) {
                            success = await _apiService.updateUser(
                              existingUser['id'],
                              data,
                            );
                          } else {
                            success = await _apiService.createUser(data);
                          }
                          LoadingOverlay.hide(context);

                          if (success) {
                            PopupNotification.show(
                              context,
                              title: 'Berhasil!',
                              message: isEdit
                                  ? 'Data karyawan berhasil diperbarui.'
                                  : 'Karyawan baru berhasil ditambahkan.',
                              type: PopupType.success,
                            );
                            await CacheService.invalidateMgmtUsers();
                            _fetchUsers(forceRefresh: true);
                          } else {
                            PopupNotification.show(
                              context,
                              title: 'Gagal',
                              message:
                                  'Terjadi kesalahan. Periksa data yang diisi.',
                              type: PopupType.error,
                            );
                          }
                        },
                        child: Text(
                          isEdit ? 'Simpan Perubahan' : 'Tambah Karyawan',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
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
      },
    );
  }

  void _confirmDelete(dynamic user) {
    LinePopup.showDual(
      context,
      title: 'Hapus User?',
      description:
          'Yakin ingin menghapus "${user['name']}"? Aksi ini tidak bisa dibatalkan.',
      dismissText: 'Batal',
      affirmText: 'Hapus',
      affirmColor: Colors.red,
      onAffirm: () async {
        LoadingOverlay.show(context, message: 'Menghapus user...');
        final success = await _apiService.deleteUser(user['id']);
        LoadingOverlay.hide(context);
        if (success) {
          PopupNotification.show(
            context,
            title: 'Dihapus',
            message: '"${user['name']}" telah dihapus.',
            type: PopupType.success,
          );
          await CacheService.invalidateMgmtUsers();
          _fetchUsers(forceRefresh: true);
        } else {
          PopupNotification.show(
            context,
            title: 'Gagal',
            message: 'Tidak bisa menghapus user.',
            type: PopupType.error,
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          'Kelola Karyawan',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.black),
            onPressed: () => _fetchUsers(forceRefresh: true),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF5D4037),
        foregroundColor: Colors.white,
        icon: Icon(Icons.person_add),
        label: Text('Tambah User'),
        onPressed: () => _showUserDialog(),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.black))
          : _users.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
                  SizedBox(height: 16),
                  Text(
                    'Belum ada karyawan',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Tekan tombol + untuk menambah user',
                    style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                  ),
                  SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () => _fetchUsers(forceRefresh: true),
                    icon: Icon(Icons.refresh),
                    label: Text('Coba Lagi'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                final isOwner = user['role'] == 'owner';

                return Container(
                  margin: EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: isOwner
                          ? Colors.orange[100]
                          : Colors.blue[100],
                      child: Icon(
                        isOwner
                            ? Icons.admin_panel_settings
                            : Icons.point_of_sale,
                        color: isOwner ? Colors.orange[800] : Colors.blue[800],
                      ),
                    ),
                    title: Text(
                      user['name'],
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user['email'],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 4),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isOwner
                                ? Colors.orange[50]
                                : Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isOwner ? 'OWNER' : 'KASIR',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isOwner
                                  ? Colors.orange[800]
                                  : Colors.blue[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit_outlined, color: Colors.black),
                          onPressed: () => _showUserDialog(existingUser: user),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _confirmDelete(user),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
