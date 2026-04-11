
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myapp/firebase_api.dart';
import 'package:myapp/firebase_options.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'note_editor_page.dart';
import 'graph_view_page.dart';

const Uuid uuid = Uuid();

// --- 1. DATA MODELS (Adjusted for Firestore) ---

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

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'createdAt': createdAt,
        'imagePath': imagePath,
        'connections': connections.map((c) => c.toJson()).toList(),
      };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
        id: json['id'],
        title: json['title'],
        content: json['content'],
        createdAt: json['createdAt'] as Timestamp, // Firestore uses Timestamp
        imagePath: json['imagePath'],
        connections: (json['connections'] as List<dynamic>?)
                ?.map((c) => Connection.fromJson(c))
                .toList() ??
            [],
      );
}

// --- 2. STATE MANAGEMENT (Rewritten for Firestore) ---

enum LoadingStatus { loading, ready, error }

class NexusData extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot>? _notesSubscription;

  List<Note> _notes = [];
  String _searchQuery = '';
  LoadingStatus _status = LoadingStatus.loading;

  final _stopWords = {
    'a', 'al', 'el', 'la', 'los', 'las', 'un', 'una', 'unos', 'unas',
    'y', 'e', 'o', 'u', 'de', 'del', 'en', 'con', 'por', 'para', 'sin',
    'sobre', 'tras', 'que', 'como', 'cuando', 'donde', 'quien', 'cual',
    'mi', 'tu', 'su', 'nuestro', 'vuestro', 'mis', 'tus', 'sus',
    'es', 'soy', 'eres', 'somos', 'son'
  };

  NexusData() {
    listenToNotes();
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

  void listenToNotes() {
    _status = LoadingStatus.loading;
    notifyListeners();

    _notesSubscription?.cancel();
    _notesSubscription = _db
        .collection('notes')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      _notes = snapshot.docs.map((doc) => Note.fromJson(doc.data())).toList();
      _rebuildAllConnections();
      _status = LoadingStatus.ready;
      notifyListeners();
    }, onError: (_) {
      _status = LoadingStatus.error;
      notifyListeners();
    });
  }

  Future<void> addNote(Note note) async {
    await _db.collection('notes').doc(note.id).set(note.toJson());
  }

  Future<void> updateNote(Note updatedNote) async {
    await _db.collection('notes').doc(updatedNote.id).update(updatedNote.toJson());
  }

  Future<void> removeNote(String id) async {
    await _db.collection('notes').doc(id).delete();
  }

  void _rebuildAllConnections() {
    for (final note in _notes) {
      note.connections.clear();
    }

    for (int i = 0; i < _notes.length; i++) {
      for (int j = i + 1; j < _notes.length; j++) {
        final noteA = _notes[i];
        final noteB = _notes[j];

        final keywordsA = _extractKeywords(noteA.title);
        final keywordsB = _extractKeywords(noteB.title);
        final commonKeywords = keywordsA.intersection(keywordsB);

        if (commonKeywords.isNotEmpty) {
          final topic = commonKeywords.join(', ');
          noteA.connections.add(Connection(noteId: noteB.id, topic: topic));
          noteB.connections.add(Connection(noteId: noteA.id, topic: topic));
        }
      }
    }
  }

  Set<String> _extractKeywords(String text) {
    if (text.isEmpty) return {};
    final sanitizedText = text.toLowerCase().replaceAll(RegExp(r'[¿?¡!.,;:]'), '');
    return sanitizedText
        .split(' ')
        .where((word) => word.length > 2 && !_stopWords.contains(word))
        .toSet();
  }

  void createAndEditNoteFromTopic(BuildContext context, String topic) {
    final newNote = Note(
        id: uuid.v4(),
        title: topic,
        content: 'Desarrollar la idea sobre "$topic".',
        createdAt: Timestamp.now()); // Use Firestore Timestamp
    addNote(newNote);
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (context) => NoteEditorPage(note: newNote)),
    );
  }

  @override
  void dispose() {
    _notesSubscription?.cancel();
    super.dispose();
  }
}

// --- 3. MAIN APP & THEME ---

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: firebaseOptions,
  );
  await FirebaseApi().initNotifications();
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
          iconTheme: IconThemeData(color: Color(0xFF333333)),
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
          onRefresh: () async => data.listenToNotes(), // Changed to listenToNotes
          child: _buildNotesGrid(context, data.filteredNotes, data),
        );
    }
  }

  void _navigateToEditor(BuildContext context, NexusData data, {Note? note}) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NoteEditorPage(note: note)),
    ); // .then() is no longer needed due to real-time updates
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
            Align(
              alignment: Alignment.bottomRight,
              // Use toDate() to convert Timestamp to DateTime for formatting
              child: Text(DateFormat.yMMMd().format(note.createdAt.toDate()), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
            ),
          ]),
        ),
      ),
    );
  }
}
