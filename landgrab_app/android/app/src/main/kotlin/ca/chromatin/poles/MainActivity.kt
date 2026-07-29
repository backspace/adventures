package ca.chromatin.poles

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (not FlutterActivity) is required by local_auth for
// the biometric prompt on Android.
class MainActivity : FlutterFragmentActivity()
