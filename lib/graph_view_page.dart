import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'main.dart';
import 'note_editor_page.dart';

class GraphViewPage extends StatefulWidget {
  const GraphViewPage({super.key});

  @override
  State<GraphViewPage> createState() => _GraphViewPageState();
}

class _GraphViewPageState extends State<GraphViewPage> {
  final TransformationController _transformationController = TransformationController();
  Map<String, Offset> _notePositions = {};
  final double _nodeRadius = 45.0;
  final Size _canvasSize = const Size(2000, 2000);
  String? _selectedNodeId;

  @override
  void initState() {
    super.initState();
    final nexusData = Provider.of<NexusData>(context, listen: false);
    if (nexusData.loadingStatus == LoadingStatus.ready) {
      _initializePositions(nexusData.notes);
    }
  }

  void _initializePositions(List<Note> notes) {
    final random = Random();
    final newPositions = <String, Offset>{};
    for (var note in notes) {
      newPositions[note.id] = _notePositions[note.id] ??
          Offset(
            _nodeRadius + random.nextDouble() * (_canvasSize.width - _nodeRadius * 2),
            _nodeRadius + random.nextDouble() * (_canvasSize.height - _nodeRadius * 2),
          );
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _notePositions = newPositions;
        });
      }
    });
  }

  void _handleTap(Offset localPosition) {
    final scenePosition = _transformationController.toScene(localPosition);
    String? tappedNodeId;
    final nexusData = Provider.of<NexusData>(context, listen: false);
    if (nexusData.loadingStatus != LoadingStatus.ready) return;

    for (final note in nexusData.notes) {
      final nodePosition = _notePositions[note.id];
      if (nodePosition != null && (scenePosition - nodePosition).distance <= _nodeRadius) {
        tappedNodeId = note.id;
        break;
      }
    }

    setState(() {
      _selectedNodeId = tappedNodeId;
    });

    if (tappedNodeId != null) {
      final tappedNote = nexusData.notes.firstWhere((n) => n.id == tappedNodeId);
      _showNodeActions(tappedNote);
    }
  }

  void _showNodeActions(Note note) {
    final nexusData = Provider.of<NexusData>(context, listen: false);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final connectedNotes = note.connections.map((conn) {
          try {
            return nexusData.notes.firstWhere((n) => n.id == conn.noteId);
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
        title: const Text('Grafo de Notas'),
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
        child: Consumer<NexusData>(
          builder: (context, nexusData, child) {
            switch (nexusData.loadingStatus) {
              case LoadingStatus.loading:
                return const Center(child: CircularProgressIndicator());
              case LoadingStatus.error:
                return const Center(child: Text('Error al cargar el grafo.'));
              case LoadingStatus.ready:
                if (nexusData.notes.length != _notePositions.length) {
                  _initializePositions(nexusData.notes);
                }
                if (_notePositions.length != nexusData.notes.length) {
                  return const Center(child: CircularProgressIndicator());
                }

                return InteractiveViewer(
                  transformationController: _transformationController,
                  boundaryMargin: const EdgeInsets.all(double.infinity),
                  minScale: 0.1,
                  maxScale: 2.5,
                  child: CustomPaint(
                    size: _canvasSize,
                    painter: GraphPainter(
                      notes: nexusData.notes,
                      positions: _notePositions,
                      nodeRadius: _nodeRadius,
                      selectedNodeId: _selectedNodeId,
                    ),
                  ),
                );
            }
          },
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
    if (positions.isEmpty) return;

    final linePaint = Paint()
      ..color = Colors.grey.withOpacity(0.4)
      ..strokeWidth = 1;
    final selectedLinePaint = Paint()
      ..color = Colors.deepPurpleAccent
      ..strokeWidth = 2.5;

    final nodePaint = Paint()..color = Colors.deepPurple[300]!;
    final selectedNodePaint = Paint()..color = Colors.amber;

    final Note? selectedNote =
        selectedNodeId == null ? null : notes.firstWhere((n) => n.id == selectedNodeId);

    final connectedIds = selectedNote?.connections.map((c) => c.noteId).toSet();

    for (final note in notes) {
      final startPos = positions[note.id];
      if (startPos == null) continue;

      for (final conn in note.connections) {
        if (note.id.compareTo(conn.noteId) < 0) {
          final endPos = positions[conn.noteId];
          if (endPos != null) {
            final isSelected = selectedNodeId != null &&
                (note.id == selectedNodeId || conn.noteId == selectedNodeId);
            canvas.drawLine(startPos, endPos,
                isSelected ? selectedLinePaint : linePaint);
          }
        }
      }
    }

    for (final note in notes) {
      final pos = positions[note.id];
      if (pos == null) continue;

      final isSelected = note.id == selectedNodeId;
      final isConnectedToSelected = connectedIds?.contains(note.id) ?? false;

      final Paint currentPaint;
      double currentRadius = nodeRadius;

      if (isSelected) {
        currentPaint = selectedNodePaint;
        currentRadius = nodeRadius * 1.1;
      } else if (selectedNodeId != null && isConnectedToSelected) {
        currentPaint = nodePaint;
      } else if (selectedNodeId != null) {
        currentPaint = Paint()..color = Colors.grey[350]!;
      } else {
        currentPaint = nodePaint;
      }

      canvas.drawCircle(pos, currentRadius, currentPaint);

      final textPainter = TextPainter(
        text: TextSpan(
            text: note.title,
            style: TextStyle(
              color: isSelected ? Colors.black : Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            )),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: nodeRadius * 2 - 10);

      textPainter.paint(
          canvas, pos - Offset(textPainter.width / 2, textPainter.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
