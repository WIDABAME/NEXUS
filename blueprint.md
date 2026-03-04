# Nexus App Blueprint (Versión 2.0)

## Descripción General

Nexus es una aplicación de toma de notas moderna y elegante, diseñada con Flutter. Su objetivo es proporcionar una experiencia de usuario limpia, intuitiva y visualmente atractiva para capturar, organizar y encontrar ideas rápidamente. La aplicación ha sido completamente rediseñada para adoptar una estética minimalista y vibrante, centrada en la facilidad de uso.

## Arquitectura y Estado

*   **Gestión de Estado:** La aplicación utiliza el paquete `provider` para una gestión de estado centralizada y reactiva. La clase `NexusData` actúa como un `ChangeNotifier`, gestionando toda la lógica de negocio y el estado de las notas.
*   **Persistencia de Datos:** Todas las notas se guardan localmente en el dispositivo utilizando el paquete `shared_preferences`. Los datos se codifican en formato JSON, asegurando que las notas del usuario persistan entre sesiones de la aplicación. La carga y el guardado son automáticos.
*   **Modelo de Datos:** El núcleo de los datos es la clase `Note`, que contiene un `id` único (generado por `uuid`), un `title`, un `content` y una `createdAt` para el seguimiento.

## Funcionalidades Implementadas

### Estilo y Diseño (UI/UX)

*   **Paleta de Colores:** Se utiliza una paleta de colores sofisticada con un fondo de gradiente lavanda pálido (`#FBFBFF` a `#F4F3FF`), y acentos vibrantes de gradiente púrpura/magenta para botones y elementos interactivos.
*   **Tipografía:** La fuente principal es 'Poppins', importada a través del paquete `google_fonts`, que proporciona a la aplicación un aspecto moderno y legible.
*   **Diseño de la Pantalla Principal:**
    *   Una `AppBar` personalizada con un logotipo, el nombre de la aplicación y un botón de menú.
    *   Una barra de búsqueda estilizada con fondo blanco semitransparente.
    *   Un **Botón de Acción Flotante (FAB)** en la esquina inferior derecha para crear notas, diseñado con un gradiente personalizado y una sombra para un efecto visual destacado.
    *   Las notas se muestran en una `GridView` de dos columnas.
    *   Un estado vacío (empty state) bien diseñado guía al usuario cuando no hay notas o cuando una búsqueda no arroja resultados.
*   **Tarjetas de Nota (`NoteCard`):** Cada nota se muestra en una tarjeta con esquinas redondeadas, una sombra sutil para dar profundidad, y un fondo blanco semitransparente. Muestra el título, un extracto del contenido y la fecha de creación.
*   **Pantalla de Edición de Notas:** Una interfaz de escritura sin distracciones, con campos de texto sin bordes. La `AppBar` de esta pantalla contiene un botón de "atrás" y botones de acción con gradientes.

### Funcionalidad

*   **Gestión de Notas (CRUD):**
    *   **Crear:** Los usuarios pueden crear nuevas notas a través del **Botón de Acción Flotante (FAB)**, que les lleva a una pantalla de edición limpia.
    *   **Leer:** Las notas se muestran en la pantalla principal en orden cronológico inverso.
    *   **Actualizar:** Al tocar una tarjeta de nota existente, el usuario navega a la pantalla de edición para modificarla. El guardado es automático al salir de la pantalla.
    *   **Eliminar:** Cada tarjeta de nota tiene un icono de papelera que permite eliminar la nota de forma inmediata.
*   **Navegación Fluida:** La navegación entre la pantalla principal y la de edición se gestiona con `Navigator`.
*   **Búsqueda en Tiempo Real:** La barra de búsqueda permite a los usuarios filtrar sus notas por título o contenido. La lista se actualiza instantáneamente.
*   **Formato de Fecha:** Las fechas de creación se formatean de manera legible utilizando el paquete `intl`.