import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Baixa uma imagem de produto e salva na pasta Downloads (substitui ImageDownloader).
class ImageDownloader {
  static Future<void> downloadImage(
    BuildContext context,
    String imageUrl,
    String productName,
  ) async {
    if (imageUrl.isEmpty) {
      _toast(context, 'URL da imagem inválida');
      return;
    }
    try {
      final safeName = productName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').length > 50
          ? productName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').substring(0, 50)
          : productName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${safeName}_$timestamp.jpg';

      final response = await http
          .get(Uri.parse(imageUrl))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        _toast(context, 'Erro ao baixar imagem');
        return;
      }
      final bytes = response.bodyBytes;

      final dir = await getExternalStorageDirectory();
      final downloadsDir = Directory('${dir?.path ?? '/tmp'}/Download');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      final file = File('${downloadsDir.path}/$fileName');
      await file.writeAsBytes(bytes);
      _toast(context, 'Imagem salva: $fileName');
    } catch (e) {
      _toast(context, 'Erro ao baixar: $e');
    }
  }

  static void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }
}
