package com.cruizx.slowride

import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "cruizx/google-maps-view",
            CruizXGoogleMapViewFactory(flutterEngine.dartExecutor.binaryMessenger),
        )
        AndroidAutoStateStore.attachChannel(
            io.flutter.plugin.common.MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                AndroidAutoStateStore.CHANNEL_NAME,
            ),
        )
    }

    override fun onDestroy() {
        AndroidAutoStateStore.detachChannel()
        super.onDestroy()
    }
}
