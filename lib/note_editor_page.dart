import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'main.dart';

const Uuid uuid = Uuid();

class NoteEditorPage extends StatefulWidget {
  final Note? note;

  const NoteEditorPage({super.key, this.note});

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  String? _imagePath; // Can be a local path or a network URL
  bool _isNewNote = true;
  bool _isUploading = false;
  String? _initialImagePath; // To track if the image was changed

  @override
  void initState() {
    super.initState();
    _isNewNote = widget.note == null;
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(text: widget.note?.content ?? '');
    _imagePath = widget.note?.imagePath;
    _initialImagePath = widget.note?.imagePath;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imagePath = pickedFile.path;
      });
    }
  }

  Future<String?> _uploadImage(String filePath) async {
    final fileName = 'note_images/${uuid.v4()}';
    final reference = FirebaseStorage.instance.ref().child(fileName);
    try {
      final uploadTask = reference.putFile(File(filePath));
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al subir la imagen: ${e.toString()}')),
      );
      return null;
    }
  }
  
  Future<void> _deleteImage(String imageUrl) async {
    if (imageUrl.contains('firebasestorage')) {
        try {
            final ref = FirebaseStorage.instance.refFromURL(imageUrl);
            await ref.delete();
        } catch (e) {
            print("Failed to delete image from storage: $e");
        }
    }
}


  Future<void> _saveNote() async {
    if (_isUploading) return; // Prevent saving while uploading

    final nexusData = Provider.of<NexusData>(context, listen: false);
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El título no puede estar vacío.')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    String? finalImageUrl = _imagePath;

    // Check if the image has changed
    bool imageChanged = _initialImagePath != _imagePath;

    if (imageChanged) {
        // If there was an old image, delete it
        if (_initialImagePath != null) {
            await _deleteImage(_initialImagePath!);
        }

        // If there is a new image (and it's a local file), upload it
        if (_imagePath != null && !_imagePath!.startsWith('http')) {
            finalImageUrl = await _uploadImage(_imagePath!);
        }
    }


    final noteData = {
      'title': title,
      'content': content,
      'imagePath': finalImageUrl,
    };

    if (_isNewNote) {
      final newNote = Note(
        id: uuid.v4(),
        title: title,
        content: content,
        createdAt: Timestamp.now(),
        imagePath: finalImageUrl,
      );
      await nexusData.addNote(newNote);
    } else {
       final updatedNote = Note(
        id: widget.note!.id,
        title: title,
        content: content,
        createdAt: widget.note!.createdAt, 
        imagePath: finalImageUrl,
        connections: widget.note!.connections,
      );
      await nexusData.updateNote(updatedNote);
    }

    setState(() {
      _isUploading = false;
    });
    
    if (mounted) {
        Navigator.of(context).pop();
    }
  }

  Widget _buildImagePreview() {
    if (_imagePath == null) {
      return const SizedBox.shrink();
    }

    Widget imageWidget;
    if (_imagePath!.startsWith('http')) {
      imageWidget = Image.network(key: ValueKey(_imagePath), _imagePath!, fit: BoxFit.cover, width: double.infinity, height: 200);
    } else {
      imageWidget = Image.file(key: ValueKey(_imagePath), File(_imagePath!), fit: BoxFit.cover, width: double.infinity, height: 200);
    }

    return Stack(
      alignment: Alignment.topRight,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12.0),
          child: imageWidget,
        ),
        Positioned(
          right: 4,
          top: 4,
          child: Material(
             color: Colors.black54,
             borderRadius: BorderRadius.circular(30),
             child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 20),
              onPressed: () => setState(() => _imagePath = null),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showNoteSelectionDialog(BuildContext context) async {
    final nexusData = Provider.of<NexusData>(context, listen: false);
    final currentNoteId = widget.note?.id;

    // Filter out the current note and already connected notes
    final connectedNoteIds = widget.note?.connections.map((c) => c.noteId).toSet() ?? {};
    final List<Note> availableNotes = nexusData.notes
        .where((n) => n.id != currentNoteId && !connectedNoteIds.contains(n.id))
        .toList();

    if (availableNotes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay otras notas disponibles para conectar.')),
      );
      return;
    }

    final Note? selectedNote = await showDialog<Note>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Conectar con...'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              itemCount: availableNotes.length,
              itemBuilder: (context, index) {
                final note = availableNotes[index];
                return ListTile(
                  title: Text(note.title),
                  onTap: () {
                    Navigator.of(context).pop(note);
                  },
                );
              },
            ),
          ),
        );
      },
    );

    if (selectedNote != null && widget.note != null) {
      await nexusData.addManualConnection(widget.note!, selectedNote);
      // The NexusData provider will notify listeners, and the UI will update.
    }
  }

  Widget _buildConnectionsSection(BuildContext context) {
    // Use Consumer to get the latest data and rebuild when it changes
    return Consumer<NexusData>(builder: (context, nexusData, child) {
      // Find the latest version of the note from the provider
      final currentNote = nexusData.notes.firstWhere((n) => n.id == widget.note?.id, orElse: () => widget.note!); 
      final connections = currentNote?.connections ?? [];

      Note? findNoteById(String id) {
        try {
          return nexusData.notes.firstWhere((note) => note.id == id);
        } catch (e) {
          return null;
        }
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Conexiones',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (!_isNewNote)
                IconButton(
                  icon: const Icon(Icons.add_link),
                  onPressed: () => _showNoteSelectionDialog(context),
                ),
            ],
          ),
          if (connections.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text('No hay conexiones aún.', style: TextStyle(color: Colors.grey)),
            )
          else
            const SizedBox(height: 8),
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: connections.map((connection) {
              final connectedNote = findNoteById(connection.noteId);
              if (connectedNote == null) {
                return const SizedBox.shrink();
              }
              return ActionChip(
                avatar: Icon(connection.topic == 'manual' ? Icons.handyman : Icons.auto_awesome, size: 16),
                label: Text(connectedNote.title),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NoteEditorPage(note: connectedNote),
                    ),
                  );
                },
              );
            }).toList(),
          ),
        ],
      );
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNewNote ? 'Nueva Nota' : 'Editar Nota'),
        actions: [
          if (_isUploading)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white,))))
          else
            IconButton(icon: const Icon(Icons.save), onPressed: _saveNote),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16,16,16,80),
        child: Column(
          children: [
            _buildImagePreview(),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Título', border: OutlineInputBorder()),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(labelText: 'Contenido', alignLabelWithHint: true, border: OutlineInputBorder()),
              minLines: 10,
              maxLines: null, // Allows the text field to grow
            ),
           if (!_isNewNote) _buildConnectionsSection(context),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickImage,
        label: const Text('Añadir Imagen'),
        icon: const Icon(Icons.add_photo_alternate),
      ),
    );
  }
}
