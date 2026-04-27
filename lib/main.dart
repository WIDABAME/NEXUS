
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myapp/database_helper.dart';
import 'package:myapp/firebase_options.dart';
import 'package:myapp/notification_service.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'note_editor_page.dart';
import 'graph_view_page.dart';

const Uuid uuid = Uuid();

// --- Configuration ---
const bool USE_EMULATOR = false;
const String EMULATOR_HOST = '192.168.80.63';

// --- 1. DATA MODELS ---

class Connection {
  final String noteId;
  final String topic;

  Connection({required this.noteId, required this.topic});

  Map<String, dynamic> toJson() => {
        'noteId': noteId,
        'topic': topic,
      };

  factory Connection.fromJson(Map<String, dynamic> json) => Connection(
        noteId: json['noteId'],
        topic: json['topic'],
      );
}

class Note {
  final String id;
  String title;
  String content;
  final Timestamp createdAt;
  String? imagePath;
  List<Connection> connections;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    this.imagePath,
    List<Connection>? connections,
  }) : connections = connections ?? [];
}

// --- 2. STATE MANAGEMENT (Using local DB and remote functions) ---

enum LoadingStatus { loading, ready, error }

class NexusData extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  List<Note> _notes = [];
  String _searchQuery = '';
  LoadingStatus _status = LoadingStatus.loading;

  NexusData() {
    loadNotes();
  }

  List<Note> get notes => List.unmodifiable(_notes);
  List<Note> get filteredNotes => _searchQuery.isEmpty
      ? List.unmodifiable(_notes)
      : List.unmodifiable(_notes.where((note) {
          final query = _searchQuery.toLowerCase();
          return note.title.toLowerCase().contains(query) ||
              note.content.toLowerCase().contains(query);
        }));

  String get searchQuery => _searchQuery;
  LoadingStatus get loadingStatus => _status;

  void updateSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> loadNotes() async {
    try {
      _status = LoadingStatus.loading;
      notifyListeners();
      _notes = await _dbHelper.getNotes();
      // await _rebuildAllConnections();
      _status = LoadingStatus.ready;
    } catch (e) {
      print("Error loading notes: $e");
      _status = LoadingStatus.error;
    }
    notifyListeners();
  }

  Future<void> addNote(Note note) async {
    await _dbHelper.addNote(note);
    NotificationService().showNotification(
      'Nueva Nota Creada',
      'Se ha añadido la nota: "${note.title}"',
    );
    await loadNotes();
    // await _rebuildAllConnections(); // Recalculate connections
    notifyListeners();
  }

  Future<void> updateNote(Note updatedNote) async {
    await _dbHelper.updateNote(updatedNote);
     NotificationService().showNotification(
      'Nota Actualizada',
      'Se ha modificado la nota: "${updatedNote.title}"',
    );
    await loadNotes();
    // await _rebuildAllConnections(); // Recalculate connections
    notifyListeners();
  }

  Future<void> removeNote(String id) async {
    await _dbHelper.removeNote(id);
    NotificationService().showNotification(
      'Nota Eliminada',
      'Una nota ha sido eliminada.', // Generic message
    );
    await loadNotes();
    // await _rebuildAllConnections(); // Recalculate connections
    notifyListeners();
  }

  Future<void> addManualConnection(Note fromNote, Note toNote) async {
    // Avoid duplicate connections
    if (fromNote.connections.any((c) => c.noteId == toNote.id)) return;

    // Create connections
    final fromConnection = Connection(noteId: toNote.id, topic: 'manual');
    final toConnection = Connection(noteId: fromNote.id, topic: 'manual');

    fromNote.connections.add(fromConnection);
    toNote.connections.add(toConnection);

    // Persist changes
    await _dbHelper.updateNote(fromNote);
    await _dbHelper.updateNote(toNote);

    notifyListeners();
  }

  Future<void> _rebuildAllConnections() async {
    if (_notes.isEmpty) return;

    try {
      final HttpsCallable callable = _functions.httpsCallable('rebuildConnections');
      final notesData = _notes.map((n) => {'id': n.id, 'title': n.title}).toList();

      final result = await callable.call<Map<String, dynamic>>({
        'notes': notesData,
      });

      final allConnections = result.data['connections'] as Map<String, dynamic>;

      for (final note in _notes) {
        // Preserve manual connections
        final manualConnections = note.connections.where((c) => c.topic == 'manual').toList();
        note.connections.clear();
        note.connections.addAll(manualConnections);

        if (allConnections.containsKey(note.id)) {
          final connectionsForNote = allConnections[note.id] as List<dynamic>;
          final automaticConnections = connectionsForNote
              .map((c) => Connection.fromJson(c as Map<String, dynamic>))
              .where((c) => !note.connections.any((manual) => manual.noteId == c.noteId)); // Avoid duplicates
          note.connections.addAll(automaticConnections);
        }
        await _dbHelper.updateNote(note); // Persist connections to local DB
      }
    } on FirebaseFunctionsException catch (e) {
      print('Functions Error: ${e.code} - ${e.message}');
    } catch (e) {
      print('Generic Error calling function: $e');
    }
  }

  void createAndEditNoteFromTopic(BuildContext context, String topic) {
    final newNote = Note(
        id: uuid.v4(),
        title: topic,
        content: 'Desarrollar la idea sobre "$topic".',
        createdAt: Timestamp.now());
    addNote(newNote);
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (context) => NoteEditorPage(note: newNote)),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

// --- 3. MAIN APP & THEME ---

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: firebaseOptions,
  );

  if (USE_EMULATOR) {
    try {
      FirebaseFunctions.instance.useFunctionsEmulator(EMULATOR_HOST, 5001);
      print("Functions emulator connected");
    } catch (e) {
      print("Error connecting to functions emulator: $e");
    }
  }

  await NotificationService().init();

  runApp(
    ChangeNotifierProvider(
      create: (context) => NexusData(),
      child: const NexusApp(),
    ),
  );
}

class NexusApp extends StatelessWidget {
  const NexusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nexus',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFFFBFBFF),
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme).apply(bodyColor: const Color(0xFF333333)),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: const Color(0xFF333333)),
          titleTextStyle: TextStyle(
              color: Color(0xFF333333), fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      home: const NexusHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// --- 4. HOME PAGE ---

class NexusHomePage extends StatelessWidget {
  const NexusHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NexusData>(
      builder: (context, data, child) {
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                _buildCustomAppBar(context, data),
                _buildHeader(context, data),
                Expanded(
                  child: _buildBody(context, data),
                ),
              ],
            ),
          ),
          floatingActionButton: _buildGradientFab(context, data),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, NexusData data) {
     switch (data.loadingStatus) {
      case LoadingStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case LoadingStatus.error:
        return const Center(child: Text('Error al cargar las notas.'));
      case LoadingStatus.ready:
        if (data.filteredNotes.isEmpty) {
          return _buildEmptyState(context, isSearching: data.searchQuery.isNotEmpty);
        }
        return RefreshIndicator(
          onRefresh: () async => data.loadNotes(),
          child: _buildNotesGrid(context, data.filteredNotes, data),
        );
    }
  }

  void _navigateToEditor(BuildContext context, NexusData data, {Note? note}) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NoteEditorPage(note: note)),
    );
  }

  void _navigateToGraphView(BuildContext context, NexusData data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GraphViewPage(notes: data.notes),
      ),
    );
  }

  Widget _buildCustomAppBar(BuildContext context, NexusData data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(children: [
        const Icon(Icons.bubble_chart, color: Colors.deepPurple, size: 30),
        const SizedBox(width: 8),
        Text('Nexus', style: Theme.of(context).appBarTheme.titleTextStyle),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.auto_graph),
          onPressed: data.loadingStatus == LoadingStatus.ready
              ? () => _navigateToGraphView(context, data)
              : null,
        ),
      ]),
    );
  }

  Widget _buildHeader(BuildContext context, NexusData data) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Tus Notas', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        TextField(
          onChanged: data.updateSearchQuery,
          decoration: const InputDecoration(
            hintText: 'Buscar...',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
          ),
        ),
      ]),
    );
  }

  Widget _buildEmptyState(BuildContext context, {required bool isSearching}) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(isSearching ? Icons.search_off : Icons.lightbulb_outline, size: 60, color: Colors.grey[400]),
        const SizedBox(height: 16),
        Text(
          isSearching ? 'No se encontraron notas' : 'Crea tu primera nota',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          isSearching ? 'Intenta con otra búsqueda' : 'Presiona el botón + para empezar',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }

  Widget _buildNotesGrid(BuildContext context, List<Note> notes, NexusData data) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        return NoteCard(note: note, data: data, onTap: () => _navigateToEditor(context, data, note: note));
      },
    );
  }

  Widget _buildGradientFab(BuildContext context, NexusData data) {
    return FloatingActionButton(
      onPressed: () => _navigateToEditor(context, data),
      child: const Icon(Icons.add),
    );
  }
}

class NoteCard extends StatelessWidget {
  final Note note;
  final NexusData data;
  final VoidCallback onTap;

  const NoteCard({super.key, required this.note, required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: () {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Eliminar Nota'),
            content: const Text('¿Estás seguro de que quieres eliminar esta nota?'),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  data.removeNote(note.id);
                },
                child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
      child: Card(
        elevation: 2.0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(note.title, style: Theme.of(context).textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Expanded(
              child: Text(note.content, style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.fade),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (note.connections.isNotEmpty)
                  Chip(
                    avatar: const Icon(Icons.link, size: 14),
                    label: Text(note.connections.length.toString(), style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(0),
                  ),
                const Spacer(), // Pushes the date to the right
                Text(DateFormat.yMMMd().format(note.createdAt.toDate()), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}
