import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

// SRS Section 6.5: Network resilience and graceful disconnection handling
// SRS Section 6.1: Performance under varying network conditions
class NetworkService {
  final Connectivity _connectivity = Connectivity();
  StreamController<NetworkStatus>? _networkStatusController;
  StreamSubscription<dynamic>? _connectivitySubscription;

  NetworkService() {
    _networkStatusController = StreamController<NetworkStatus>.broadcast();
    _init();
  }

  void _init() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      dynamic result,
    ) {
      final status = result is List<ConnectivityResult>
          ? _getNetworkStatusFromList(result)
          : _getNetworkStatus(result as ConnectivityResult);
      _networkStatusController?.add(status);
    });
  }

  NetworkStatus _getNetworkStatus(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.mobile:
        return NetworkStatus.mobile;
      case ConnectivityResult.wifi:
        return NetworkStatus.wifi;
      case ConnectivityResult.ethernet:
        return NetworkStatus.ethernet;
      case ConnectivityResult.none:
        return NetworkStatus.offline;
      default:
        return NetworkStatus.offline;
    }
  }

  NetworkStatus _getNetworkStatusFromList(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.wifi)) return NetworkStatus.wifi;
    if (results.contains(ConnectivityResult.ethernet)) {
      return NetworkStatus.ethernet;
    }
    if (results.contains(ConnectivityResult.mobile)) {
      return NetworkStatus.mobile;
    }
    if (results.contains(ConnectivityResult.none)) return NetworkStatus.offline;
    return NetworkStatus.offline;
  }

  // SRS Section 6.5: Check current network status
  Future<NetworkStatus> getCurrentStatus() async {
    final result = await _connectivity.checkConnectivity();
    return _getNetworkStatusFromList(result);
      return _getNetworkStatus(result as ConnectivityResult);
  }

  // SRS Section 6.5: Stream of network status changes
  Stream<NetworkStatus> get networkStatusStream =>
      _networkStatusController?.stream ?? const Stream.empty();

  // SRS Section 6.1: Check if network is available
  Future<bool> isOnline() async {
    final status = await getCurrentStatus();
    return status != NetworkStatus.offline;
  }

  // SRS Section 6.1: Get network type for bandwidth optimization
  Future<NetworkType> getNetworkType() async {
    final status = await getCurrentStatus();
    switch (status) {
      case NetworkStatus.wifi:
      case NetworkStatus.ethernet:
        return NetworkType.highBandwidth;
      case NetworkStatus.mobile:
        return NetworkType.lowBandwidth;
      case NetworkStatus.offline:
        return NetworkType.offline;
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _networkStatusController?.close();
  }
}

enum NetworkStatus { wifi, mobile, ethernet, offline }

enum NetworkType { highBandwidth, lowBandwidth, offline }

// SRS Section 6.5: Retry mechanism for network operations
class RetryHandler {
  static Future<T> retry<T>({
    required Future<T> Function() operation,
    int maxRetries = 3,
    Duration delay = const Duration(seconds: 2),
  }) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        return await operation();
      } catch (e) {
        attempts++;
        if (attempts >= maxRetries) {
          rethrow;
        }
        await Future.delayed(delay * attempts); // Exponential backoff
      }
    }
    throw Exception('Max retries exceeded');
  }
}
