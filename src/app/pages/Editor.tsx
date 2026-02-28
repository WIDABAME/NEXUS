import { useState, useEffect, useRef } from "react";
import { useParams, useNavigate } from "react-router";
import { ArrowLeft, Share2, MoreVertical, Hash, Link2, List, Bold, Eye, Network } from "lucide-react";
import { getNote, updateNote, deleteNote } from "../lib/api";
import { extractTags, extractLinks } from "../lib/markdown-parser";
import type { Note } from "../lib/api";
import { toast } from "sonner";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "../components/ui/dropdown-menu";

export function Editor() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const [note, setNote] = useState<Note | null>(null);
  const [title, setTitle] = useState("");
  const [content, setContent] = useState("");
  const [isPreview, setIsPreview] = useState(false);
  const [loading, setLoading] = useState(true);
  const contentRef = useRef<HTMLTextAreaElement>(null);
  const saveTimeoutRef = useRef<NodeJS.Timeout>();

  useEffect(() => {
    if (id) {
      loadNote(id);
    }
  }, [id]);

  useEffect(() => {
    // Auto-guardar después de 1 segundo de inactividad
    if (note && (title !== note.title || content !== note.content)) {
      if (saveTimeoutRef.current) {
        clearTimeout(saveTimeoutRef.current);
      }
      saveTimeoutRef.current = setTimeout(() => {
        handleSave();
      }, 1000);
    }

    return () => {
      if (saveTimeoutRef.current) {
        clearTimeout(saveTimeoutRef.current);
      }
    };
  }, [title, content]);

  async function loadNote(noteId: string) {
    try {
      const data = await getNote(noteId);
      setNote(data);
      setTitle(data.title);
      setContent(data.content);
    } catch (error) {
      console.error("Error loading note:", error);
      toast.error("Error al cargar la nota");
      navigate("/");
    } finally {
      setLoading(false);
    }
  }

  async function handleSave() {
    if (!id) return;

    try {
      const tags = extractTags(content);
      const links = extractLinks(content);
      
      const updatedNote = await updateNote(id, {
        title,
        content,
        tags,
        links,
        updatedAt: new Date().toISOString(),
      });
      
      setNote(updatedNote);
      toast.success("Guardado");
    } catch (error) {
      console.error("Error saving note:", error);
      toast.error("Error al guardar");
    }
  }

  async function handleDelete() {
    if (!id || !confirm("¿Estás seguro de eliminar esta nota?")) return;

    try {
      await deleteNote(id);
      toast.success("Nota eliminada");
      navigate("/");
    } catch (error) {
      console.error("Error deleting note:", error);
      toast.error("Error al eliminar");
    }
  }

  function handleShare() {
    if (navigator.share) {
      navigator.share({
        title: title,
        text: content,
      }).catch(() => {});
    } else {
      navigator.clipboard.writeText(content);
      toast.success("Contenido copiado al portapapeles");
    }
  }

  function insertMarkdown(before: string, after: string = "") {
    const textarea = contentRef.current;
    if (!textarea) return;

    const start = textarea.selectionStart;
    const end = textarea.selectionEnd;
    const selectedText = content.substring(start, end);
    const newText = content.substring(0, start) + before + selectedText + after + content.substring(end);
    
    setContent(newText);
    
    // Restaurar foco y selección
    setTimeout(() => {
      textarea.focus();
      const newPosition = start + before.length + selectedText.length;
      textarea.setSelectionRange(newPosition, newPosition);
    }, 0);
  }

  function handleLinkClick(e: React.MouseEvent) {
    const target = e.target as HTMLElement;
    const linkTitle = target.getAttribute('data-link');
    if (linkTitle) {
      // Aquí podrías buscar la nota por título y navegar a ella
      toast.info(`Navegando a: ${linkTitle}`);
    }
  }

  function renderPreview() {
    let html = content;
    
    // Tags
    html = html.replace(
      /#([a-zA-ZáéíóúñÁÉÍÓÚÑ0-9_-]+)/g,
      '<span class="text-blue-600 font-medium">#$1</span>'
    );
    
    // Enlaces bidireccionales
    html = html.replace(
      /\[\[([^\]]+)\]\]/g,
      '<span class="text-purple-600 font-medium underline cursor-pointer" data-link="$1">[[$1]]</span>'
    );
    
    // Negritas
    html = html.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
    
    // Cursivas
    html = html.replace(/\*([^*]+)\*/g, '<em>$1</em>');
    
    // Listas
    html = html.replace(/^- (.+)$/gm, '<li class="ml-4">$1</li>');
    
    // Saltos de línea
    html = html.replace(/\n/g, '<br/>');
    
    return html;
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-indigo-50 via-purple-50 to-pink-50 flex items-center justify-center">
        <div className="flex flex-col items-center gap-4">
          <div className="w-16 h-16 border-4 border-purple-200 border-t-purple-600 rounded-full animate-spin"></div>
          <div className="text-gray-600 font-medium">Cargando...</div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-indigo-50 via-purple-50 to-pink-50 flex flex-col">
      {/* Header */}
      <div className="bg-white/80 backdrop-blur-md border-b border-purple-100 px-4 py-4 flex items-center justify-between shadow-sm">
        <button
          onClick={() => navigate("/")}
          className="w-10 h-10 bg-gradient-to-br from-indigo-500 to-purple-500 hover:from-indigo-600 hover:to-purple-600 text-white rounded-xl flex items-center justify-center transition-all hover:scale-105 shadow-md"
        >
          <ArrowLeft size={20} />
        </button>
        
        <input
          type="text"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          placeholder="Título de la nota"
          className="flex-1 mx-4 text-xl font-bold text-center focus:outline-none bg-transparent text-gray-900 placeholder:text-gray-400"
        />
        
        <div className="flex items-center gap-2">
          <button
            onClick={() => navigate(`/graph/${id}`)}
            className="w-10 h-10 bg-gradient-to-br from-green-500 to-emerald-500 hover:from-green-600 hover:to-emerald-600 text-white rounded-xl flex items-center justify-center transition-all hover:scale-105 shadow-md"
            title="Ver grafo"
          >
            <Network size={20} />
          </button>
          
          <button
            onClick={handleShare}
            className="w-10 h-10 bg-gradient-to-br from-blue-500 to-cyan-500 hover:from-blue-600 hover:to-cyan-600 text-white rounded-xl flex items-center justify-center transition-all hover:scale-105 shadow-md"
          >
            <Share2 size={20} />
          </button>
          
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <button className="w-10 h-10 bg-gradient-to-br from-pink-500 to-rose-500 hover:from-pink-600 hover:to-rose-600 text-white rounded-xl flex items-center justify-center transition-all hover:scale-105 shadow-md">
                <MoreVertical size={20} />
              </button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              <DropdownMenuItem onClick={handleDelete} className="text-red-600">
                Eliminar nota
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
      </div>

      {/* Área de contenido */}
      <div className="flex-1 overflow-auto">
        {isPreview ? (
          <div
            className="max-w-3xl mx-auto px-6 py-8 prose prose-sm bg-white/60 backdrop-blur rounded-3xl my-6 shadow-lg border border-purple-100"
            dangerouslySetInnerHTML={{ __html: renderPreview() }}
            onClick={handleLinkClick}
          />
        ) : (
          <div className="max-w-3xl mx-auto px-6 py-8 my-6">
            <textarea
              ref={contentRef}
              value={content}
              onChange={(e) => setContent(e.target.value)}
              placeholder="Escribe tu pensamiento... Usa #tags y [[enlaces]] para conectar ideas"
              className="w-full h-full px-6 py-6 text-base leading-relaxed resize-none focus:outline-none bg-white/60 backdrop-blur rounded-3xl shadow-lg border-2 border-purple-100 focus:border-purple-400 transition-all placeholder:text-gray-400"
              style={{ minHeight: "calc(100vh - 240px)" }}
            />
          </div>
        )}
      </div>

      {/* Barra de herramientas */}
      <div className="bg-white/80 backdrop-blur-md border-t border-purple-100 px-4 py-4 shadow-sm">
        <div className="max-w-3xl mx-auto flex items-center justify-between">
          <div className="flex items-center gap-3">
            <button
              onClick={() => insertMarkdown("#")}
              className="flex items-center gap-2 px-4 py-2 bg-gradient-to-br from-blue-500 to-cyan-500 hover:from-blue-600 hover:to-cyan-600 text-white rounded-lg transition-all hover:scale-105 shadow-md font-medium"
              title="Insertar tag"
            >
              <Hash size={18} />
              <span className="hidden sm:inline">Tag</span>
            </button>
            
            <button
              onClick={() => insertMarkdown("[[", "]]")}
              className="flex items-center gap-2 px-4 py-2 bg-gradient-to-br from-purple-500 to-pink-500 hover:from-purple-600 hover:to-pink-600 text-white rounded-lg transition-all hover:scale-105 shadow-md font-medium"
              title="Insertar enlace"
            >
              <Link2 size={18} />
              <span className="hidden sm:inline">Enlace</span>
            </button>
            
            <button
              onClick={() => insertMarkdown("- ")}
              className="flex items-center gap-2 px-4 py-2 bg-gradient-to-br from-green-500 to-emerald-500 hover:from-green-600 hover:to-emerald-600 text-white rounded-lg transition-all hover:scale-105 shadow-md font-medium"
              title="Lista"
            >
              <List size={18} />
              <span className="hidden sm:inline">Lista</span>
            </button>
            
            <button
              onClick={() => insertMarkdown("**", "**")}
              className="flex items-center gap-2 px-4 py-2 bg-gradient-to-br from-orange-500 to-amber-500 hover:from-orange-600 hover:to-amber-600 text-white rounded-lg transition-all hover:scale-105 shadow-md font-medium"
              title="Negrita"
            >
              <Bold size={18} />
              <span className="hidden sm:inline">Negrita</span>
            </button>
          </div>
          
          <button
            onClick={() => setIsPreview(!isPreview)}
            className="flex items-center gap-2 px-5 py-2 bg-gradient-to-br from-indigo-500 to-purple-500 hover:from-indigo-600 hover:to-purple-600 text-white rounded-lg transition-all hover:scale-105 shadow-md font-medium"
          >
            <Eye size={18} />
            <span>{isPreview ? "Editar" : "Vista Previa"}</span>
          </button>
        </div>
      </div>
    </div>
  );
}