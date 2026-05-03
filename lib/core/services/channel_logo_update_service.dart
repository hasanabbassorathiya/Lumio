import 'dart:convert';
import 'package:http/http.dart' as http;
import '../database/database_helper.dart';
import '../services/service_locator.dart';

class ChannelLogoUpdateService {
  final DatabaseHelper _db;
  static const String _remoteUrl = 'https://raw.githubusercontent.com/username/repo/main/channel_logos.sql'; // Placeholder

  ChannelLogoUpdateService(this._db);

  Future<void> updateLogos() async {
    try {
      ServiceLocator.log.d('Updating logos from remote...');
      final response = await http.get(Uri.parse(_remoteUrl));
      if (response.statusCode == 200) {
        final sql = response.body;
        await _applySql(sql);
        ServiceLocator.log.d('Logos updated successfully');
      }
    } catch (e) {
      ServiceLocator.log.e('Logo update failed: $e');
    }
  }

  Future<void> _applySql(String sql) async {
    final statements = sql
        .split('\n')
        .where((line) => line.trim().startsWith('INSERT'))
        .toList();

    await _db.db.transaction((txn) async {
      await txn.delete('channel_logos');
      for (final statement in statements) {
        await txn.rawInsert(statement);
      }
    });
  }
}
