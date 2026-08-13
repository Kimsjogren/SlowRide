package com.cruizx.slowride

import android.content.pm.ApplicationInfo
import androidx.car.app.CarAppService
import androidx.car.app.Screen
import androidx.car.app.Session
import androidx.car.app.SessionInfo
import androidx.car.app.validation.HostValidator
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner

class CruizXCarAppService : CarAppService() {
    override fun onCreate() {
        super.onCreate()
        AndroidAutoStateStore.initialize(applicationContext)
    }

    override fun onCreateSession(sessionInfo: SessionInfo): Session = CruizXCarSession()

    override fun createHostValidator(): HostValidator =
        if (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0) {
            HostValidator.ALLOW_ALL_HOSTS_VALIDATOR
        } else {
            HostValidator.Builder(applicationContext)
                .addAllowedHosts(androidx.car.app.R.array.hosts_allowlist_sample)
                .build()
        }
}

private class CruizXCarSession : Session() {
    private lateinit var renderer: CruizXAutoMapRenderer
    private lateinit var rootScreen: CruizXNavigationScreen

    override fun onCreateScreen(intent: android.content.Intent): Screen {
        renderer = CruizXAutoMapRenderer(carContext)
        rootScreen = CruizXNavigationScreen(carContext, renderer)
        AndroidAutoStateStore.setConnected(true)
        lifecycle.addObserver(object : DefaultLifecycleObserver {
            override fun onDestroy(owner: LifecycleOwner) {
                renderer.destroy()
                AndroidAutoStateStore.setConnected(false)
            }
        })
        return rootScreen
    }

    override fun onCarConfigurationChanged(newConfiguration: android.content.res.Configuration) {
        super.onCarConfigurationChanged(newConfiguration)
        if (::renderer.isInitialized) renderer.refreshTheme()
    }

}
