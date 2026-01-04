import 'dart:convert';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as imglib;

class ImageUtils {
  static String? convertCameraImageToBase64(CameraImage image) {
    try {
      imglib.Image? img;
      if (image.format.group == ImageFormatGroup.yuv420) {
        img = _convertYUV420(image);
      } else if (image.format.group == ImageFormatGroup.bgra8888) {
        img = _convertBGRA8888(image);
      }
      
      if (img != null) {
        // Rotate the image 90 degrees to handle portrait mode on Android
        // Most Android sensors are landscape (90 deg offset)
        img = imglib.copyRotate(img, angle: 90);
        
        // Encode to JPEG
        List<int> jpeg = imglib.encodeJpg(img);
        return base64Encode(jpeg);
      }
    } catch (e) {
      print("Error converting image: $e");
    }
    return null;
  }

  static imglib.Image _convertBGRA8888(CameraImage image) {
    return imglib.Image.fromBytes(
      width: image.width,
      height: image.height,
      bytes: image.planes[0].bytes.buffer,
      order: imglib.ChannelOrder.bgra,
    );
  }

  static imglib.Image _convertYUV420(CameraImage image) {
    final width = image.width;
    final height = image.height;
    var img = imglib.Image(width: width, height: height);
    
    // Per-pixel conversion would be too slow here in Dart usually, 
    // but the 'image' package might have helpers or we do a basic one.
    // For simplicity/performance in this constrained env, we might rely on the image package's YUV conversion if available
    // OR just use valid planes.
    // Actually, image 4.x has better support.
    
    // Simple implementation or placeholder not efficient for 30fps.
    // But since we are doing HTTP request, we can afford one slow frame conversion.
    
    final int uvRowStride = image.planes[1].bytesPerRow;
    final int uvPixelStride = image.planes[1].bytesPerPixel!;
    
    for (int x = 0; x < width; x++) {
      for (int y = 0; y < height; y++) {
        final int uvIndex = uvPixelStride * (x / 2).floor() + uvRowStride * (y / 2).floor();
        final int index = y * width + x;
        
        final yp = image.planes[0].bytes[index];
        final up = image.planes[1].bytes[uvIndex];
        final vp = image.planes[2].bytes[uvIndex];
        
        int r = (yp + (vp - 128) * 1.402).toInt();
        int g = (yp - (up - 128) * 0.34414 - (vp - 128) * 0.71414).toInt();
        int b = (yp + (up - 128) * 1.772).toInt();
        
        img.setPixelRgb(x, y, r.clamp(0, 255), g.clamp(0, 255), b.clamp(0, 255));
      }
    }
    return img;
  }
}
