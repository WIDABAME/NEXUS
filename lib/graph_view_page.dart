
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'main.dart';
import 'note_editor_page.dart';

class GraphViewPage extends StatefulWidget {
  final List<Note> notes;

  const GraphViewPage({super.key, required this.notes});

  @override
  State<GraphViewPage> createState() => _GraphViewPageState();
}

class _GraphViewPageState extends State<GraphViewPage> {
  final TransformationController _transformationController = TransformationController();
  late Map<String, Offset> _notePositions = {};
  final double _nodeRadius = 45.0;
  final Size _canvasSize = const Size(2000, 2000);
  String? _selectedNodeId;

  @override
  void initState() {
    super.initState();
    // Las posiciones se inicializan aquí y solo una vez.
    if (widget.notes.isNotEmpty) {
      _notePositions = _initializePositions(widget.notes);
    }
  }

  Map<String, Offset> _initializePositions(List<Note> notes) {
    final random = Random();
    final positions = <String, Offset>{};
    for (var note in notes) {
      positions[note.id] = Offset(
        _nodeRadius + random.nextDouble() * (_canvasSize.width - _nodeRadius * 2),
        _nodeRadius + random.nextDouble() * (_canvasSize.height - _nodeRadius * 2),
      );
    }
    return positions;
  }

  void _handleTap(Offset localPosition) {
    final scenePosition = _transformationController.toScene(localPosition);
    String? tappedNodeId;

    // Invertimos el bucle para dar prioridad a los nodos dibujados encima
    for (final note in widget.notes.reversed) {
      final nodePosition = _notePositions[note.id];
      if (nodePosition != null &&
          (scenePosition - nodePosition).distance <= _nodeRadius) {
        tappedNodeId = note.id;
        break;
      }
    }

    setState(() {
      if (tappedNodeId == _selectedNodeId) {
        _selectedNodeId = null;
      } else {
        _selectedNodeId = tappedNodeId;
      }
    });

    if (tappedNodeId != null) {
      final tappedNote = widget.notes.firstWhere((n) => n.id == tappedNodeId);
      _showNodeActions(tappedNote);
    }
  }

  void _showNodeActions(Note note) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final connectedNotes = note.connections.map((conn) {
          try {
            return widget.notes.firstWhere((n) => n.id == conn.noteId);
          } catch (_) {
            return null;
          }
        }).where((n) => n != null).toList();

        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(note.title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              Text('Conectado con:', style: Theme.of(context).textTheme.titleMedium),
              const Divider(),
              if (connectedNotes.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: Center(child: Text('Sin conexiones.')),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: connectedNotes.length,
                    itemBuilder: (_, index) {
                      final connectedNote = connectedNotes[index]!;
                      return ListTile(
                        title: Text(connectedNote.title),
                        onTap: () => _navigateToNote(context, connectedNote),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  child: const Text('Abrir Nota'),
                  onPressed: () => _navigateToNote(context, note),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

    void _navigateToNote(BuildContext parentContext, Note note) {
      Navigator.of(parentContext).pop();
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => NoteEditorPage(note: note)),
      );
    }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Grafo de Notas (${widget.notes.length} notas)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Botón para forzar la reinicialización de las posiciones
              setState(() {
                _notePositions = _initializePositions(widget.notes);
                _selectedNodeId = null;
              });
            },
            tooltip: 'Reorganizar Grafo',
          ),
          IconButton(
            icon: const Icon(Icons.center_focus_strong),
            onPressed: () {
              _transformationController.value = Matrix4.identity();
              setState(() {
                _selectedNodeId = null;
              });
            },
          ),
        ],
      ),
      body: widget.notes.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_graph, size: 60, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No hay notas para mostrar en el grafo.', style: TextStyle(fontSize: 16)),
                ],
              ),
            )
          : GestureDetector(
        onTapUp: (details) => _handleTap(details.localPosition),
        child: InteractiveViewer(
          transformationController: _transformationController,
          boundaryMargin: const EdgeInsets.all(double.infinity),
          minScale: 0.1,
          maxScale: 2.5,
          child: CustomPaint(
            size: _canvasSize,
            painter: GraphPainter(
              notes: widget.notes,
              positions: _notePositions,
              nodeRadius: _nodeRadius,
              selectedNodeId: _selectedNodeId,
            ),
          ),
        ),
      ),
    );
  }
}

class GraphPainter extends CustomPainter {
  final List<Note> notes;
  final Map<String, Offset> positions;
  final double nodeRadius;
  final String? selectedNodeId;

  GraphPainter({
    required this.notes,
    required this.positions,
    required this.nodeRadius,
    this.selectedNodeId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Si no hay posiciones, no hay nada que dibujar.
    if (positions.isEmpty) return;

    final linePaint = Paint()
      ..color = Colors.grey.withOpacity(0.6)
      ..strokeWidth = 2.0;
    final selectedLinePaint = Paint()
      ..color = Colors.deepPurpleAccent
      ..strokeWidth = 3.0;

    final nodePaint = Paint()..color = Colors.deepPurple[300]!;
    final selectedNodePaint = Paint()..color = Colors.amber;
    
    final Note? selectedNote = (selectedNodeId == null)
      ? null
      : notes.firstWhere((n) => n.id == selectedNodeId, orElse: () => notes.first);

    final connectedToSelectedIds = selectedNote?.connections.map((c) => c.noteId).toSet();
    final paintedConnections = <String>{};

    // -- DIBUJAR LÍNEAS --
    for (final note in notes) {
      final startPos = positions[note.id];
      if (startPos == null) continue;

      for (final conn in note.connections) {
        final endPos = positions[conn.noteId];
        if (endPos == null) continue;
        
        final connectionKey = [note.id, conn.noteId]..sort();
        final uniqueKey = connectionKey.join('-');
        if (paintedConnections.contains(uniqueKey)) continue;

        final bool isConnectionOfSelectedNode = selectedNodeId != null && 
            (note.id == selectedNodeId || conn.noteId == selectedNodeId);

        canvas.drawLine(
          startPos,
          endPos,
          isConnectionOfSelectedNode ? selectedLinePaint : linePaint,
        );
        paintedConnections.add(uniqueKey);
      }
    }

    // -- DIBUJAR NODOS Y TEXTO --
    for (final note in notes) {
      final pos = positions[note.id];
      if (pos == null) continue;

      final bool isSelected = note.id == selectedNodeId;
      final bool isConnectedToSelected = connectedToSelectedIds?.contains(note.id) ?? false;

      final Paint currentPaint;
      final double currentRadius;
      final Color textColor;

      if (isSelected) {
        currentPaint = selectedNodePaint;
        currentRadius = nodeRadius * 1.15;
        textColor = Colors.black87;
      } else if (selectedNodeId != null && isConnectedToSelected) {
        currentPaint = nodePaint;
        currentRadius = nodeRadius * 1.05;
        textColor = Colors.white;
      } else if (selectedNodeId != null) {
        currentPaint = Paint()..color = Colors.grey[400]!.withAlpha(150);
        currentRadius = nodeRadius;
        textColor = Colors.white70;
      } else {
        currentPaint = nodePaint;
        currentRadius = nodeRadius;
        textColor = Colors.white;
      }

      canvas.drawCircle(pos, currentRadius, currentPaint);

      final textPainter = TextPainter(
        text: TextSpan(
            text: note.title,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            )),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: nodeRadius * 2 - 16);

      textPainter.paint(
          canvas, pos - Offset(textPainter.width / 2, textPainter.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant GraphPainter oldDelegate) {
    return oldDelegate.notes != notes || 
           oldDelegate.positions != positions || 
           oldDelegate.selectedNodeId != selectedNodeId;
  }
}
