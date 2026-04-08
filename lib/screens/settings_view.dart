import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notification_service.dart';
import 'profile_view.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  bool notifications = true;
  bool darkMode = false;
  bool haptics = true;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 10),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "Account",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.person),
            title: const Text("Profile"),
            subtitle: Text(user?.email ?? "Not signed in"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileView()),
              );
            },
          ),

          const Divider(),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "Preferences",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),

          SwitchListTile(
            title: const Text("Notifications"),
            value: notifications,
            onChanged: (val) {
              setState(() => notifications = val);
              if (!val) NotificationService.instance.cancelAll();
            },
          ),

          SwitchListTile(
            title: const Text("Dark Mode"),
            value: darkMode,
            onChanged: (val) => setState(() => darkMode = val),
          ),

          SwitchListTile(
            title: const Text("Haptics"),
            value: haptics,
            onChanged: (val) => setState(() => haptics = val),
          ),

        ],
      ),
    );
  }
}