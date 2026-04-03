import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const ListTile(
            leading: Icon(Icons.person),
            title: Text('Profile'),
            subtitle: Text('Manage your account'),
          ),
          const Divider(),
          SwitchListTile(
            value: false, // Wire to theme provider
            onChanged: (val) {},
            title: const Text('Dark Mode'),
            secondary: const Icon(Icons.dark_mode),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('Force Sync Data'),
            subtitle: const Text('Sync offline entries to server'),
            onTap: () {
              // trigger sync logic
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Syncing data...')),
              );
            },
          ),
        ],
      ),
    );
  }
}
