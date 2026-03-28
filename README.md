# Nexus: Tu Red de Conocimiento

Nexus es una aplicación de notas inteligente construida con Flutter. No es solo un lugar para guardar tus pensamientos, sino una herramienta para visualizar cómo se conectan tus ideas, creando un "segundo cerebro" digital.

## Visión General

La aplicación permite a los usuarios crear, editar y eliminar notas. La característica principal es la **vista de grafo**, que genera automáticamente un mapa visual de las relaciones entre las notas basándose en palabras clave comunes en sus títulos.

## Características Principales

*   **Creación y Edición de Notas:** Una interfaz simple y limpia para capturar ideas rápidamente.
*   **Conexión Automática de Ideas:** Las notas con títulos que comparten palabras clave se vinculan automáticamente.
*   **Grafo de Conocimiento Visual:** Explora tus notas y sus conexiones en un grafo interactivo.
*   **Búsqueda en Tiempo Real:** Encuentra notas al instante con un filtro por título o contenido.
*   **Soporte para Imágenes:** Adjunta una imagen a cada nota para enriquecer tu contenido.
*   **Persistencia Local:** Tus notas se guardan de forma segura en tu dispositivo, accesibles en cualquier momento.
*   **Borrado Intuitivo:** Elimina notas con una pulsación larga en la pantalla principal.

## Guía de Uso

*   **Crear una Nota:** Pulsa el botón `+` en la esquina inferior derecha.
*   **Editar una Nota:** Pulsa sobre cualquier nota en la cuadrícula principal.
*   **Eliminar una Nota:** **Mantén pulsada** la tarjeta de una nota en la pantalla principal hasta que aparezca el diálogo de confirmación.
*   **Ver el Grafo:** Pulsa el icono del grafo (tres círculos conectados) en la barra superior de la pantalla principal.
*   **Buscar Notas:** Utiliza la barra de búsqueda en la pantalla principal para filtrar tus notas al instante.

## Arquitectura Técnica

La aplicación sigue una arquitectura limpia y reactiva, facilitando su mantenimiento y escalabilidad.

*   **Gestión de Estado:** Se utiliza el paquete `provider` para la gestión del estado. La clase `NexusData` (`lib/main.dart`) actúa como un `ChangeNotifier`, centralizando toda la lógica de negocio (crear, leer, actualizar, borrar notas) y notificando a la interfaz de usuario sobre cualquier cambio.
*   **Persistencia de Datos:** Las notas se guardan en el dispositivo en formato JSON utilizando `shared_preferences`. Esto asegura que los datos del usuario persistan entre sesiones.
*   **Modelo de Datos:**
    *   `Note`: Representa una nota individual con su `id`, `title`, `content`, `createdAt`, y un `imagePath` opcional. También contiene una lista de objetos `Connection`.
    *   `Connection`: Representa un enlace entre dos notas, almacenando el `noteId` de la nota conectada y el `topic` (la palabra clave en común).

## Funciones Clave y Pruebas

A continuación se detallan las funciones más importantes dentro de `NexusData` y cómo verificar su funcionamiento:

| Método/Función | Archivo (`lib/main.dart`) | Descripción Técnica | Prueba de Uso / Verificación |
| --- | --- | --- | --- |
| `loadNotes()` | `main.dart` | Carga la lista de notas desde `shared_preferences` (decodificando JSON), reconstruye todas las conexiones y notifica a los listeners. | Al abrir la aplicación, las notas guardadas previamente deben aparecer en la pantalla principal. El grafo debe mostrar las conexiones existentes. |
| `addNote(Note note)` | `main.dart` | Añade una nueva nota a la lista, recalcula todas las conexiones del grafo, guarda la lista actualizada en `shared_preferences` y notifica a la UI. | Crea una nota nueva. Debería aparecer inmediatamente en la parte superior de la lista. Si su título coincide con otra nota, se debe crear una conexión visible en el grafo. |
| `updateNote(Note updatedNote)` | `main.dart` | Busca una nota existente por su `id`, la reemplaza con la versión actualizada, recalcula las conexiones, guarda y notifica. | Edita una nota existente (título o contenido). Los cambios deben persistir después de guardar y ser visibles en la pantalla principal. Las conexiones del grafo pueden cambiar si el título lo hace. |
| `removeNote(String id)` | `main.dart` | Elimina una nota de la lista basándose en su `id`, recalcula las conexiones, guarda la lista actualizada y notifica a la UI. | Realiza una pulsación larga sobre una nota y confirma la eliminación. La nota debe desaparecer de la pantalla principal y del grafo. |
| `_rebuildAllConnections()` | `main.dart` | Limpia todas las conexiones existentes y las reconstruye desde cero analizando los títulos de todas las notas en busca de palabras clave comunes. | Crea dos notas con una palabra clave en común en el título (p. ej., "Mi proyecto Flutter" y "Tutorial de Flutter"). Ve al grafo y verifica que una línea conecta estas dos notas. |
| `_extractKeywords(String text)`| `main.dart` | Recibe un texto (el título de una nota), lo convierte a minúsculas, elimina puntuación y "stop words" (palabras comunes), y devuelve un `Set` de palabras clave. | Esta función es interna para `_rebuildAllConnections`. Su correcto funcionamiento se verifica indirectamente cuando las conexiones se crean como se espera. |

