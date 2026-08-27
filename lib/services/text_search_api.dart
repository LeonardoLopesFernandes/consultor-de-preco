import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product.dart';
import '../utils/constants.dart';
import 'bluesoft_api.dart';

/// Equivalente a io.amer.scanner.TextSearchAPI (busca por descrição).
class TextSearchApi {
  static Future<List<ProductSearchResult>> searchProductByDescription(
      String query) async {
    // 1. Bluesoft
    try {
      final uri = Uri.parse(
        'https://api.cosmos.bluesoft.com.br/products?query=${Uri.encodeQueryComponent(query)}',
      );
      final response = await http.get(
        uri,
        headers: {
          'X-API-KEY': ApiKeys.bluesoftApiKey,
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode.toString().startsWith('2')) {
        final json = jsonDecode(response.body);
        final products = json['products'];
        if (products is List && products.isNotEmpty) {
          final temp = <ProductSearchResult>[];
          final limit = min(15, products.length);
          for (var i = 0; i < limit; i++) {
            final p = products[i];
            var title = p['description']?.toString() ?? '';
            if (title.isEmpty) title = p['name']?.toString() ?? '';
            if (title.isEmpty) title = p['product_name']?.toString() ?? '';
            final brand = p['brand']?.toString() ?? '';
            final ean = (p['gtin']?.toString().isNotEmpty == true)
                ? p['gtin'].toString()
                : (p['ean']?.toString() ?? '');

            String ncm = '';
            if (p['ncm'] is Map) ncm = p['ncm']['code']?.toString() ?? '';

            final fullTitle = brand.isNotEmpty && title.isNotEmpty
                ? '$brand $title'
                : title.isNotEmpty
                    ? title
                    : brand.isNotEmpty
                        ? brand
                        : 'Produto encontrado';

            double priceValue = 0.0;
            if (p['average_price'] is Map) {
              priceValue =
                  (p['average_price']['price'] as num?)?.toDouble() ?? 0.0;
            }
            final price = priceValue > 0
                ? 'R\$ ${_format(priceValue)}'
                : 'Preço sob consulta';

            var imageUrl = '';
            if (p['images'] is List && (p['images'] as List).isNotEmpty) {
              imageUrl = (p['images'][0]?.toString() ?? '')
                  .replaceAll('http://', 'https://');
            }
            if (imageUrl.isEmpty) {
              imageUrl = (p['thumbnail']?.toString() ?? '')
                  .replaceAll('http://', 'https://');
            }

            if (fullTitle.isNotEmpty && fullTitle != 'Produto encontrado') {
              temp.add(ProductSearchResult(
                title: fullTitle.length > 80 ? fullTitle.substring(0, 80) : fullTitle,
                price: price,
                source: 'Bluesoft',
                imageUrl: imageUrl,
                link: '',
                ean: ean,
                brand: brand,
                ncm: ncm,
                cest: p['cest']?.toString() ?? '',
                gpc: p['gpc']?.toString() ?? '',
              ));
            }
          }
          if (temp.isNotEmpty) return temp;
        }
      }
    } catch (_) {
      // cai no fallback
    }

    // 2. Google Shopping
    return _searchGoogleShopping(query);
  }

  static Future<List<ProductSearchResult>> _searchGoogleShopping(
      String query) async {
    try {
      final encoded = Uri.encodeQueryComponent(query);
      final uri = Uri.parse(
        'https://serpapi.com/search?engine=google&q=$encoded&tbm=shop&api_key=${ApiKeys.serpApiKeyTextSearch}&gl=br&hl=pt',
      );
      final response =
          await http.get(uri).timeout(const Duration(seconds: 8));
      final json = jsonDecode(response.body);
      final shopping = json['shopping_results'];
      if (shopping is List) {
        final temp = <ProductSearchResult>[];
        final limit = min(10, shopping.length);
        for (var i = 0; i < limit; i++) {
          final item = shopping[i];
          final title = item['title']?.toString() ?? '';
          final priceRaw = item['price']?.toString() ?? '';
          final source = item['source']?.toString() ?? '';
          var imageUrl = (item['thumbnail']?.toString() ?? '')
              .replaceAll('http://', 'https://');

          var link = item['link']?.toString() ?? '';
          if (link.isEmpty) link = item['product_link']?.toString() ?? '';
          if (link.isEmpty) link = item['url']?.toString() ?? '';

          var price = priceRaw;
          if (priceRaw.isNotEmpty && !priceRaw.contains('R\$')) {
            final v = _extractPrice(priceRaw);
            if (v > 0) price = 'R\$ ${_format(v)}';
          }

          if (title.isNotEmpty && title != 'null') {
            temp.add(ProductSearchResult(
              title: title.length > 80 ? title.substring(0, 80) : title,
              price: price,
              source: source,
              imageUrl: imageUrl,
              link: link,
              ean: '',
              brand: '',
              ncm: '',
              cest: '',
              gpc: '',
            ));
          }
        }
        return temp;
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static double _extractPrice(String s) {
    final dec = RegExp(r'(\d+[.,]\d{2})').firstMatch(s);
    if (dec != null) {
      return double.tryParse(dec.group(1)!.replaceAll(',', '.')) ?? 0.0;
    }
    final intMatch = RegExp(r'(\d+)').firstMatch(s);
    if (intMatch != null) {
      return double.tryParse(intMatch.group(1)!) ?? 0.0;
    }
    return 0.0;
  }

  static String _format(double n) {
    final s = n.toStringAsFixed(2);
    final parts = s.split('.');
    final intPart = parts[0];
    final buffer = StringBuffer();
    var count = 0;
    for (var i = intPart.length - 1; i >= 0; i--) {
      buffer.write(intPart[i]);
      count++;
      if (count % 3 == 0 && i != 0) buffer.write('.');
    }
    return buffer.toString().split('').reversed.join('');
  }
}
