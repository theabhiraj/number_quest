import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    // Replace these values with the ones from your google-services.json
    return const FirebaseOptions(
      apiKey: 'AIzaSyBUmahAwaOTJ-fFyeix7MT0i5mLhBFSmRA',
      appId: '1:334115018441:android:1e1629bd7005dee2865f18',
      messagingSenderId: '334115018441',
      projectId: 'numberquests',
      databaseURL: 'https://numberquests-default-rtdb.asia-southeast1.firebasedatabase.app',
      storageBucket: 'numberquests.firebasestorage.app',
    );
  }
} 
