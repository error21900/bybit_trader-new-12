import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'trade_model.dart';
import 'package:dio/dio.dart';

class ApiService {
  final String apiKey;
  final String apiSecret;
  static const String bybitBaseUrl = 'https://api.bybit.com';
  static const String bybitDemoUrl = 'https://api-demo.bybit.com';
  
  late Dio _dio;

  ApiService({required this.apiKey, required this.apiSecret}) {
    _dio = Dio(BaseOptions(
      baseUrl: bybitDemoUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
  }

  // ================================================================
  // API CALLS
  // ================================================================
  Future<void> testConnection() async {
    try {
      final response = await _dio.get(
        '/v5/account/wallet-balance',
        queryParameters: {
          'accountType': 'UNIFIED',
        },
        options: Options(
          headers: _getHeaders(
            'GET',
            '/v5/account/wallet-balance',
            'accountType=UNIFIED',
          ),
        ),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to connect to Bybit: ${response.statusMessage}');
      }
    } catch (e) {
      throw Exception('Connection test failed: $e');
    }
  }

  Future<BotStats> getStats() async {
    try {
      final balance = await _getBalance();
      final positions = await _getPositions();
      
      // For now, return a mock response
      // In production, this would fetch from your Flask server
      return BotStats(
        accountBalance: balance,
        openPositions: positions,
        trades: [],
        isRunning: false,
        lastUpdate: DateTime.now().toString(),
        totalPnL: _calculatePnL(positions),
      );
    } catch (e) {
      return BotStats.empty();
    }
  }

  Future<double> _getBalance() async {
    try {
      final response = await _dio.get(
        '/v5/account/wallet-balance',
        queryParameters: {
          'accountType': 'UNIFIED',
        },
        options: Options(
          headers: _getHeaders(
            'GET',
            '/v5/account/wallet-balance',
            'accountType=UNIFIED',
          ),
        ),
      );

      if (response.data['result'] != null) {
        final list = response.data['result']['list'] as List;
        if (list.isNotEmpty) {
          final usdt = list.firstWhere(
            (e) => e['coin'] == 'USDT',
            orElse: () => null,
          );
          if (usdt != null) {
            return double.parse(usdt['walletBalance'].toString());
          }
        }
      }
      return 0;
    } catch (e) {
      print('Error getting balance: $e');
      return 0;
    }
  }

  Future<Map<String, Position>> _getPositions() async {
    try {
      final response = await _dio.get(
        '/v5/position/list',
        queryParameters: {
          'category': 'linear',
        },
        options: Options(
          headers: _getHeaders(
            'GET',
            '/v5/position/list',
            'category=linear',
          ),
        ),
      );

      final positions = <String, Position>{};
      if (response.data['result'] != null &&
          response.data['result']['list'] != null) {
        for (var pos in response.data['result']['list']) {
          final contracts = double.parse(pos['size'].toString());
          if (contracts > 0) {
            final symbol = pos['symbol'] as String;
            positions[symbol] = Position(
              symbol: symbol,
              side: pos['side'].toString().toLowerCase(),
              contracts: contracts,
              entryPrice: double.parse(pos['avgPrice'].toString()),
              unrealizedPnl: double.parse(pos['unrealPnl'].toString()),
              timestamp: DateTime.now().toString(),
            );
          }
        }
      }
      return positions;
    } catch (e) {
      print('Error getting positions: $e');
      return {};
    }
  }

  Future<void> startBot() async {
    // This would connect to your Flask server
    // For now, just print
    print('Bot started');
  }

  Future<void> stopBot() async {
    // This would connect to your Flask server
    // For now, just print
    print('Bot stopped');
  }

  // ================================================================
  // HELPER METHODS
  // ================================================================
  Map<String, String> _getHeaders(
    String method,
    String path,
    String queryString,
  ) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final recvWindow = '5000';

    String paramsString;
    if (method == 'GET' && queryString.isNotEmpty) {
      paramsString = '$timestamp$apiKey$recvWindow$queryString';
    } else {
      paramsString = '$timestamp$apiKey$recvWindow';
    }

    final signature =
        Hmac(sha256, utf8.encode(apiSecret)).convert(utf8.encode(paramsString));

    return {
      'X-BAPI-SIGN': signature.toString(),
      'X-BAPI-API-KEY': apiKey,
      'X-BAPI-TIMESTAMP': timestamp,
      'X-BAPI-RECV-WINDOW': recvWindow,
      'Content-Type': 'application/json',
    };
  }

  double _calculatePnL(Map<String, Position> positions) {
    double totalPnL = 0;
    for (var pos in positions.values) {
      totalPnL += pos.unrealizedPnl;
    }
    return totalPnL;
  }
}
