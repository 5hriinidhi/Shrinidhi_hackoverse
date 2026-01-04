import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import '../utils/object_painter.dart';
import '../utils/image_utils.dart';
import 'camera_view.dart';

class ObjectDetectorView extends StatefulWidget {
  const ObjectDetectorView({super.key});

  @override
  State<ObjectDetectorView> createState() => _ObjectDetectorViewState();
}

class _ObjectDetectorViewState extends State<ObjectDetectorView> {
  // Config
  // Config
  final String _apiKey = "ItgPAyOo1Pab5QkU91l6";
  final String _workspace = "shrinidhi-zangaruche";
  final String _workflowId = "find-cars-taxis-autos-people-and-motorbikes";

  bool _isBusy = false;
  CustomPaint? _customPaint;
  String? _text;
  var _cameraLensDirection = CameraLensDirection.back;
  
  // Throttling
  DateTime? _lastApiCallTime;
  final Duration _throttleDuration = const Duration(seconds: 1); 

  @override
  void initState() {
    super.initState();
    _requestPermission();
  }

  void _requestPermission() async {
    await Permission.camera.request();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Roboflow Detector')),
      body: Stack(children: [
        CameraView(
          customPaint: _customPaint,
          onImage: _processImage,
          initialCameraLensDirection: _cameraLensDirection,
        ),
        Positioned(
            top: 30,
            left: 10,
            right: 10,
            child: Row(
              children: [
                Spacer(),
                Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: Text(
                    _text ?? 'Looking for objects...',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Spacer(),
              ],
            )),
      ]),
    );
  }

  Future<void> _processImage(InputImage inputImage, CameraImage cameraImage) async {
    if (_isBusy) return;
    
    // Throttling
    if (_lastApiCallTime != null && DateTime.now().difference(_lastApiCallTime!) < _throttleDuration) {
      return;
    }

    _isBusy = true;
    _lastApiCallTime = DateTime.now();
    
    setState(() {
      _text = 'Processing...';
    });

    try {
        // Convert to Base64
        final base64Image = ImageUtils.convertCameraImageToBase64(cameraImage);
        
        if (base64Image != null) {
            await detectObjects(base64Image, inputImage.metadata!.size, inputImage.metadata!.rotation);
        } else {
             print("Failed to convert image");
        }
    } catch (e) {
        print("Error processing frame: $e");
    } finally {
        _isBusy = false;
    }
  }

  Future<void> detectObjects(String base64Image, Size imageSize, InputImageRotation rotation) async {
    // Roboflow Workflows API endpoint (Restored based on Python snippet)
    final url = "https://detect.roboflow.com/infer/workflows/$_workspace/$_workflowId";

    try {
        final response = await http.post(
            Uri.parse(url),
            headers: {
                "Content-Type": "application/json" 
            },
            body: json.encode({
                "api_key": _apiKey,
                "inputs": {
                    "image": {
                        "type": "base64",
                        "value": base64Image
                    }
                }
            }),
        );

        if (response.statusCode == 200) {
            var results = json.decode(response.body);
            // Workflows return 'outputs'. We need to inspect which output contains our predictions.
            // Assuming the workflow has a standard object detection model block, 
            // the output might be named after the model or 'predictions'.
            // Let's print the full response first for debugging if users run this, 
            // but for implementation, we'll try to find a list of detections.
            
            // Common structure: results['outputs'][0]['predictions'] or similar.
            // Let's assume the workflow returns a flat output if it's simple, or we check 'outputs'.
            
            List<dynamic> rawPredictions = [];
            
            // Prioritize simple 'predictions' list as per Hosted Inference API and User Example
            if (results.containsKey('predictions')) {
                 rawPredictions = results['predictions'];
            } 
            // Fallback for tricky workflow outputs if user reverts to workflows later
            else if (results.containsKey('outputs')) {
                 dynamic outputs = results['outputs'];
                 if (outputs is List && outputs.isNotEmpty) {
                    for (var output in outputs) {
                       if (output is Map && output.containsKey('predictions')) {
                           rawPredictions = output['predictions'];
                           break;
                       }
                    }
                 } else if (outputs is Map) {
                     outputs.forEach((key, val) {
                         if (val is Map && val.containsKey('predictions')) {
                             rawPredictions = val['predictions'];
                         }
                     });
                 }
            } else if (results is List) {
                rawPredictions = results;
            }

            // If we found nothing, let's just try to parse whatever looks like a list with x,y,width,height
            if (rawPredictions.isEmpty) {
                 // Debug: print(results);
            }

            List<DetectedObject> objects = [];
            
            for (var p in rawPredictions) {
                // Workflows often return x, y as center
                final double x = (p['x'] as num).toDouble();
                final double y = (p['y'] as num).toDouble();
                final double w = (p['width'] as num).toDouble();
                final double h = (p['height'] as num).toDouble();
                final String label = p['class'] ?? 'Object';
                final double confidence = (p['confidence'] as num).toDouble();
                
                final rect = Rect.fromCenter(center: Offset(x, y), width: w, height: h);
                
                final dObject = DetectedObject(
                    boundingBox: rect,
                    labels: [Label(text: label, confidence: confidence, index: 0)],
                    trackingId: null 
                );
                objects.add(dObject);
            }

            final painter = ObjectPainter(
                objects,
                imageSize,
                rotation,
                _cameraLensDirection,
            );
            
            if (mounted) {
                setState(() {
                     _customPaint = CustomPaint(painter: painter);
                     if (objects.isNotEmpty) {
                       final first = objects.first.boundingBox;
                       _text = "Found ${objects.length}. 1st: [${first.left.toInt()}, ${first.top.toInt()}, ${first.width.toInt()}x${first.height.toInt()}]";
                     } else {
                       _text = "Found 0 objects";
                     }
                });
            }

        } else {
            print("API Error: ${response.statusCode} - ${response.body}");
            if (mounted) {
                 setState(() {
                     _text = "Err: ${response.statusCode}\n${response.body.substring(0, 50)}...";
                 });
            }
        }
    } catch (e) {
        print("Network Error: $e");
        if (mounted) {
            setState(() {
                _text = "Error: $e";
            });
        }
    }
  }
}
