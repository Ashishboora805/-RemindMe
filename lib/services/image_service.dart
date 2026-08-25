import 'dart:io';
import 'package:image_picker/image_picker.dart';

/// Where the user chose to take an image from.
enum ImageSourceChoice { camera, gallery }

/// Thin wrapper over image_picker for camera/gallery capture.
class ImageService {
  final _picker = ImagePicker();

  Future<File?> pickFromCamera() async {
    final shot = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    return shot == null ? null : File(shot.path);
  }

  Future<List<File>> pickFromGallery({bool allowMultiple = true}) async {
    if (allowMultiple) {
      final shots = await _picker.pickMultiImage(imageQuality: 85);
      return shots.map((x) => File(x.path)).toList();
    }
    final shot = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    return shot == null ? [] : [File(shot.path)];
  }
}
