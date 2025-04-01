import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Create directories if they don't exist
  Directory('assets/icon').createSync(recursive: true);

  // Generate the app icon
  await generateIcon(
    outputPath: 'assets/icon/app_icon.png',
    size: 1024,
    background: const Color(0xFF5B4CFF),
    withPadding: false,
  );

  // Generate the foreground for adaptive icons
  await generateIcon(
    outputPath: 'assets/icon/app_icon_foreground.png',
    size: 1024,
    background: Colors.transparent,
    withPadding: true,
  );

  print('Icons generated successfully!');
  exit(0);
}

Future<void> generateIcon({
  required String outputPath,
  required double size,
  required Color background,
  required bool withPadding,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final paint = Paint();

  // Draw background
  if (background != Colors.transparent) {
    paint.color = background;
    canvas.drawRect(Rect.fromLTWH(0, 0, size, size), paint);
  }

  final iconSize = withPadding ? size * 0.7 : size * 0.85;
  final center = size / 2;
  // ignore: unused_local_variable
  final offset = (size - iconSize) / 2;

  // Draw main circle
  paint.color = Colors.white;
  canvas.drawCircle(Offset(center, center), iconSize / 2, paint);

  // Draw number pattern
  final textStyle = TextStyle(
    color: const Color(0xFF5B4CFF),
    fontSize: iconSize * 0.4,
    fontWeight: FontWeight.bold,
  );

  final textPainter = TextPainter(
    text: TextSpan(
      text: '123',
      style: textStyle,
    ),
    textDirection: TextDirection.ltr,
  );

  textPainter.layout();
  textPainter.paint(
    canvas,
    Offset(
      center - textPainter.width / 2,
      center - textPainter.height / 2,
    ),
  );

  // Finish drawing
  final picture = recorder.endRecording();
  final img = await picture.toImage(size.toInt(), size.toInt());
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  final buffer = byteData!.buffer.asUint8List();

  // Save to file
  File(outputPath).writeAsBytesSync(buffer);
}
