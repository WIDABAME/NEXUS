
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'main.dart'; // Importa main.dart para acceder a Note y NexusData

const Uuid uuid = Uuid();

class NoteEditorPage extends StatefulWidget {
  final Note? note; // Nota existente para editar, o null si es nueva

  const NoteEditorPage({super.key, this.note});

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? 'Nueva Nota');
    _contentController = TextEditingController(text: widget.note?.content ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _saveNote() {
    final nexusData = Provider.of<NexusData>(context, listen: false);
    final title = _titleController.text;
    final content = _contentController.text;

    if (title.isEmpty && content.isEmpty) {
      // No guardar notas vacías
      if(widget.note != null){
        nexusData.removeNote(widget.note!.id);
      }
      return;
    }

    if (widget.note != null) {
      // Actualizar nota existente
      final updatedNote = Note(
        id: widget.note!.id,
        title: title,
        content: content,
        createdAt: widget.note!.createdAt,
      );
      nexusData.updateNote(updatedNote);
    } else {
      // Crear nueva nota
      final newNote = Note(
        id: uuid.v4(),
        title: title,
        content: content,
        createdAt: DateTime.now(),
      );
      nexusData.addNote(newNote);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _saveNote();
        return true;
      },
      child: Scaffold(
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
              children: [
                _buildCustomAppBar(context),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: ListView(
                      children: [
                        TextField(
                          controller: _titleController,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Título',
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _contentController,
                           autofocus: widget.note == null, // Autofocus si es una nota nueva
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
                          maxLines: null, // Permite múltiples líneas
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Empieza a escribir...',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _buildCustomAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          // Botón de Volver
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(12),
            child: Container(
               padding: const EdgeInsets.all(10),
               decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.8),
               ),
               child: const Icon(Icons.arrow_back, color: Color(0xFF333333)),
            ),
          ),
          const Spacer(),
           // Botones de acción
          _buildGradientIconButton(icon: Icons.graphic_eq, onPressed: () {}),
          const SizedBox(width: 8),
          _buildGradientIconButton(icon: Icons.share_outlined, onPressed: () {}),
          const SizedBox(width: 8),
          _buildGradientIconButton(icon: Icons.more_horiz, onPressed: () {}, isLast: true),
        ],
      ),
    );
  }

  Widget _buildGradientIconButton({required IconData icon, required VoidCallback onPressed, bool isLast = false}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: isLast ? [const Color(0xFFFD5DA8), const Color(0xFFC361FF)] : [const Color(0xFF7B61FF), const Color(0xFFC361FF)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B61FF).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ]
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white, size: 20),
        tooltip: 'Acción',
      ),
    );
  }
