import 'dart:io';
import '../models/file_item_model.dart';

abstract class FileRepository {
  Future<List<FileItem>> getFiles(String path, {bool useRoot = false});
  Future<bool> deleteFile(String path, {bool useRoot = false});
  // Add more abstract methods for operations
}

class FileRepositoryImpl implements FileRepository {
  @override
  Future<List<FileItem>> getFiles(String path, {bool useRoot = false}) async {
    // Abstracting the logic from FileManagerProvider later
    return [];
  }

  @override
  Future<bool> deleteFile(String path, {bool useRoot = false}) async {
    return false;
  }
}
