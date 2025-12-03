import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../pages/login.dart';

enum ProfileAction { settings, language, logout }

class ProfileMenu extends StatelessWidget {
  final double menuOffsetX;
  final double menuOffsetY;

  /// menuOffsetX/Y untuk mengatur posisi pop-up bila perlu.
  const ProfileMenu({super.key, this.menuOffsetX = 0, this.menuOffsetY = 8});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    // Nama user fallback
    final userName = auth.user?['name']?.toString() ??
        auth.user?['email']?.toString() ??
        'User';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Nama (opsional). Kamu bisa sembunyikan jika ingin hanya avatar.
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: Text(
            userName,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),

        // Popup menu (avatar + caret)
        PopupMenuButton<ProfileAction>(
          offset: Offset(menuOffsetX, menuOffsetY),
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          // custom child supaya terlihat seperti avatar + caret
          child: const Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, color: Colors.red),
              ),
              SizedBox(width: 6),
              Icon(Icons.keyboard_arrow_down, color: Colors.white),
            ],
          ),
          onSelected: (ProfileAction action) async {
            switch (action) {
              case ProfileAction.settings:
                // Contoh: open settings page (belum dibuat)
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Open Settings (TODO)')),
                );
                break;
              case ProfileAction.language:
                // Contoh: open language switcher (belum dibuat)
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Switch Language (TODO)')),
                );
                break;
              case ProfileAction.logout:
                // Panggil provider untuk logout
                await auth.logout();

                // Redirect ke LoginPage (hapus semua route sebelumnya)
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => LoginPage()),
                  (route) => false,
                );
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: ProfileAction.settings,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.settings),
                title: Text('My Settings'),
              ),
            ),
            const PopupMenuItem(
              value: ProfileAction.language,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.language),
                title: Text('Switch Language'),
              ),
            ),
            const PopupMenuDivider(height: 6),
            const PopupMenuItem(
              value: ProfileAction.logout,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.logout, color: Colors.red),
                title: Text('Log Out', style: TextStyle(color: Colors.red)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
