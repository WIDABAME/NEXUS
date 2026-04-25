# Manuales de la Funcionalidad "Nexus Connections"

---

## 1. Manual de Usuario

### ¿Qué son las Conexiones?

La función de Conexiones es el corazón de Nexus. Es un sistema inteligente que lee los títulos de tus notas y descubre automáticamente cuáles de ellas tratan sobre temas similares, creando un enlace entre ellas. 

Por ejemplo, una nota titulada "Recetas de pasta italiana" podría conectarse automáticamente con otra que se llame "Mi viaje por el norte de Italia".

### ¿Cómo funciona?

¡Es completamente automático! No necesitas hacer nada especial. Cada vez que creas, editas o eliminas una nota, Nexus trabaja en segundo plano para recalcular y actualizar las conexiones relevantes en toda tu base de conocimiento.

### ¿Cómo veo las Conexiones?

La aplicación te muestra las conexiones de dos maneras muy intuitivas:

1.  **En la Pantalla Principal:** En la cuadrícula de notas, ahora verás una pequeña insignia gris con un icono de enlace (🔗) y un número en la parte inferior de tus notas. Ese número indica cuántas otras notas están directamente conectadas a ella. Esto te da una pista visual rápida de qué tan central es una idea en tu red de conocimiento.


2.  **Dentro de una Nota:** Al abrir una nota para editarla, desplázate hacia la parte inferior. Si esa nota tiene conexiones, verás una nueva sección titulada **"Conexiones"**. Debajo, encontrarás una lista de botones con los títulos de todas las notas relacionadas.

### ¿Cómo navego entre Conexiones?

Esta es la parte más potente. En la sección "Conexiones" dentro de una nota, simplemente **toca el botón** de cualquiera de las notas relacionadas. Serás llevado instantáneamente a esa nota, permitiéndote saltar de una idea a otra de forma fluida y sin esfuerzo.

---

## 2. Manual Técnico

### Arquitectura General

La funcionalidad de Conexiones se implementa a través de una arquitectura cliente-servidor desacoplada, utilizando una Cloud Function de Firebase para el procesamiento pesado y el cliente Flutter para la interacción y visualización.

### Backend: Cloud Function `rebuildConnections`

-   **Trigger:** Es una función HTTPS Callable (`httpsCallable`), lo que significa que se invoca directamente desde la aplicación cliente.
-   **Ubicación:** `functions/src/index.ts`
-   **Input:** Recibe un objeto JSON con una sola clave, `notes`, que es una lista de objetos, cada uno con `id` y `title`.
    ```json
    { "notes": [ { "id": "note1", "title": "..." }, { "id": "note2", "title": "..." } ] }
    ```
-   **Proceso Lógico:**
    1.  **Extracción de Palabras Clave:** Para cada nota, se invoca la función interna `extractKeywords`. Esta función normaliza el título (minúsculas, sin acentos), lo divide en palabras y filtra "stop words" (artículos, preposiciones, etc.) y palabras de 2 caracteres o menos.
    2.  **Creación de Mapa Inverso:** Se construye una estructura de datos `Map<string, string[]>` donde la clave es la palabra clave normalizada y el valor es una lista de los IDs de las notas que contienen esa palabra clave.
    3.  **Construcción de Conexiones:** Se itera sobre el mapa inverso. Si una palabra clave está asociada con más de una nota, se crea una conexión bidireccional entre todas las notas de esa lista.
    4.  **Agrupación de Tópicos:** Si dos notas están conectadas por múltiples palabras clave (p. ej., "desarrollo" y "firebase"), estas se agrupan en un único `topic` separado por comas (ej: "desarrollo, firebase").
-   **Output:** Devuelve un objeto JSON que contiene un mapa de `connections`. La clave de este mapa es el ID de una nota, y su valor es una lista de objetos `Connection`, cada uno con el `noteId` de la nota conectada y el `topic` (la palabra clave en común).

### Frontend: Integración en Flutter

-   **Provider (`NexusData` en `lib/main.dart`):**
    -   La función principal es `_rebuildAllConnections()`. Esta función es asíncrona.
    -   Utiliza el paquete `cloud_functions` para preparar y llamar a la Cloud Function `rebuildConnections`.
    -   Al recibir la respuesta, itera sobre las notas en el estado local (`_notes`) y actualiza su propiedad `connections`.
    -   **Persistencia Local:** Crucialmente, después de actualizar las conexiones en el modelo de datos en memoria, invoca a `_dbHelper.updateNote(note)` para cada nota modificada, asegurando que las conexiones se guarden en la base de datos local SQLite.
    -   **Automatización (CRUD):** Las funciones `addNote`, `updateNote` y `removeNote` ahora llaman a `_rebuildAllConnections()` después de completar su operación principal y notificar a los listeners. Esto mantiene la UI y los datos sincronizados.

-   **Componentes de UI:**
    -   **`NoteCard` (`lib/main.dart`):**
        -   Renderiza condicionalmente un `Chip` si `note.connections.isNotEmpty`.
        -   El `Chip` muestra el `note.connections.length`.
    -   **`NoteEditorPage` (`lib/note_editor_page.dart`):**
        -   El método `build` ahora incluye una llamada a `_buildConnectionsSection(context)`.
        -   `_buildConnectionsSection` renderiza una `Column` con un título y un `Wrap` de `ActionChip`.
        -   Para obtener el título de la nota conectada (dado solo su ID), busca en la lista completa de notas (`nexusData.notes`) que obtiene del `NexusData` provider.
        -   La acción `onPressed` de cada `ActionChip` ejecuta un `Navigator.push` para abrir una nueva instancia de `NoteEditorPage`, pasando el objeto `Note` completo de la nota conectada.
