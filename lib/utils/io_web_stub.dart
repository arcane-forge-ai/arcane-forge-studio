class Directory {
  final String path;
  Directory(this.path);

  bool existsSync() => false;
  void createSync({bool recursive = false}) {
    throw UnsupportedError('Directory operations are not supported on the web.');
  }
}

enum FileMode { write }

class File {
  final String path;
  File(this.path);

  Future<void> writeAsBytes(List<int> bytes, {FileMode mode = FileMode.write, bool flush = false}) async {
    throw UnsupportedError('File operations are not supported on the web.');
  }
}
