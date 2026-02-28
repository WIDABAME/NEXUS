import { Hono } from "npm:hono";
import { cors } from "npm:hono/cors";
import { logger } from "npm:hono/logger";
import * as kv from "./kv_store.tsx";

const app = new Hono();

// Enable logger
app.use('*', logger(console.log));

// Enable CORS for all routes and methods
app.use(
  "/*",
  cors({
    origin: "*",
    allowHeaders: ["Content-Type", "Authorization"],
    allowMethods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    exposeHeaders: ["Content-Length"],
    maxAge: 600,
  }),
);

// Health check endpoint
app.get("/make-server-05d465fd/health", (c) => {
  return c.json({ status: "ok" });
});

// Get all notes
app.get("/make-server-05d465fd/notes", async (c) => {
  try {
    const notes = await kv.getByPrefix("note:");
    return c.json(notes.map(n => n.value));
  } catch (error) {
    console.error("Error getting notes:", error);
    return c.json({ error: "Failed to get notes" }, 500);
  }
});

// Get single note
app.get("/make-server-05d465fd/notes/:id", async (c) => {
  try {
    const id = c.req.param("id");
    const note = await kv.get(`note:${id}`);
    
    if (!note) {
      return c.json({ error: "Note not found" }, 404);
    }
    
    return c.json(note);
  } catch (error) {
    console.error("Error getting note:", error);
    return c.json({ error: "Failed to get note" }, 500);
  }
});

// Create note
app.post("/make-server-05d465fd/notes", async (c) => {
  try {
    const body = await c.req.json();
    const id = `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    
    const note = {
      id,
      title: body.title || "Nueva Nota",
      content: body.content || "",
      tags: body.tags || [],
      links: body.links || [],
      createdAt: body.createdAt || new Date().toISOString(),
      updatedAt: body.updatedAt || new Date().toISOString(),
    };
    
    await kv.set(`note:${id}`, note);
    return c.json(note, 201);
  } catch (error) {
    console.error("Error creating note:", error);
    return c.json({ error: "Failed to create note" }, 500);
  }
});

// Update note
app.put("/make-server-05d465fd/notes/:id", async (c) => {
  try {
    const id = c.req.param("id");
    const body = await c.req.json();
    
    const existingNote = await kv.get(`note:${id}`);
    if (!existingNote) {
      return c.json({ error: "Note not found" }, 404);
    }
    
    const updatedNote = {
      ...existingNote,
      ...body,
      id, // Preserve ID
      createdAt: existingNote.createdAt, // Preserve creation date
      updatedAt: new Date().toISOString(),
    };
    
    await kv.set(`note:${id}`, updatedNote);
    return c.json(updatedNote);
  } catch (error) {
    console.error("Error updating note:", error);
    return c.json({ error: "Failed to update note" }, 500);
  }
});

// Delete note
app.delete("/make-server-05d465fd/notes/:id", async (c) => {
  try {
    const id = c.req.param("id");
    await kv.del(`note:${id}`);
    return c.json({ success: true });
  } catch (error) {
    console.error("Error deleting note:", error);
    return c.json({ error: "Failed to delete note" }, 500);
  }
});

// Search notes
app.get("/make-server-05d465fd/notes/search", async (c) => {
  try {
    const query = c.req.query("q")?.toLowerCase() || "";
    const notes = await kv.getByPrefix("note:");
    
    const filtered = notes
      .map(n => n.value)
      .filter((note: any) => 
        note.title.toLowerCase().includes(query) ||
        note.content.toLowerCase().includes(query) ||
        note.tags.some((tag: string) => tag.toLowerCase().includes(query))
      );
    
    return c.json(filtered);
  } catch (error) {
    console.error("Error searching notes:", error);
    return c.json({ error: "Failed to search notes" }, 500);
  }
});

Deno.serve(app.fetch);