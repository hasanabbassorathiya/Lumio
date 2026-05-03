import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_update.dart';
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';
import '../services/service_locator.dart';
import '../i18n/app_strings.dart';

class UpdateManager {
  static final UpdateManager _instance = UpdateManager._internal();
  factory UpdateManager() => _instance;
  UpdateManager._internal();

  final UpdateService _updateService = UpdateService();

  // MethodChannel for installing APK on Android
  static const _installChannel = MethodChannel('com.flutteriptv/install');

  /// Check for updates and show update dialog
  Future<void> checkAndShowUpdateDialog(BuildContext context, {bool forceCheck = false}) async {
    try {
      ServiceLocator.log.d('UPDATE_MANAGER: Starting update check...');

      final update = await _updateService.checkForUpdates(forceCheck: forceCheck);

      if (update != null && context.mounted) {
        ServiceLocator.log.d('UPDATE_MANAGER: New version found, showing update dialog');
        _showUpdateDialog(context, update);
      } else {
        ServiceLocator.log.d('UPDATE_MANAGER: No new version found');
      }
    } catch (e) {
      ServiceLocator.log.d('UPDATE_MANAGER: Error checking for updates: $e');
    }
  }

  /// Manually check for updates
  Future<void> manualCheckForUpdate(BuildContext context) async {
    try {
      ServiceLocator.log.d('UPDATE_MANAGER: Manually checking for updates...');

      // Show loading hint
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              Text(AppStrings.of(context)!.checkingForUpdates),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );

      final update = await _updateService.checkForUpdates(forceCheck: true);

      // Hide loading hint
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      if (update != null && context.mounted) {
        ServiceLocator.log.d('UPDATE_MANAGER: New version found, showing update dialog');
        _showUpdateDialog(context, update);
      } else if (context.mounted) {
        ServiceLocator.log.d('UPDATE_MANAGER: Already latest version');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.of(context)!.alreadyLatestVersion),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ServiceLocator.log.d('UPDATE_MANAGER: Manually checking for updates... Error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.of(context)!.updateCheckFailed.replaceAll('{error}', e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Show update dialog
  void _showUpdateDialog(BuildContext context, AppUpdate update) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => UpdateDialog(
        update: update,
        onUpdate: () => _handleUpdate(context, update),
        onCancel: () {
          Navigator.of(context).pop();
          ServiceLocator.log.d('UPDATE_MANAGER: User chose to update later');
        },
      ),
    );
  }

  /// Handle update action
  Future<void> _handleUpdate(BuildContext context, AppUpdate update) async {
    try {
      ServiceLocator.log.d('UPDATE_MANAGER: User chose to update now');

      // Close dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (Platform.isAndroid) {
        await _downloadAndInstallAndroid(context, update);
      } else if (Platform.isWindows) {
        await _downloadAndInstallWindows(context, update);
      } else {
        // Open download page on other platforms
        await _updateService.openDownloadPage();
      }
    } catch (e) {
      ServiceLocator.log.d('UPDATE_MANAGER: Error handling update: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.of(context)!.updateFailed.replaceAll('{error}', e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Download and install APK on Android
  Future<void> _downloadAndInstallAndroid(BuildContext context, AppUpdate update) async {
    double progress = 0;
    bool cancelled = false;
    void Function(void Function())? dialogSetState;
    BuildContext? dialogContext;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        dialogContext = ctx;
        return StatefulBuilder(
          builder: (context, setState) {
            dialogSetState = setState;
            return AlertDialog(
              title: Text(AppStrings.of(context)!.downloadingUpdate),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 16),
                  Text('${(progress * 100).toStringAsFixed(1)}%'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    cancelled = true;
                    Navigator.of(ctx).pop();
                  },
                  child: Text(AppStrings.of(context)!.cancel),
                ),
              ],
            );
          },
        );
      },
    );

    try {
      final file = await _updateService.downloadUpdate(
        update,
        onProgress: (p) {
          if (!cancelled && dialogSetState != null) {
            progress = p;
            dialogSetState!(() {});
          }
        },
      );

      if (cancelled) {
        ServiceLocator.log.d('UPDATE_MANAGER: User cancelled download');
        // Delete incomplete download file
        if (file != null && await file.exists()) {
          await file.delete();
        }
        return;
      }

      // Close download dialog
      if (dialogContext != null && dialogContext!.mounted) {
        Navigator.of(dialogContext!).pop();
      }

      if (file != null) {
        ServiceLocator.log.d('UPDATE_MANAGER: Download complete, starting installation: ${file.path}');
        await _installApk(file.path);

        // Delete cache file after installation starts (delayed to ensure installer has read the file)
        Future.delayed(const Duration(seconds: 5), () async {
          try {
            if (await file.exists()) {
              await file.delete();
              ServiceLocator.log.d('UPDATE_MANAGER: Installation cache file deleted');
            }
          } catch (e) {
            ServiceLocator.log.d('UPDATE_MANAGER: Failed to delete cache file: $e');
          }
        });
      } else {
        throw Exception('Download failed');
      }
    } catch (e) {
      ServiceLocator.log.d('UPDATE_MANAGER: Download failed: $e');
      if (dialogContext != null && dialogContext!.mounted) {
        Navigator.of(dialogContext!).pop();
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.of(context)!.downloadFailed.replaceAll('{error}', e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Call native method to install APK
  Future<void> _installApk(String filePath) async {
    try {
      await _installChannel.invokeMethod('installApk', {'filePath': filePath});
    } catch (e) {
      ServiceLocator.log.d('UPDATE_MANAGER: Failed to install APK: $e');
      rethrow;
    }
  }

  /// Download and install on Windows
  Future<void> _downloadAndInstallWindows(BuildContext context, AppUpdate update) async {
    double progress = 0;
    bool cancelled = false;
    bool dialogOpen = true;
    void Function(void Function())? dialogSetState;
    final navigatorState = Navigator.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (_, setState) {
            dialogSetState = setState;
            return AlertDialog(
              title: Text(AppStrings.of(context)!.downloadingUpdate),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 16),
                  Text('${(progress * 100).toStringAsFixed(1)}%'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    cancelled = true;
                    dialogOpen = false;
                    Navigator.of(ctx).pop();
                  },
                  child: Text(AppStrings.of(context)!.cancel),
                ),
              ],
            );
          },
        );
      },
    );

    try {
      final file = await _updateService.downloadUpdate(
        update,
        onProgress: (p) {
          if (!cancelled && dialogSetState != null) {
            progress = p;
            dialogSetState!(() {});
          }
        },
      );

      if (cancelled) {
        ServiceLocator.log.d('UPDATE_MANAGER: User cancelled download');
        // Delete incomplete download file
        if (file != null && await file.exists()) {
          await file.delete();
          ServiceLocator.log.d('UPDATE_MANAGER: Incomplete download file deleted');
        }
        return;
      }

      // Close download dialog
      if (dialogOpen) {
        dialogOpen = false;
        navigatorState.pop();
      }

      ServiceLocator.log.d('UPDATE_MANAGER: Dialog closed, file=${file?.path}');

      if (file != null) {
        ServiceLocator.log.d('UPDATE_MANAGER: Download complete: ${file.path}');

        // Windows: Start installer
        if (context.mounted) {
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(AppStrings.of(context)!.downloadComplete),
              content: Text(AppStrings.of(context)!.runInstallerNowQuestion),
              actions: [
                TextButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    // User chose later, delete download file
                    try {
                      if (await file.exists()) {
                        await file.delete();
                        ServiceLocator.log.d('UPDATE_MANAGER: Download file deleted');
                      }
                    } catch (e) {
                      ServiceLocator.log.d('UPDATE_MANAGER: Failed to delete file: $e');
                    }
                  },
                  child: Text(AppStrings.of(context)!.later),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    ServiceLocator.log.d('UPDATE_MANAGER: Starting installer: ${file.path}');
                    // Start installer
                    await Process.start(file.path, [], mode: ProcessStartMode.detached);
                    // Exit current app
                    exit(0);
                  },
                  child: Text(AppStrings.of(context)!.installNow),
                ),
              ],
            ),
          );
        } else {
          ServiceLocator.log.d('UPDATE_MANAGER: Context not mounted, starting installation directly');
          await Process.start(file.path, [], mode: ProcessStartMode.detached);
          exit(0);
        }
      } else {
        throw Exception('Download failed');
      }
    } catch (e) {
      ServiceLocator.log.d('UPDATE_MANAGER: Download failed: $e');
      if (dialogOpen) {
        dialogOpen = false;
        navigatorState.pop();
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.of(context)!.downloadFailed.replaceAll('{error}', e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Get current app version
  Future<String> getCurrentVersion() async {
    try {
      return await _updateService.getCurrentVersion();
    } catch (e) {
      ServiceLocator.log.d('UPDATE_MANAGER: Failed to get current version: $e');
      return '0.0.0';
    }
  }
}
