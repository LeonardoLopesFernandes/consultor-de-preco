import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

/// Equivalente a io.amer.scanner.AmericanasWebScraper (busca preço no HTML).
class AmericanasWebScraper {
  static Future<String?> searchPriceByEan(String ean) async {
    try {
      final uri = Uri.parse('https://www.americanas.com.br/busca/$ean');
      final response = await http.get(
        uri,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      ).timeout(const Duration(seconds: 4));

      final html = response.body;

      // Tenta extrair do __NEXT_DATA__
      final nextDataMatch = RegExp(
        r'window\.__NEXT_DATA__\s*=\s*(\{.*?\});</script>',
        dotAll: true,
      ).firstMatch(html);

      if (nextDataMatch != null) {
        try {
          final json = jsonDecode(nextDataMatch.group(1)!);
          final props = json['props'];
          final pageProps = props?['pageProps'];
          final product = pageProps?['product'];
          if (product != null) {
            final priceValue =
                (product['price']?['sellingPrice'] as num?)?.toDouble() ?? 0.0;
            if (priceValue > 0) {
              return 'R\$ ${_format(priceValue)}';
            }
          }
        } catch (_) {
          // ignora
        }
      }

      // Fallback: regex de preço no HTML
      final priceMatch = RegExp(
        r'R\$\s*([0-9]+[.,][0-9]{2})',
        caseSensitive: false,
      ).firstMatch(html);

      if (priceMatch != null) {
        return _formatPrice(priceMatch.group(1)!);
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  static String _formatPrice(String value) {
    final clean = value.replaceAll(RegExp(r'[^0-9,.]'), '').replaceAll(',', '.');
    final n = double.tryParse(clean) ?? 0.0;
    return 'R\$ ${_format(n)}';
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
