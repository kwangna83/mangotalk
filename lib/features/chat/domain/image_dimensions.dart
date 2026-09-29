import 'dart:typed_data';
import 'dart:ui' as ui;

class ImageDimensions {
  const ImageDimensions({required this.width, required this.height})
    : assert(width > 0),
      assert(height > 0);

  final int width;
  final int height;

  double get aspectRatio => width / height;
}

Future<ImageDimensions> readImageDimensions(Uint8List bytes) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  try {
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    try {
      if (descriptor.width <= 0 || descriptor.height <= 0) {
        throw const FormatException('이미지 크기를 확인할 수 없습니다.');
      }
      return ImageDimensions(
        width: descriptor.width,
        height: descriptor.height,
      );
    } finally {
      descriptor.dispose();
    }
  } finally {
    buffer.dispose();
  }
}
