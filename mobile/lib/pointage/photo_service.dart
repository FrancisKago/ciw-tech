import 'package:image_picker/image_picker.dart';

class PhotoCancelled implements Exception { const PhotoCancelled(); }

class PhotoService {
  PhotoService([ImagePicker? picker]) : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;

  /// Ouvre la caméra. Retourne le chemin local. Lève [PhotoCancelled] si annulé.
  Future<String> capture() async {
    final file = await _picker.pickImage(source: ImageSource.camera, imageQuality: 60, maxWidth: 1280);
    if (file == null) throw const PhotoCancelled();
    return file.path;
  }
}
