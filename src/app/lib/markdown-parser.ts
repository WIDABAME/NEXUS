// Parsear tags (#tag) y enlaces bidireccionales ([[nota]])

export function extractTags(content: string): string[] {
  const tagRegex = /#([a-zA-ZáéíóúñÁÉÍÓÚÑ0-9_-]+)/g;
  const matches = content.matchAll(tagRegex);
  const tags = Array.from(matches, m => m[1]);
  return [...new Set(tags)]; // Eliminar duplicados
}

export function extractLinks(content: string): string[] {
  const linkRegex = /\[\[([^\]]+)\]\]/g;
  const matches = content.matchAll(linkRegex);
  const links = Array.from(matches, m => m[1]);
  return [...new Set(links)]; // Eliminar duplicados
}

export function highlightMarkdown(content: string): string {
  // Resaltar tags
  let highlighted = content.replace(
    /#([a-zA-ZáéíóúñÁÉÍÓÚÑ0-9_-]+)/g,
    '<span class="text-blue-600 font-medium">#$1</span>'
  );
  
  // Resaltar enlaces bidireccionales
  highlighted = highlighted.replace(
    /\[\[([^\]]+)\]\]/g,
    '<span class="text-purple-600 font-medium underline cursor-pointer" data-link="$1">[[$1]]</span>'
  );
  
  // Resaltar negritas
  highlighted = highlighted.replace(
    /\*\*([^*]+)\*\*/g,
    '<strong>$1</strong>'
  );
  
  // Resaltar cursivas
  highlighted = highlighted.replace(
    /\*([^*]+)\*/g,
    '<em>$1</em>'
  );
  
  return highlighted;
}

export function normalizeTitle(title: string): string {
  return title.trim().toLowerCase().replace(/\s+/g, '-');
}
