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
  bool _hasShownInitialDialog = false;

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
      // Just show a snackbar instead of a blocking dialog
      _showNoInternetSnackbar();
    } else {
      // Verify actual internet connectivity with a test request
      final hasInternet = await _hasActualInternetConnection();
      if (!hasInternet) {
        _showNoInternetSnackbar();
      }
    }
  }

  // Public method to manually check connection and show dialog
  Future<bool> checkConnectionAndShowDialog() async {
    final connectivityResult = await _connectivity.checkConnectivity();

    if (connectivityResult == ConnectivityResult.none) {
      // Only show the dialog the first time the app is launched
      if (!_hasShownInitialDialog) {
        _showNoInternetDialog();
        _hasShownInitialDialog = true;
      } else {
        _showNoInternetSnackbar();
      }
      return false;
    } else {
      final hasInternet = await _hasActualInternetConnection();
      if (!hasInternet) {
        // Only show the dialog the first time the app is launched
        if (!_hasShownInitialDialog) {
          _showNoInternetDialog();
          _hasShownInitialDialog = true;
        } else {
          _showNoInternetSnackbar();
        }
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

  // Show a snackbar for no internet connection
  void _showNoInternetSnackbar() {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    // Prevent showing too frequently
    final now = DateTime.now();
    if (_lastDialogTime != null && now.difference(_lastDialogTime!).inSeconds < 30) {
      return;
    }

    _lastDialogTime = now;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'No internet connection.',
          style: TextStyle(fontSize: 14),
        ),
        duration: Duration(seconds: 3),
        backgroundColor: Colors.orange,
      ),
    );
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
                    color: Colors.orange),
                Text('No Internet Connection'),
              ],
            ),
            content: const Text(
              'You are currently offline. You can continue playing with cached puzzles, but leaderboard updates and new puzzles will not be available.',
              style: TextStyle(fontSize: 16),
            ),
            actions: [
              ElevatedButton(
                onPressed: () async {
                  final hasInternet = await _hasActualInternetConnection();
                  // Always close the dialog
                  Navigator.of(context).pop();
                  _isDialogShowing = false;
                  
                  if (hasInternet) {
                    // Show a success message
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Connected to the internet. Full features available.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    // Show a warning but allow continuing
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Still no internet connection. Using cached data only.'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                },
                child: const Text('Check Again'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _isDialogShowing = false;
                },
                child: const Text('Continue Offline'),
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
