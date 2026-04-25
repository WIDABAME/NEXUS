
import { expect } from 'chai';
import 'mocha';

// Import the functions to be tested
import { extractKeywords, rebuildConnectionsLogic } from '../src/index';

describe('Nexus Backend Logic', () => {

  // Test suite for extractKeywords
  describe('extractKeywords', () => {

    it('should extract meaningful keywords from a title', () => {
      const title = 'Un tutorial sobre desarrollo con Firebase y Flutter';
      const keywords = extractKeywords(title);
      expect(Array.from(keywords)).to.have.members(['tutorial', 'desarrollo', 'firebase', 'flutter']);
    });

    it('should ignore common stop words', () => {
      const title = 'Una nota que es sobre nada en particular';
      const keywords = extractKeywords(title);
      // 'sobre' is now a stop word
      expect(Array.from(keywords)).to.have.members(['nota', 'nada', 'particular']);
    });

    it('should handle punctuation and capitalization', () => {
      const title = '¿¡Pregunta!? Sobre... Flutter, sí, Flutter.';
      const keywords = extractKeywords(title);
      // 'sobre' is now a stop word
      expect(Array.from(keywords)).to.have.members(['pregunta', 'flutter']);
    });

    it('should return an empty set for an empty string', () => {
      const keywords = extractKeywords('');
      expect(keywords.size).to.equal(0);
    });

    it('should ignore words with 2 or less characters and some stop words', () => {
      const title = 'Ir a ver si ya es la hora del té';
      const keywords = extractKeywords(title);
      // 'ver' is now a stop word
      expect(Array.from(keywords)).to.have.members(['hora']);
    });
  });

  // Test suite for rebuildConnectionsLogic
  describe('rebuildConnectionsLogic', () => {

    it('should create connections between notes with common keywords', () => {
      const notes = [
        { id: '1', title: 'Mi primer viaje a Japón' },
        { id: '2', title: 'Consejos para un viaje a Tokio' },
        { id: '3', title: 'Receta de Ramen Japonés' }, // Note a word variation
      ];
      const connections = rebuildConnectionsLogic(notes);

      // Note 1 should connect to Note 2 (via 'viaje') and Note 3 (via 'japon')
      expect(connections['1']).to.have.deep.members([
        { noteId: '2', topic: 'viaje' },
        { noteId: '3', topic: 'japon' }, // Corrected: Expect the normalized topic
      ]);

      // Note 2 should connect to Note 1
      expect(connections['2']).to.have.deep.members([
        { noteId: '1', topic: 'viaje' },
      ]);
      
      // Note 3 should connect to Note 1
      expect(connections['3']).to.have.deep.members([
        { noteId: '1', topic: 'japon' }, // Corrected: Expect the normalized topic
      ]);
    });

    it('should not create connections when there are no common keywords', () => {
      const notes = [
        { id: '1', title: 'Aprendiendo sobre Dart' },
        { id: '2', title: 'La historia de la pizza' },
        { id: '3', title: 'El sistema solar' },
      ];
      const connections = rebuildConnectionsLogic(notes);

      expect(connections['1']).to.be.empty;
      expect(connections['2']).to.be.empty;
      expect(connections['3']).to.be.empty;
    });

    it('should handle multiple common keywords', () => {
      const notes = [
        { id: 'A', title: 'Guía de desarrollo con Flutter y Firebase' },
        { id: 'B', title: 'Tutorial sobre Firebase para el desarrollo de apps' },
      ];
      const connections = rebuildConnectionsLogic(notes);
      
      expect(connections['A']).to.have.lengthOf(1);
      expect(connections['B']).to.have.lengthOf(1);
      expect(connections['A'][0].noteId).to.equal('B');
      expect(connections['B'][0].noteId).to.equal('A');

      // Make the test flexible to the order and spacing of keywords
      const topicsA = connections['A'][0].topic.split(', ').sort();
      const topicsB = connections['B'][0].topic.split(', ').sort();

      expect(topicsA).to.deep.equal(['desarrollo', 'firebase']);
      expect(topicsB).to.deep.equal(['desarrollo', 'firebase']);
    });

    it('should return an empty object for an empty list of notes', () => {
      const connections = rebuildConnectionsLogic([]);
      expect(connections).to.be.an('object').that.is.empty;
    });

  });

});
