import 'dart:convert';
import 'package:http/http.dart' as http;

class CurrencyService {
  final http.Client _client;
  final Map<String, Map<String, double>> _cache = {};

  CurrencyService(this._client);

  /// Get exchange rate from one currency to another
  /// Uses in-memory cache keyed by from->to->date
  Future<double> getRate({
    required String from,
    required String to,
  }) async {
    // If same currency, rate is 1
    if (from == to) return 1.0;

    // Check cache for today's date
    final today = DateTime.now().toIso8601String().split('T')[0];
    final cacheKey = '$from->$to->$today';
    
    if (_cache.containsKey(cacheKey) && _cache[cacheKey]!.containsKey(to)) {
      return _cache[cacheKey]![to]!;
    }

    try {
      final uri = Uri.parse(
        'https://api.exchangerate.host/latest?base=$from&symbols=$to',
      );
      final res = await _client.get(uri);

      if (res.statusCode != 200) {
        throw Exception('Rate fetch failed with status ${res.statusCode}');
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final rates = data['rates'] as Map<String, dynamic>;
      final rate = (rates[to] as num).toDouble();

      // Cache the result
      _cache[cacheKey] = {to: rate};

      return rate;
    } catch (e) {
      // If API fails, return 1.0 as fallback
      print('Currency API error: $e');
      return 1.0;
    }
  }

  /// Convert an amount using a pre-fetched rate
  double convert(double amount, double rateToBase) {
    return double.parse((amount * rateToBase).toStringAsFixed(2));
  }

  /// Clear the cache
  void clearCache() {
    _cache.clear();
  }
}
