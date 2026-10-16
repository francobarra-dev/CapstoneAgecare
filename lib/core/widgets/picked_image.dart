import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Vista previa de una imagen elegida con image_picker.
///
/// Lee los bytes del XFile, así que funciona igual en Android, iOS y web
/// (Image.file depende de dart:io y no existe en el navegador).
class PickedImage extends StatefulWidget {
  const PickedImage(this.file, {super.key, this.height, this.width, this.fit});

  final XFile file;
  final double? height;
  final double? width;
  final BoxFit? fit;

  @override
  State<PickedImage> createState() => _PickedImageState();
}

class _PickedImageState extends State<PickedImage> {
  late Future<Uint8List> _bytes = widget.file.readAsBytes();

  @override
  void didUpdateWidget(PickedImage old) {
    super.didUpdateWidget(old);
    if (old.file.path != widget.file.path) _bytes = widget.file.readAsBytes();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _bytes,
      builder: (context, snap) {
        if (!snap.hasData) {
          return SizedBox(
            height: widget.height,
            width: widget.width,
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        return Image.memory(snap.data!,
            height: widget.height, width: widget.width, fit: widget.fit);
      },
    );
  }
}
