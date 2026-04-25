
import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'main.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Needed for Timestamp

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getApplicationDocumentsDirectory();
    final path = join(dbPath.path, 'nexus.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE notes(
        id TEXT PRIMARY KEY,
        title TEXT,
        content TEXT,
        createdAt INTEGER,
        imagePath TEXT,
        connections TEXT
      )
    ''');
  }

  // --- CRUD Methods ---

  Future<void> addNote(Note note) async {
    final db = await database;
    await db.insert(
      'notes',
      _noteToMap(note),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Note>> getNotes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('notes', orderBy: 'createdAt DESC');

    if (maps.isEmpty) {
        return [];
    }

    return List.generate(maps.length, (i) => _mapToNote(maps[i]));
  }

  Future<void> updateNote(Note note) async {
    final db = await database;
    await db.update(
      'notes',
      _noteToMap(note),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  Future<void> removeNote(String id) async {
    final db = await database;
    await db.delete(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Data Conversion ---

  Map<String, dynamic> _noteToMap(Note note) {
    return {
      'id': note.id,
      'title': note.title,
      'content': note.content,
      'createdAt': note.createdAt.millisecondsSinceEpoch,
      'imagePath': note.imagePath,
      'connections': jsonEncode(note.connections.map((c) => c.toJson()).toList()),
    };
  }

  Note _mapToNote(Map<String, dynamic> map) {
     return Note(
        id: map['id'],
        title: map['title'],
        content: map['content'],
        createdAt: Timestamp.fromMillisecondsSinceEpoch(map['createdAt']),
        imagePath: map['imagePath'],
        connections: (jsonDecode(map['connections']) as List<dynamic>)
            .map((c) => Connection.fromJson(c))
            .toList(),
      );
  }
}
