import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final _connectivity = Connectivity();
  final _controller = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isOnline = true;

  bool get isOnline => _isOnline;
  Stream<bool> get onConnectivityChanged => _controller.stream;

  Future<void> initialize() async {
    final results = await _connectivity.checkConnectivity();
    _isOnline = _anyConnected(results);
    _controller.add(_isOnline);

    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final online = _anyConnected(results);
      if (online != _isOnline) {
        _isOnline = online;
        _controller.add(_isOnline);
      }
    });
  }

  bool _anyConnected(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}
