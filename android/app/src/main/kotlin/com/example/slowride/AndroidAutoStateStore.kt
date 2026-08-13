package com.cruizx.slowride

import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.CopyOnWriteArraySet

object AndroidAutoStateStore {
    const val CHANNEL_NAME = "cruizx/carplay"

    data class Snapshot(
        val destinations: Map<String, Any?> = emptyMap(),
        val navigation: Map<String, Any?> = emptyMap(),
        val route: Map<String, Any?> = emptyMap(),
        val convoy: Map<String, Any?> = emptyMap(),
    )

    private val mainHandler = Handler(Looper.getMainLooper())
    private val listeners = CopyOnWriteArraySet<(Snapshot) -> Unit>()
    private var channel: MethodChannel? = null
    private var applicationContext: Context? = null
    private var pendingFlutterCalls = mutableListOf<Pair<String, Any?>>()

    @Volatile
    var isConnected: Boolean = false
        private set

    @Volatile
    var snapshot = Snapshot()
        private set

    fun initialize(context: Context) {
        applicationContext = context.applicationContext
    }

    fun attachChannel(value: MethodChannel) {
        channel = value
        value.setMethodCallHandler { call, result ->
            when (call.method) {
                "syncState", "syncNavigationState", "syncRouteGeometry", "syncConvoyState" -> {
                    @Suppress("UNCHECKED_CAST")
                    update(
                        call.method,
                        call.arguments as? Map<String, Any?> ?: emptyMap(),
                    )
                    result.success(null)
                }
                "getConnectionState" -> result.success(isConnected)
                else -> result.notImplemented()
            }
        }
        sendToFlutter("carPlayConnectionChanged", isConnected)
        val pending = pendingFlutterCalls.toList()
        pendingFlutterCalls.clear()
        pending.forEach { (method, arguments) -> sendToFlutter(method, arguments) }
    }

    fun detachChannel() {
        channel = null
    }

    fun setConnected(connected: Boolean) {
        isConnected = connected
        sendToFlutter("carPlayConnectionChanged", connected)
    }

    fun update(method: String, payload: Map<String, Any?>) {
        snapshot = when (method) {
            "syncState" -> snapshot.copy(destinations = payload)
            "syncNavigationState" -> snapshot.copy(navigation = payload)
            "syncRouteGeometry" -> snapshot.copy(route = payload)
            "syncConvoyState" -> snapshot.copy(convoy = payload)
            else -> snapshot
        }
        listeners.forEach { listener -> mainHandler.post { listener(snapshot) } }
    }

    fun addListener(listener: (Snapshot) -> Unit) {
        listeners.add(listener)
        mainHandler.post { listener(snapshot) }
    }

    fun removeListener(listener: (Snapshot) -> Unit) {
        listeners.remove(listener)
    }

    fun startNavigation(latitude: Double, longitude: Double, label: String, address: String) {
        sendOrQueue(
            "startNavigation",
            mapOf(
                "lat" to latitude,
                "lon" to longitude,
                "label" to label,
                "address" to address,
                "startImmediately" to true,
            ),
        )
    }

    fun stopNavigation() {
        sendOrQueue("stopNavigation", null)
    }

    private fun sendOrQueue(method: String, arguments: Any?) {
        if (channel == null) {
            pendingFlutterCalls.add(method to arguments)
            applicationContext?.startActivity(
                Intent(applicationContext, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                },
            )
        } else {
            sendToFlutter(method, arguments)
        }
    }

    private fun sendToFlutter(method: String, arguments: Any?) {
        mainHandler.post { channel?.invokeMethod(method, arguments) }
    }
}
