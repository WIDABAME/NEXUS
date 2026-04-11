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
  late final Map<String, Offset> _notePositions;
  final double _nodeRadius = 45.0;
  final Size _canvasSize = const Size(2000, 2000);
  String? _selectedNodeId;

  @override
  void initState() {
    super.initState();
    _notePositions = _initializePositions(widget.notes);
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
    for (final note in widget.notes) {
      final nodePosition = _notePositions[note.id];
      if (nodePosition != null &&
          (scenePosition - nodePosition).distance <= _nodeRadius) {
        tappedNodeId = note.id;
        break;
      }
    }

    if (tappedNodeId != null) {
      setState(() {
        _selectedNodeId = tappedNodeId;
      });
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
    final nexusData = Provider.of<NexusData>(context, listen: false);
    Navigator.of(parentContext).pop();
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => NoteEditorPage(note: note)))
        .then((_) => nexusData.loadNotes());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Diagnostic: Display the number of notes received by the widget.
        title: Text('Grafo de Notas (${widget.notes.length} notas)'),
        actions: [
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
      body: GestureDetector(
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
    // -- Start Diagnostic Section --
    const textStyle = TextStyle(color: Colors.red, fontSize: 32, fontWeight: FontWeight.bold);
    void drawDebugText(String message, Offset offset) {
      final textSpan = TextSpan(text: message, style: textStyle);
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
      textPainter.layout();
      textPainter.paint(canvas, offset);
    }

    if (notes.isEmpty) {
      drawDebugText('PAINTER DIAGNOSTIC: notes list is empty.', const Offset(50, 100));
      return;
    }

    if (positions.isEmpty) {
      drawDebugText('PAINTER DIAGNOSTIC: positions map is empty.', const Offset(50, 200));
      return;
    }
    // -- End Diagnostic Section --

    final linePaint = Paint()
      ..color = Colors.grey.withOpacity(0.5)
      ..strokeWidth = 1.5;
    final selectedLinePaint = Paint()
      ..color = Colors.deepPurpleAccent
      ..strokeWidth = 2.5;

    final nodePaint = Paint()..color = Colors.deepPurple[300]!;
    final selectedNodePaint = Paint()..color = Colors.amber;

    final Note? selectedNote = (selectedNodeId == null)
        ? null
        : notes.firstWhere((n) => n.id == selectedNodeId);

    final connectedIds = selectedNote?.connections.map((c) => c.noteId).toSet();
    final paintedConnections = <String>{};

    for (final note in notes) {
      final startPos = positions[note.id];
      if (startPos == null) continue;

      for (final conn in note.connections) {
        final connectionKey = [note.id, conn.noteId]..sort();
        final uniqueKey = connectionKey.join('-');
        if (paintedConnections.contains(uniqueKey)) continue;

        final endPos = positions[conn.noteId];
        if (endPos != null) {
          final isSelected = selectedNodeId != null &&
              (note.id == selectedNodeId || conn.noteId == selectedNodeId);
          canvas.drawLine(
              startPos, endPos, isSelected ? selectedLinePaint : linePaint);
          paintedConnections.add(uniqueKey);
        }
      }
    }

    for (final note in notes) {
      final pos = positions[note.id];
      if (pos == null) continue;

      final isSelected = note.id == selectedNodeId;
      final isConnectedToSelected = connectedIds?.contains(note.id) ?? false;

      final Paint currentPaint;
      final double currentRadius;

      if (isSelected) {
        currentPaint = selectedNodePaint;
        currentRadius = nodeRadius * 1.15;
      } else if (selectedNodeId != null && isConnectedToSelected) {
        currentPaint = nodePaint;
        currentRadius = nodeRadius * 1.05;
      } else if (selectedNodeId != null) {
        currentPaint = Paint()..color = Colors.grey[400]!;
        currentRadius = nodeRadius;
      } else {
        currentPaint = nodePaint;
        currentRadius = nodeRadius;
      }

      canvas.drawCircle(pos, currentRadius, currentPaint);

      final textPainter = TextPainter(
        text: TextSpan(
            text: note.title,
            style: TextStyle(
              color: isSelected ? Colors.black87 : Colors.white,
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
