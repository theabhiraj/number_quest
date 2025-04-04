import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;

  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _subscription;
  bool _isDialogShowing = false;
  DateTime? _lastDialogTime;

  // Holds the context from the app's navigatorKey
  late GlobalKey<NavigatorState> navigatorKey;

  // Initialize connectivity monitoring
  void initialize(GlobalKey<NavigatorState> key) {
    navigatorKey = key;
    _startMonitoring();
  }

  // Start monitoring connectivity changes
  void _startMonitoring() {
    _subscription =
        _connectivity.onConnectivityChanged.listen(_checkInternetConnection);

    // Check connection immediately on start
    checkConnectionAndShowDialog();
  }

  // Check internet connection when connectivity status changes
  Future<void> _checkInternetConnection(ConnectivityResult result) async {
    if (result == ConnectivityResult.none) {
      _showNoInternetDialog();
    } else {
      // Verify actual internet connectivity with a test request
      final hasInternet = await _hasActualInternetConnection();
      if (!hasInternet) {
        _showNoInternetDialog();
      }
    }
  }

  // Public method to manually check connection and show dialog
  Future<bool> checkConnectionAndShowDialog() async {
    final connectivityResult = await _connectivity.checkConnectivity();

    if (connectivityResult == ConnectivityResult.none) {
      _showNoInternetDialog();
      return false;
    } else {
      final hasInternet = await _hasActualInternetConnection();
      if (!hasInternet) {
        _showNoInternetDialog();
        return false;
      }
      return true;
    }
  }

  // Public method to check connection without showing dialog
  Future<bool> checkConnection() async {
    final connectivityResult = await _connectivity.checkConnectivity();

    if (connectivityResult == ConnectivityResult.none) {
      return false;
    } else {
      return await _hasActualInternetConnection();
    }
  }

  // Verify actual internet connectivity by making a test request
  Future<bool> _hasActualInternetConnection() async {
    try {
      final response = await http
          .get(
            Uri.parse('https://www.google.com'),
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Show no internet dialog if not already showing
  void _showNoInternetDialog() {
    // Get current context from navigator key
    final context = navigatorKey.currentContext;
    if (context == null) return;

    // Prevent multiple dialogs - only show once per minute
    final now = DateTime.now();
    if (_isDialogShowing ||
        (_lastDialogTime != null &&
            now.difference(_lastDialogTime!).inSeconds < 60)) {
      return;
    }

    _isDialogShowing = true;
    _lastDialogTime = now;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false, // Prevent dialog dismiss on back button
          child: AlertDialog(
            title: Wrap(
              spacing: 8,
              children: const [
                Icon(Icons.signal_wifi_connected_no_internet_4,
                    color: Colors.red),
                Text('No Internet Connection'),
              ],
            ),
            content: const Text(
              'Please connect to the internet to use Number Quest. The app requires an internet connection.',
              style: TextStyle(fontSize: 16),
            ),
            actions: [
              ElevatedButton(
                onPressed: () async {
                  final hasInternet = await _hasActualInternetConnection();
                  if (hasInternet) {
                    Navigator.of(context).pop();
                    _isDialogShowing = false;
                  } else {
                    // Vibrate or show feedback that internet is still unavailable
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Still no internet connection. Please check your settings.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: const Text('Check Again'),
              ),
            ],
          ),
        );
      },
    ).then((_) {
      _isDialogShowing = false;
    });
  }

  // Dispose of resources
  void dispose() {
    _subscription?.cancel();
  }
}
