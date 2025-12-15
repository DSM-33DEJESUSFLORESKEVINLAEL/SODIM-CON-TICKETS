import 'package:sodim/db/db_helper.dart';

class PendingUpload {
  final int? id;
  final String fileName;
  final String empresa;
  final String bytesB64;
  final String createdAt;
  final int attempts;
  final String? lastError;

  PendingUpload({
    this.id,
    required this.fileName,
    required this.empresa,
    required this.bytesB64,
    required this.createdAt,
    this.attempts = 0,
    this.lastError,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'file_name': fileName,
    'empresa': empresa,
    'bytes_b64': bytesB64,
    'created_at': createdAt,
    'attempts': attempts,
    'last_error': lastError,
  };

  static PendingUpload fromMap(Map<String, dynamic> m) => PendingUpload(
    id: m['id'] as int?,
    fileName: m['file_name'] as String,
    empresa: m['empresa'] as String,
    bytesB64: m['bytes_b64'] as String,
    createdAt: m['created_at'] as String,
    attempts: (m['attempts'] as int?) ?? 0,
    lastError: m['last_error'] as String?,
  );
}

class UploadQueueDAO {
  static const _table = 'pending_uploads';

  static Future<int> insert(PendingUpload u) async {
    final db = await DBHelper.initDb();
    return await db.insert(_table, u.toMap());
  }

  static Future<List<PendingUpload>> getAll() async {
    final db = await DBHelper.initDb();
    final rows = await db.query(_table, orderBy: 'created_at ASC, id ASC');
    return rows.map(PendingUpload.fromMap).toList();
  }

  static Future<void> remove(int id) async {
    final db = await DBHelper.initDb();
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> bumpAttempts({required int id, String? error}) async {
    final db = await DBHelper.initDb();
    await db.rawUpdate(
      'UPDATE $_table SET attempts = attempts + 1, last_error = ? WHERE id = ?',
      [error, id],
    );
  }
}
