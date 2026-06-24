import 'package:flutter/material.dart';
import 'api_service.dart';

// ================================================================
// DATA MODELS
// ================================================================
class Trade {
  final String symbol;
  final String direction;
  final double price;
  final double quantity;
  final double? stopLoss;
  final String timestamp;
  final String status;

  Trade({
    required this.symbol,
    required this.direction,
    required this.price,
    required this.quantity,
    this.stopLoss,
    required this.timestamp,
    this.status = 'OPEN',
  });

  factory Trade.fromJson(Map<String, dynamic> json) {
    return Trade(
      symbol: json['symbol'] ?? 'UNKNOWN',
      direction: json['direction'] ?? 'LONG',
      price: (json['price'] ?? 0).toDouble(),
      quantity: (json['qty'] ?? 0).toDouble(),
      stopLoss: json['sl'] != null ? (json['sl']).toDouble() : null,
      timestamp: json['timestamp'] ?? DateTime.now().toString(),
      status: json['status'] ?? 'OPEN',
    );
  }
}

class Position {
  final String symbol;
  final String side;
  final double contracts;
  final double entryPrice;
  final double unrealizedPnl;
  final String timestamp;

  Position({
    required this.symbol,
    required this.side,
    required this.contracts,
    required this.entryPrice,
    required this.unrealizedPnl,
    required this.timestamp,
  });

  factory Position.fromJson(Map<String, dynamic> json) {
    return Position(
      symbol: json['symbol'] ?? 'UNKNOWN',
      side: json['side'] ?? 'long',
      contracts: (json['contracts'] ?? 0).toDouble(),
      entryPrice: (json['entryPrice'] ?? 0).toDouble(),
      unrealizedPnl: (json['unrealizedPnl'] ?? 0).toDouble(),
      timestamp: json['timestamp'] ?? DateTime.now().toString(),
    );
  }
}

class BotStats {
  final double accountBalance;
  final Map<String, Position> openPositions;
  final List<Trade> trades;
  final bool isRunning;
  final String lastUpdate;
  final double totalPnL;

  BotStats({
    required this.accountBalance,
    required this.openPositions,
    required this.trades,
    required this.isRunning,
    required this.lastUpdate,
    required this.totalPnL,
  });

  factory BotStats.fromJson(Map<String, dynamic> json) {
    final positions = <String, Position>{};
    if (json['positions'] is Map) {
      (json['positions'] as Map).forEach((key, value) {
        positions[key] = Position.fromJson(value);
      });
    }

    final trades = <Trade>[];
    if (json['trades'] is List) {
      trades.addAll(
        (json['trades'] as List).map((t) => Trade.fromJson(t)),
      );
    }

    return BotStats(
      accountBalance: (json['account_balance'] ?? 0).toDouble(),
      openPositions: positions,
      trades: trades,
      isRunning: json['running'] ?? false,
      lastUpdate: json['last_update'] ?? '',
      totalPnL: (json['total_pnl'] ?? 0).toDouble(),
    );
  }

  static BotStats empty() {
    return BotStats(
      accountBalance: 0,
      openPositions: {},
      trades: [],
      isRunning: false,
      lastUpdate: '',
      totalPnL: 0,
    );
  }
}

// ================================================================
// TRADING PROVIDER (State Management)
// ================================================================
class TradingProvider extends ChangeNotifier {
  late ApiService _apiService;
  BotStats _stats = BotStats.empty();
  bool _isInitialized = false;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isRunning => _stats.isRunning;
  double get accountBalance => _stats.accountBalance;
  Map<String, Position> get openPositions => _stats.openPositions;
  List<Trade> get trades => _stats.trades;
  double get totalPnL => _stats.totalPnL;

  Future<void> initializeExchange(String apiKey, String apiSecret) async {
    _apiService = ApiService(apiKey: apiKey, apiSecret: apiSecret);
    
    // Test connection
    await _apiService.testConnection();
    
    _isInitialized = true;
    notifyListeners();
    
    // Fetch initial stats
    await refreshStats();
  }

  Future<void> refreshStats() async {
    if (!_isInitialized) return;
    
    try {
      _stats = await _apiService.getStats();
      notifyListeners();
    } catch (e) {
      print('Error refreshing stats: $e');
    }
  }

  Future<void> startBot() async {
    if (!_isInitialized) return;
    
    try {
      await _apiService.startBot();
      _stats = _stats..isRunning;
      notifyListeners();
    } catch (e) {
      print('Error starting bot: $e');
    }
  }

  Future<void> stopBot() async {
    if (!_isInitialized) return;
    
    try {
      await _apiService.stopBot();
      notifyListeners();
    } catch (e) {
      print('Error stopping bot: $e');
    }
  }

  void startAutoUpdate() {
    _startAutoRefresh();
  }

  void stopAutoUpdate() {
    // Cancel auto-refresh timer if needed
  }

  void _startAutoRefresh() {
    Future.delayed(const Duration(seconds: 3), () async {
      if (_isInitialized) {
        await refreshStats();
        _startAutoRefresh();
      }
    });
  }
}

// Extension to create a copy with modified isRunning
extension BotStatsCopy on BotStats {
  BotStats get isRunning => BotStats(
    accountBalance: accountBalance,
    openPositions: openPositions,
    trades: trades,
    isRunning: !this.isRunning,
    lastUpdate: lastUpdate,
    totalPnL: totalPnL,
  );
}
