/// Filtros de tipo de archivo usados por el explorador, el panel divided y la
/// busqueda global. Antes esta lista estaba copiada en 3 archivos y se
/// comparaba por texto contra etiquetas visibles al usuario.
class FileFilters {
  const FileFilters._();

  static const String all = 'All';
  static const String folders = 'Folders';
  static const String images = 'Images';
  static const String videos = 'Videos';
  static const String audio = 'Audio';
  static const String docs = 'Docs';

  static const List<String> all_ = <String>[
    all,
    folders,
    images,
    videos,
    audio,
    docs,
  ];
}