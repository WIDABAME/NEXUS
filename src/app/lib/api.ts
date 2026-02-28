import { projectId, publicAnonKey } from '/utils/supabase/info';

const BASE_URL = `https://${projectId}.supabase.co/functions/v1/make-server-05d465fd`;

export interface Note {
  id: string;
  title: string;
  content: string;
  tags: string[];
  links: string[];
  createdAt: string;
  updatedAt: string;
}

async function fetchAPI(endpoint: string, options: RequestInit = {}) {
  const response = await fetch(`${BASE_URL}${endpoint}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${publicAnonKey}`,
      ...options.headers,
    },
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`API Error: ${error}`);
  }

  return response.json();
}

export async function getNotes(): Promise<Note[]> {
  try {
    const notes = await fetchAPI('/notes');
    return Array.isArray(notes) ? notes : [];
  } catch (error) {
    console.error("Error fetching notes:", error);
    return [];
  }
}

export async function getNote(id: string): Promise<Note> {
  return fetchAPI(`/notes/${id}`);
}

export async function createNote(note: Partial<Note>): Promise<Note> {
  return fetchAPI('/notes', {
    method: 'POST',
    body: JSON.stringify(note),
  });
}

export async function updateNote(id: string, note: Partial<Note>): Promise<Note> {
  return fetchAPI(`/notes/${id}`, {
    method: 'PUT',
    body: JSON.stringify(note),
  });
}

export async function deleteNote(id: string): Promise<void> {
  await fetchAPI(`/notes/${id}`, {
    method: 'DELETE',
  });
}

export async function searchNotes(query: string): Promise<Note[]> {
  try {
    const results = await fetchAPI(`/notes/search?q=${encodeURIComponent(query)}`);
    return Array.isArray(results) ? results : [];
  } catch (error) {
    console.error("Error searching notes:", error);
    return [];
  }
}