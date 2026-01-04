import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:camera/camera.dart';

class ObjectPainter extends CustomPainter {
  ObjectPainter(this._objects, this._imageSize, this._rotation, this._cameraLensDirection);

  final List<DetectedObject> _objects;
  final Size _imageSize;
  final InputImageRotation _rotation;
  final CameraLensDirection _cameraLensDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.lightGreenAccent;

    final Paint background = Paint()
      ..color = Color(0x99000000);

    for (final DetectedObject detectedObject in _objects) {
      final ui.ParagraphBuilder builder = ui.ParagraphBuilder(
        ui.ParagraphStyle(
            textAlign: TextAlign.left,
            fontSize: 16,
            textDirection: TextDirection.ltr),
      );
      builder.pushStyle(ui.TextStyle(color: Colors.lightGreenAccent, background: background));
      if (detectedObject.labels.isNotEmpty) {
        final label = detectedObject.labels
            .reduce((a, b) => a.confidence > b.confidence ? a : b);
        builder.addText('${label.text} ${label.confidence.toStringAsFixed(2)}');
      } else {
        builder.addText('Object');
      }
      builder.pop();

      final left = translateX(
        detectedObject.boundingBox.left,
        size,
        _imageSize,
        _rotation,
        _cameraLensDirection,
      );
      final top = translateY(
        detectedObject.boundingBox.top,
        size,
        _imageSize,
        _rotation,
        _cameraLensDirection,
      );
      final right = translateX(
        detectedObject.boundingBox.right,
        size,
        _imageSize,
        _rotation,
        _cameraLensDirection,
      );
      final bottom = translateY(
        detectedObject.boundingBox.bottom,
        size,
        _imageSize,
        _rotation,
        _cameraLensDirection,
      );

      canvas.drawRect(
        Rect.fromLTRB(left, top, right, bottom),
        paint,
      );

      canvas.drawParagraph(
        builder.build()
          ..layout(ui.ParagraphConstraints(
            width: (right - left).abs(),
          )),
        Offset(left, top),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;

  double translateX(
    double x,
    Size canvasSize,
    Size imageSize,
    InputImageRotation rotation,
    CameraLensDirection cameraLensDirection,
  ) {
    return switch (rotation) {
      InputImageRotation.rotation90deg => x *
          canvasSize.width /
          (Platform.isIOS ? imageSize.width : imageSize.height),
      InputImageRotation.rotation270deg => canvasSize.width -
          x *
              canvasSize.width /
              (Platform.isIOS ? imageSize.width : imageSize.height),
      InputImageRotation.rotation0deg || InputImageRotation.rotation180deg => x * canvasSize.width / imageSize.width,
    };
  }

  double translateY(
    double y,
    Size canvasSize,
    Size imageSize,
    InputImageRotation rotation,
    CameraLensDirection cameraLensDirection,
  ) {
    return switch (rotation) {
      InputImageRotation.rotation90deg || InputImageRotation.rotation270deg => y *
          canvasSize.height /
          (Platform.isIOS ? imageSize.height : imageSize.width),
      InputImageRotation.rotation0deg || InputImageRotation.rotation180deg => y * canvasSize.height / imageSize.height,
    };
  }
}
