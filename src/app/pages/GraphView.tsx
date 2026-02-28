import { useState, useEffect, useCallback } from "react";
import { useParams, useNavigate } from "react-router";
import { ArrowLeft } from "lucide-react";
import ForceGraph2D from "react-force-graph-2d";
import { getNote, getNotes } from "../lib/api";
import type { Note } from "../lib/api";
import { toast } from "sonner";

interface GraphNode {
  id: string;
  name: string;
  val: number;
  color: string;
}

interface GraphLink {
  source: string;
  target: string;
}

interface GraphData {
  nodes: GraphNode[];
  links: GraphLink[];
}

export function GraphView() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const [currentNote, setCurrentNote] = useState<Note | null>(null);
  const [graphData, setGraphData] = useState<GraphData>({ nodes: [], links: [] });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (id) {
      loadGraphData(id);
    }
  }, [id]);

  async function loadGraphData(noteId: string) {
    try {
      const [note, allNotes] = await Promise.all([
        getNote(noteId),
        getNotes(),
      ]);

      setCurrentNote(note);
      
      // Crear mapa de notas por título normalizado
      const notesByTitle = new Map<string, Note>();
      allNotes.forEach(n => {
        const normalizedTitle = n.title.toLowerCase().trim();
        notesByTitle.set(normalizedTitle, n);
        notesByTitle.set(n.id, n);
      });

      // Construir grafo
      const nodes: GraphNode[] = [];
      const links: GraphLink[] = [];
      const processedIds = new Set<string>();

      // Nodo central (nota actual)
      nodes.push({
        id: note.id,
        name: note.title || "Sin título",
        val: 20, // Tamaño más grande
        color: "#8b5cf6", // Púrpura vibrante
      });
      processedIds.add(note.id);

      // Procesar enlaces de la nota actual
      note.links.forEach(linkTitle => {
        const normalizedLink = linkTitle.toLowerCase().trim();
        const linkedNote = notesByTitle.get(normalizedLink);
        
        if (linkedNote && !processedIds.has(linkedNote.id)) {
          nodes.push({
            id: linkedNote.id,
            name: linkedNote.title || "Sin título",
            val: 10,
            color: "#3b82f6", // Azul
          });
          processedIds.add(linkedNote.id);
        }
        
        if (linkedNote) {
          links.push({
            source: note.id,
            target: linkedNote.id,
          });
        }
      });

      // Procesar notas que enlazan a la actual
      allNotes.forEach(n => {
        if (n.id === note.id || processedIds.has(n.id)) return;
        
        const hasBacklink = n.links.some(link => {
          const normalizedLink = link.toLowerCase().trim();
          const normalizedCurrentTitle = note.title.toLowerCase().trim();
          return normalizedLink === normalizedCurrentTitle || normalizedLink === note.id;
        });

        if (hasBacklink) {
          nodes.push({
            id: n.id,
            name: n.title || "Sin título",
            val: 10,
            color: "#ec4899", // Rosa
          });
          links.push({
            source: n.id,
            target: note.id,
          });
          processedIds.add(n.id);
        }
      });

      // Agregar notas con tags compartidos
      if (note.tags.length > 0) {
        allNotes.forEach(n => {
          if (n.id === note.id || processedIds.has(n.id)) return;
          
          const sharedTags = n.tags.filter(tag => note.tags.includes(tag));
          if (sharedTags.length > 0) {
            nodes.push({
              id: n.id,
              name: n.title || "Sin título",
              val: 8,
              color: "#10b981", // Verde
            });
            links.push({
              source: note.id,
              target: n.id,
            });
            processedIds.add(n.id);
          }
        });
      }

      setGraphData({ nodes, links });
    } catch (error) {
      console.error("Error loading graph data:", error);
      toast.error("Error al cargar el grafo");
      navigate("/");
    } finally {
      setLoading(false);
    }
  }

  const handleNodeClick = useCallback((node: GraphNode) => {
    navigate(`/note/${node.id}`);
  }, [navigate]);

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-indigo-50 via-purple-50 to-pink-50 flex items-center justify-center">
        <div className="flex flex-col items-center gap-4">
          <div className="w-16 h-16 border-4 border-purple-200 border-t-purple-600 rounded-full animate-spin"></div>
          <div className="text-gray-600 font-medium">Cargando grafo...</div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-indigo-50 via-purple-50 to-pink-50 flex flex-col">
      {/* Header */}
      <div className="bg-white/80 backdrop-blur-md border-b border-purple-100 px-4 py-4 flex items-center justify-between shadow-sm">
        <button
          onClick={() => navigate(`/note/${id}`)}
          className="w-10 h-10 bg-gradient-to-br from-indigo-500 to-purple-500 hover:from-indigo-600 hover:to-purple-600 text-white rounded-xl flex items-center justify-center transition-all hover:scale-105 shadow-md"
        >
          <ArrowLeft size={20} />
        </button>
        
        <h1 className="text-xl font-bold bg-gradient-to-r from-indigo-600 to-purple-600 bg-clip-text text-transparent">
          {currentNote?.title || "Sin título"}
        </h1>
        
        <button
          onClick={() => navigate("/")}
          className="px-4 py-2 bg-gradient-to-br from-pink-500 to-purple-500 hover:from-pink-600 hover:to-purple-600 text-white rounded-xl transition-all hover:scale-105 shadow-md font-medium text-sm"
        >
          Inicio
        </button>
      </div>

      {/* Grafo */}
      <div className="flex-1 relative bg-white/40 backdrop-blur-sm m-4 rounded-3xl border-2 border-purple-100 shadow-lg overflow-hidden">
        <ForceGraph2D
          graphData={graphData}
          nodeLabel="name"
          nodeVal="val"
          nodeColor="color"
          nodeCanvasObject={(node: any, ctx, globalScale) => {
            const label = node.name;
            const fontSize = 14 / globalScale;
            ctx.font = `bold ${fontSize}px Sans-Serif`;
            
            // Dibujar nodo con sombra
            ctx.shadowColor = 'rgba(0,0,0,0.2)';
            ctx.shadowBlur = 10;
            ctx.shadowOffsetX = 2;
            ctx.shadowOffsetY = 2;
            
            ctx.beginPath();
            ctx.arc(node.x, node.y, node.val || 5, 0, 2 * Math.PI, false);
            ctx.fillStyle = node.color || '#94a3b8';
            ctx.fill();
            
            // Borde blanco
            ctx.shadowColor = 'transparent';
            ctx.strokeStyle = '#ffffff';
            ctx.lineWidth = 2;
            ctx.stroke();
            
            // Dibujar label con fondo
            ctx.textAlign = 'center';
            ctx.textBaseline = 'middle';
            const textY = node.y + (node.val || 5) + fontSize + 4;
            
            // Fondo del texto
            const textWidth = ctx.measureText(label).width;
            ctx.fillStyle = 'rgba(255,255,255,0.9)';
            ctx.fillRect(node.x - textWidth/2 - 4, textY - fontSize/2 - 2, textWidth + 8, fontSize + 4);
            
            // Texto
            ctx.fillStyle = '#1f2937';
            ctx.fillText(label, node.x, textY);
          }}
          linkColor={() => '#a78bfa'}
          linkWidth={3}
          onNodeClick={handleNodeClick}
          cooldownTicks={100}
          d3AlphaDecay={0.02}
          d3VelocityDecay={0.3}
        />
        
        {/* Leyenda */}
        <div className="absolute bottom-6 left-6 bg-white/90 backdrop-blur-md rounded-2xl p-4 shadow-xl border-2 border-purple-200">
          <p className="font-semibold text-gray-800 mb-3">Leyenda del Grafo</p>
          <div className="space-y-2 text-sm">
            <div className="flex items-center gap-3">
              <div className="w-5 h-5 rounded-full bg-purple-500"></div>
              <span className="text-gray-700">Nota actual</span>
            </div>
            <div className="flex items-center gap-3">
              <div className="w-4 h-4 rounded-full bg-blue-500"></div>
              <span className="text-gray-700">Enlaces directos</span>
            </div>
            <div className="flex items-center gap-3">
              <div className="w-4 h-4 rounded-full bg-pink-500"></div>
              <span className="text-gray-700">Backlinks</span>
            </div>
            <div className="flex items-center gap-3">
              <div className="w-3 h-3 rounded-full bg-green-500"></div>
              <span className="text-gray-700">Tags compartidos</span>
            </div>
          </div>
          <p className="mt-4 text-xs text-gray-500">💡 Toca un nodo para navegar</p>
        </div>
        
        {graphData.nodes.length === 1 && (
          <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 text-center">
            <div className="bg-white/90 backdrop-blur-md rounded-3xl p-12 shadow-xl border-2 border-purple-200">
              <div className="w-20 h-20 bg-gradient-to-br from-purple-100 to-pink-100 rounded-full flex items-center justify-center mx-auto mb-4">
                <span className="text-4xl">🌐</span>
              </div>
              <p className="text-gray-700 font-medium mb-2 text-lg">Esta nota aún no tiene conexiones</p>
              <p className="text-gray-500 text-sm">Usa enlaces [[nota]] y #tags para conectar ideas</p>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}