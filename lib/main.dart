import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart'; // Para formatear la fecha
import 'note_editor_page.dart'; // Importa la nueva página

const Uuid uuid = Uuid();

// --- 1. MODELO DE DATOS ---

class Note {
  final String id;
  String title;
  String content;
  final DateTime createdAt;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
    id: json['id'],
    title: json['title'],
    content: json['content'],
    createdAt: DateTime.parse(json['createdAt']),
  );
}

// --- 2. GESTOR DE ESTADO ---

class NexusData extends ChangeNotifier {
  List<Note> _notes = [];
  String _searchQuery = '';

  NexusData() {
    _loadNotes();
  }

  List<Note> get filteredNotes {
    if (_searchQuery.isEmpty) {
      return List<Note>.unmodifiable(_notes);
    }
    return List<Note>.unmodifiable(
      _notes.where((note) {
        final titleMatch = note.title.toLowerCase().contains(
          _searchQuery.toLowerCase(),
        );
        final contentMatch = note.content.toLowerCase().contains(
          _searchQuery.toLowerCase(),
        );
        return titleMatch || contentMatch;
      }),
    );
  }

  String get searchQuery => _searchQuery;

  void updateSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final String? notesJson = prefs.getString('nexus_notes');
    if (notesJson != null) {
      final List<dynamic> decodedList = jsonDecode(notesJson);
      _notes = decodedList.map((json) => Note.fromJson(json)).toList();
    }
    _notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    notifyListeners();
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedList = jsonEncode(
      _notes.map((note) => note.toJson()).toList(),
    );
    await prefs.setString('nexus_notes', encodedList);
  }

  void addNote(Note note) {
    _notes.insert(0, note);
    _saveNotes();
    notifyListeners();
  }

  void updateNote(Note updatedNote) {
    final index = _notes.indexWhere((note) => note.id == updatedNote.id);
    if (index != -1) {
      _notes[index] = updatedNote;
      _notes.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Re-sort
      _saveNotes();
      notifyListeners();
    }
  }

  void removeNote(String id) {
    _notes.removeWhere((note) => note.id == id);
    _saveNotes();
    notifyListeners();
  }
}

// --- 3. APP PRINCIPAL Y TEMA ---

void main() async {
  // Forzando un reinicio completo para arreglar la interactividad.
  WidgetsFlutterBinding.ensureInitialized();
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
    final textTheme = GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);

    return MaterialApp(
      title: 'Nexus',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFFBFBFF),
        textTheme: textTheme.apply(bodyColor: const Color(0xFF333333)),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: Color(0xFF333333)),
        ),
      ),
      home: const NexusHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// --- 4. PANTALLA DE INICIO ---

class NexusHomePage extends StatelessWidget {
  const NexusHomePage({super.key});

  void _navigateToEditor(BuildContext context, {Note? note}) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NoteEditorPage(note: note)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nexusData = Provider.of<NexusData>(context);
    final filteredNotes = nexusData.filteredNotes;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFFBFBFF),
              const Color(0xFFF4F3FF).withOpacity(0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCustomAppBar(context),
              _buildHeader(context),
              Expanded(
                child: filteredNotes.isEmpty
                    ? _buildEmptyState(
                        context,
                        isSearching: nexusData.searchQuery.isNotEmpty,
                      )
                    : _buildNotesGrid(context, filteredNotes),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildGradientFab(context),
    );
  }

  Widget _buildCustomAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF7B61FF),
            ),
            child: const Center(
              child: Text(
                'N',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Nexus',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          _buildGradientButton(
            onPressed: () {},
            child: const Icon(Icons.menu, color: Colors.white, size: 20),
            padding: const EdgeInsets.all(10),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final nexusData = Provider.of<NexusData>(context, listen: false);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notas Recientes',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: TextField(
              onChanged: (value) => nexusData.updateSearchQuery(value),
              decoration: const InputDecoration(
                icon: Icon(Icons.search, color: Colors.grey),
                hintText: 'Buscar en tu cerebro digital...',
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, {bool isSearching = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Icon(
              isSearching ? Icons.search_off : Icons.add,
              size: 40,
              color: const Color(0xFF7B61FF),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isSearching ? 'No se encontraron notas' : 'Aún no tienes notas',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            isSearching
                ? 'Intenta con otra búsqueda'
                : 'Presiona el botón + para empezar',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesGrid(BuildContext context, List<Note> notes) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        return NoteCard(
          note: note,
          onTap: () => _navigateToEditor(context, note: note),
        );
      },
    );
  }

  Widget _buildGradientButton({
    required VoidCallback onPressed,
    required Widget child,
    EdgeInsets? padding,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding:
            padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [Color(0xFF7B61FF), Color(0xFFC361FF)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7B61FF).withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: child,
      ),
    );
  }

  Widget _buildGradientFab(BuildContext context) {
    return InkWell(
      onTap: () => _navigateToEditor(context),
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF7B61FF), Color(0xFFFD5DA8)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7B61FF).withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }
}

// --- 5. WIDGET DE TARJETA DE NOTA ---

class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;

  const NoteCard({super.key, required this.note, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              note.title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                note.content,
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.fade,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat.yMMMd().format(note.createdAt),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                  onPressed: () {
                    Provider.of<NexusData>(
                      context,
                      listen: false,
                    ).removeNote(note.id);
                  },
                  splashRadius: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
