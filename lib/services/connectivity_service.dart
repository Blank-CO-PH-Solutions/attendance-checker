import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final Connectivity _connectivity = Connectivity();

  static Future<bool> checkConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    return result.isNotEmpty && !result.contains(ConnectivityResult.none);
  }

  static Stream<List<ConnectivityResult>> get connectivityStream =>
      _connectivity.onConnectivityChanged;

  static StreamSubscription<List<ConnectivityResult>> listen({
    required void Function(bool isOnline) onChanged,
  }) {
    return _connectivity.onConnectivityChanged.listen((result) {
      final isOnline = result.isNotEmpty && !result.contains(ConnectivityResult.none);
      onChanged(isOnline);
    });
  }
}
