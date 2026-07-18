package com.example.scam_safety_app

import android.content.Context
import android.media.AudioManager
import android.telecom.TelecomManager
import android.telephony.TelephonyManager
import android.os.Build
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class CallMergingModule(private val context: Context ) {
    
    companion object {
        private const val CHANNEL = "com.example.scam_safety_app/call_merging"
        private const val TAG = "CallMergingModule"
        private const val TWILIO_RECORDING_NUMBER = "+12768776132"
    }
    
    private val audioManager: AudioManager = 
        context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val telecomManager: TelecomManager? = 
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            context.getSystemService(Context.TELECOM_SERVICE) as TelecomManager
        } else null
    
    private var isCallMerging = false
    private var recordingCallId: String? = null
    
    fun setupMethodChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startCallMerging" -> {
                        val incomingNumber = call.argument<String>("incomingNumber")
                        val recordingServiceNumber = call.argument<String>("recordingNumber")
                            ?: TWILIO_RECORDING_NUMBER
                        
                        startCallMerging(incomingNumber, recordingServiceNumber, result)
                    }
                    "stopCallMerging" -> {
                        stopCallMerging(result)
                    }
                    "setSpeakerphone" -> {                       
(Content truncated due to size limit. Use line ranges to read remaining content)
