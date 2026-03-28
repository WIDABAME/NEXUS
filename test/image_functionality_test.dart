import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mockito/mockito.dart';
import 'package:myapp/main.dart';
import 'package:myapp/note_editor_page.dart';
import 'package:provider/provider.dart';

// Mock de ImagePicker para evitar el acceso al sistema de archivos en las pruebas
class MockImagePicker extends Mock implements ImagePicker {}

void main() {
  group('Note Model', () {
    test('Prueba de serialización y deserialización JSON con imagePath', () {
      final now = DateTime.now();
      final note = Note(
        id: '1',
        title: 'Test Title',
        content: 'Test Content',
        createdAt: now,
        imagePath: '/path/to/image.jpg',
      );

      final json = note.toJson();
      final noteFromJson = Note.fromJson(json);

      expect(noteFromJson.id, note.id);
      expect(noteFromJson.title, note.title);
      expect(noteFromJson.content, note.content);
      expect(noteFromJson.createdAt, note.createdAt);
      expect(noteFromJson.imagePath, note.imagePath);
    });

    test('Prueba de serialización y deserialización JSON sin imagePath', () {
      final now = DateTime.now();
      final note = Note(
        id: '2',
        title: 'Test Title 2',
        content: 'Test Content 2',
        createdAt: now,
      );

      final json = note.toJson();
      final noteFromJson = Note.fromJson(json);

      expect(noteFromJson.imagePath, isNull);
    });
  });

  group('NoteEditorPage', () {
    testWidgets('El botón de imagen está presente', (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => NexusData(),
          child: MaterialApp(
            home: NoteEditorPage(),
          ),
        ),
      );

      expect(find.byIcon(Icons.image), findsOneWidget);
    });
  });

  group('NoteCard', () {
    testWidgets('Muestra un widget de imagen si imagePath no es nulo', (WidgetTester tester) async {
      final note = Note(
        id: '1',
        title: 'Test',
        content: 'Test',
        createdAt: DateTime.now(),
        imagePath: '/fake/path/to/image.jpg',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteCard(note: note, onTap: () {}),
          ),
        ),
      );

      // El Image.file crea un widget Image, por lo que simplemente verificamos su presencia.
      // El framework de prueba de Flutter maneja el error de archivo no encontrado silenciosamente
      // para no bloquear la prueba, por lo que no necesitamos capturar excepciones.
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('No muestra la imagen si imagePath es nulo', (WidgetTester tester) async {
      final note = Note(
        id: '1',
        title: 'Test',
        content: 'Test',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteCard(note: note, onTap: () {}),
          ),
        ),
      );

      expect(find.byType(Image), findsNothing);
    });
  });
}
