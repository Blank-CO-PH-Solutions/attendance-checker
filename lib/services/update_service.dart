import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  static const _collection = 'app_config';
  static const _doc = 'latest';

  /// Checks Firestore for a newer version. Auto-creates the config doc if missing.
  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersionCode = int.tryParse(packageInfo.buildNumber) ?? 0;
      final currentVersionName = packageInfo.version;

      final docRef = FirebaseFirestore.instance
          .collection(_collection)
          .doc(_doc);

      final doc = await docRef.get();

      // Auto-create with current version if doc doesn't exist
      if (!doc.exists) {
        await docRef.set({
          'minVersionCode': currentVersionCode,
          'latestVersionName': currentVersionName,
          'downloadUrl': '',
          'updateMessage': 'A new version is available.',
          'force': false,
        });
        return;
      }

      final data = doc.data()!;
      final latestVersionName = data['latestVersionName'] as String? ?? '';
      final downloadUrl = data['downloadUrl'] as String? ?? '';
      final updateMessage = data['updateMessage'] as String? ?? 'A new version is available.';
      final minVersionCode = data['minVersionCode'] as int? ?? 0;
      final force = data['force'] as bool? ?? false;

      // If no minVersionCode is set or current is >= min, no update needed
      if (minVersionCode > 0 && currentVersionCode < minVersionCode) {
        if (context.mounted) {
          await _showUpdateDialog(
            context,
            currentVersionName: currentVersionName,
            latestVersionName: latestVersionName,
            message: updateMessage,
            downloadUrl: downloadUrl,
            force: force,
          );
        }
      }
    } catch (e) {
      // Silently fail — update check should never block app usage
      debugPrint('Update check failed: $e');
    }
  }

  static Future<void> _showUpdateDialog(
    BuildContext context, {
    required String currentVersionName,
    required String latestVersionName,
    required String message,
    required String downloadUrl,
    required bool force,
  }) async {
    return showGeneralDialog(
      context: context,
      barrierDismissible: !force,
      barrierLabel: 'Update',
      pageBuilder: (ctx, _, __) {
        return PopScope(
          canPop: !force,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.system_update, color: Color(0xFFF59E0B), size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Text('Update Available')),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current',
                            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                          ),
                          Text(
                            'v$currentVersionName',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const Icon(Icons.arrow_forward, size: 18, color: Colors.grey),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Latest',
                            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                          ),
                          Text(
                            'v$latestVersionName',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              if (!force)
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Later'),
                ),
              ElevatedButton(
                onPressed: () async {
                  final uri = Uri.parse(downloadUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Update Now'),
              ),
            ],
          ),
        );
      },
    );
  }
}
