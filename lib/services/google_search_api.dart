import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product.dart';
import '../utils/constants.dart';
import 'bluesoft_api.dart';

/// Equivalente a io.amer.scanner.GoogleSearchAPI (Busca descrição do produto).
class GoogleSearchApi {
  static Future<String?> searchProductDescription(String ean) async {
    // 1. Bluesoft por EAN
    var bluesoft = await BluesoftApi.searchProductByEan(ean);
    // 2. Bluesoft por descrição
    if (bluesoft == null) {
      bluesoft = await BluesoftApi.searchProductByDescription(ean);
    }
    if (bluesoft != null && bluesoft.name.isNotEmpty) {
      return bluesoft.name;
    }
    // 3. Fallback Google
    return _searchGoogleDescription(ean);
  }

  static Future<String?> _searchGoogleDescription(String ean) async {
    try {
      final query = Uri.encodeQueryComponent('$ean produto');
      final uri = Uri.parse(
        'https://serpapi.com/search?engine=google&q=$query&api_key=${ApiKeys.serpApiKey}',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      final json = jsonDecode(response.body);
      final results = json['organic_results'];
      if (results is List && results.isNotEmpty) {
        for (final r in results) {
          var title = r['title']?.toString() ?? '';
          if (title.isNotEmpty && title.length > 5) {
            title = title
                .replaceAll(RegExp(r'R\$\s*[0-9,.]+'), '')
                .replaceAll(RegExp(r'\|.*'), '')
                .replaceAll(RegExp(r'-.*'), '')
                .replaceAll(RegExp(r'\s+'), ' ')
                .trim();
            if (title.isNotEmpty && !title.contains(ean)) {
              return title.length > 80 ? title.substring(0, 80) : title;
            }
          }
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
