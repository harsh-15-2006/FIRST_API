package com.example.scam_safety_app
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val callMergingModule = CallMergingModule(this)
        callMergingModule.setupMethodChannel(flutterEngine)
    }
}