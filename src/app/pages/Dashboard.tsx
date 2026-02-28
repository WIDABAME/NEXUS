import { useState, useEffect } from "react";
import { useNavigate } from "react-router";
import { Search, Menu, User, Plus, Hash } from "lucide-react";
import { getNotes, createNote, searchNotes } from "../lib/api";
import type { Note } from "../lib/api";
import { toast } from "sonner";

export function Dashboard() {
  const navigate = useNavigate();
  const [notes, setNotes] = useState<Note[]>([]);
  const [filteredNotes, setFilteredNotes] = useState<Note[]>([]);
  const [searchQuery, setSearchQuery] = useState("");
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadNotes();
  }, []);

  useEffect(() => {
    if (searchQuery.trim() === "") {
      setFilteredNotes(notes);
    } else {
      performSearch();
    }
  }, [searchQuery, notes]);

  async function loadNotes() {
    try {
      const data = await getNotes();
      // Filter out any null or invalid notes
      const validNotes = (data || []).filter(note => note && note.id && note.title !== undefined);
      setNotes(validNotes);
      setFilteredNotes(validNotes);
    } catch (error) {
      console.error("Error loading notes:", error);
      toast.error("Error al cargar las notas");
      setNotes([]);
      setFilteredNotes([]);
    } finally {
      setLoading(false);
    }
  }

  async function performSearch() {
    try {
      const results = await searchNotes(searchQuery);
      // Filter out any null or invalid notes
      const validResults = (results || []).filter(note => note && note.id && note.title !== undefined);
      setFilteredNotes(validResults);
    } catch (error) {
      console.error("Error searching notes:", error);
      // Fallback a búsqueda local
      const localResults = notes.filter(note => 
        note && note.id &&
        (note.title?.toLowerCase().includes(searchQuery.toLowerCase()) ||
        note.content?.toLowerCase().includes(searchQuery.toLowerCase()) ||
        note.tags?.some(tag => tag?.toLowerCase().includes(searchQuery.toLowerCase())))
      );
      setFilteredNotes(localResults);
    }
  }

  async function handleCreateNote() {
    try {
      const newNote = await createNote({
        title: "Nueva Nota",
        content: "",
        tags: [],
        links: [],
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      });
      navigate(`/note/${newNote.id}`);
    } catch (error) {
      console.error("Error creating note:", error);
      toast.error("Error al crear la nota");
    }
  }

  function getExcerpt(content: string, maxLength: number = 120): string {
    const plainText = content.replace(/[#*\[\]]/g, '');
    return plainText.length > maxLength 
      ? plainText.substring(0, maxLength) + "..."
      : plainText;
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-indigo-50 via-purple-50 to-pink-50">
      {/* Header con búsqueda */}
      <div className="bg-white/80 backdrop-blur-md border-b border-purple-100 sticky top-0 z-10 shadow-sm">
        <div className="max-w-4xl mx-auto px-4 py-5">
          <div className="flex items-center gap-4">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 bg-gradient-to-br from-indigo-600 to-purple-600 rounded-xl flex items-center justify-center shadow-md">
                <span className="text-white font-bold text-lg">N</span>
              </div>
              <h1 className="text-xl font-bold bg-gradient-to-r from-indigo-600 to-purple-600 bg-clip-text text-transparent">
                Nexus
              </h1>
            </div>
            
            <div className="flex-1 relative">
              <Search size={20} className="absolute left-4 top-1/2 -translate-y-1/2 text-purple-400" />
              <input
                type="text"
                placeholder="Buscar en tu cerebro digital..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="w-full pl-12 pr-4 py-3.5 bg-gradient-to-r from-purple-50 to-indigo-50 rounded-2xl text-sm focus:outline-none focus:ring-2 focus:ring-purple-400 focus:bg-white transition-all shadow-sm border border-purple-100"
              />
            </div>
            
            <button 
              onClick={() => navigate("/graph/all")}
              className="w-10 h-10 bg-gradient-to-br from-pink-500 to-purple-500 hover:from-pink-600 hover:to-purple-600 text-white rounded-xl flex items-center justify-center shadow-md transition-all hover:scale-105"
              title="Ver grafo"
            >
              <Menu size={20} />
            </button>
          </div>
        </div>
      </div>

      {/* Contenido principal */}
      <div className="max-w-4xl mx-auto px-4 py-8">
        <div className="flex items-center justify-between mb-6">
          <h2 className="text-2xl font-bold text-gray-800">
            Notas Recientes
          </h2>
          
          <button
            onClick={handleCreateNote}
            className="flex items-center gap-2 bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-700 hover:to-purple-700 text-white px-6 py-3 rounded-xl shadow-lg transition-all hover:scale-105 hover:shadow-xl font-medium"
          >
            <Plus size={20} />
            Crear Nota
          </button>
        </div>

        {loading ? (
          <div className="space-y-4">
            {[...Array(3)].map((_, i) => (
              <div key={i} className="bg-white/80 backdrop-blur rounded-2xl p-6 border border-purple-100 animate-pulse shadow-md">
                <div className="h-6 bg-gradient-to-r from-purple-200 to-indigo-200 rounded-lg w-1/3 mb-4"></div>
                <div className="h-4 bg-gradient-to-r from-purple-100 to-indigo-100 rounded w-full mb-2"></div>
                <div className="h-4 bg-gradient-to-r from-purple-100 to-indigo-100 rounded w-2/3 mb-4"></div>
                <div className="flex gap-2">
                  <div className="h-7 bg-gradient-to-r from-blue-200 to-purple-200 rounded-full w-20"></div>
                  <div className="h-7 bg-gradient-to-r from-pink-200 to-purple-200 rounded-full w-24"></div>
                </div>
              </div>
            ))}
          </div>
        ) : filteredNotes.length === 0 ? (
          <div className="text-center py-20">
            <div className="bg-white/60 backdrop-blur rounded-3xl p-12 inline-block shadow-lg border border-purple-100">
              {searchQuery ? (
                <>
                  <div className="w-20 h-20 bg-gradient-to-br from-purple-100 to-pink-100 rounded-full flex items-center justify-center mx-auto mb-4">
                    <Search size={40} className="text-purple-500" />
                  </div>
                  <p className="text-gray-700 font-medium mb-2 text-lg">No se encontraron notas</p>
                  <p className="text-gray-500 text-sm">Intenta con otra búsqueda</p>
                </>
              ) : (
                <>
                  <div className="w-20 h-20 bg-gradient-to-br from-indigo-100 to-purple-100 rounded-full flex items-center justify-center mx-auto mb-4">
                    <Plus size={40} className="text-indigo-500" />
                  </div>
                  <p className="text-gray-700 font-medium mb-2 text-lg">Aún no tienes notas</p>
                  <p className="text-gray-500 text-sm">Presiona "Crear Nota" para empezar</p>
                </>
              )}
            </div>
          </div>
        ) : (
          <div className="grid gap-4">
            {filteredNotes.map((note, index) => {
              const gradients = [
                'from-blue-50 to-indigo-50 hover:from-blue-100 hover:to-indigo-100 border-blue-200',
                'from-purple-50 to-pink-50 hover:from-purple-100 hover:to-pink-100 border-purple-200',
                'from-green-50 to-emerald-50 hover:from-green-100 hover:to-emerald-100 border-green-200',
                'from-orange-50 to-amber-50 hover:from-orange-100 hover:to-amber-100 border-orange-200',
                'from-rose-50 to-pink-50 hover:from-rose-100 hover:to-pink-100 border-rose-200',
              ];
              const gradient = gradients[index % gradients.length];
              
              return (
                <div
                  key={note.id}
                  onClick={() => navigate(`/note/${note.id}`)}
                  className={`bg-gradient-to-br ${gradient} rounded-2xl p-6 border-2 hover:shadow-xl transition-all cursor-pointer transform hover:-translate-y-1 backdrop-blur-sm`}
                >
                  <h3 className="text-xl font-bold text-gray-900 mb-3">
                    {note.title || "Sin título"}
                  </h3>
                  
                  <p className="text-sm text-gray-700 mb-4 line-clamp-2 leading-relaxed">
                    {getExcerpt(note.content) || "Nota vacía"}
                  </p>
                  
                  {note.tags && note.tags.length > 0 && (
                    <div className="flex flex-wrap gap-2">
                      {note.tags.map((tag, idx) => (
                        <span
                          key={idx}
                          className="inline-flex items-center gap-1 px-3 py-1.5 bg-white/70 backdrop-blur text-purple-700 rounded-full text-xs font-medium shadow-sm border border-purple-200"
                        >
                          <Hash size={14} />
                          {tag}
                        </span>
                      ))}
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}