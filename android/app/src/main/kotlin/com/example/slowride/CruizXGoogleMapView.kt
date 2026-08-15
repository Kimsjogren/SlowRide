package com.cruizx.slowride

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.view.View
import android.view.animation.LinearInterpolator
import com.google.android.gms.maps.CameraUpdateFactory
import com.google.android.gms.maps.GoogleMap
import com.google.android.gms.maps.MapView
import com.google.android.gms.maps.MapsInitializer
import com.google.android.gms.maps.OnMapReadyCallback
import com.google.android.gms.maps.model.BitmapDescriptorFactory
import com.google.android.gms.maps.model.CameraPosition
import com.google.android.gms.maps.model.LatLng
import com.google.android.gms.maps.model.LatLngBounds
import com.google.android.gms.maps.model.MapStyleOptions
import com.google.android.gms.maps.model.Marker
import com.google.android.gms.maps.model.MarkerOptions
import com.google.android.gms.maps.model.Polyline
import com.google.android.gms.maps.model.PolylineOptions
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import io.flutter.plugin.common.StandardMessageCodec
import kotlin.math.asin
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.sin

class CruizXGoogleMapViewFactory(
    private val messenger: BinaryMessenger,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
        CruizXGoogleMapView(context, viewId, messenger)
}

private class CruizXGoogleMapView(
    private val context: Context,
    viewId: Int,
    messenger: BinaryMessenger,
) : PlatformView, OnMapReadyCallback, MethodChannel.MethodCallHandler {
    private val mapView = MapView(context)
    private val channel = MethodChannel(messenger, "cruizx/google_maps_view_$viewId")
    private var googleMap: GoogleMap? = null
    private var pendingState: Map<String, Any?>? = null
    private var location: LatLng? = null
    private var heading = 0f
    private var followUser = false
    private var use3D = true
    private var darkMode = false
    private var userMarker: Marker? = null
    private var destinationMarker: Marker? = null
    private var routePolyline: Polyline? = null
    private var markerAnimator: ValueAnimator? = null
    private var lastRoute: List<LatLng> = emptyList()
    private var renderedHeading = 0f
    private var targetLocation: LatLng? = null
    private var hasCenteredOnUser = false

    init {
        MapsInitializer.initialize(context, MapsInitializer.Renderer.LATEST) {}
        mapView.onCreate(null)
        mapView.onResume()
        mapView.getMapAsync(this)
        channel.setMethodCallHandler(this)
    }

    override fun getView(): View = mapView

    override fun dispose() {
        markerAnimator?.cancel()
        channel.setMethodCallHandler(null)
        mapView.onPause()
        mapView.onDestroy()
    }

    override fun onMapReady(map: GoogleMap) {
        googleMap = map
        map.mapType = GoogleMap.MAP_TYPE_NORMAL
        map.isTrafficEnabled = false
        map.isIndoorEnabled = false
        map.uiSettings.isCompassEnabled = false
        map.uiSettings.isMapToolbarEnabled = false
        map.uiSettings.isMyLocationButtonEnabled = false
        map.uiSettings.isZoomControlsEnabled = false
        map.setPadding(0, 0, 0, 0)
        map.setOnMapClickListener { point ->
            channel.invokeMethod(
                "mapTapped",
                mapOf("latitude" to point.latitude, "longitude" to point.longitude),
            )
        }
        map.setOnCameraMoveStartedListener { reason ->
            if (reason == GoogleMap.OnCameraMoveStartedListener.REASON_GESTURE && followUser) {
                channel.invokeMethod("userPanned", null)
            }
        }
        pendingState?.let(::applyState)
        pendingState = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setState" -> {
                @Suppress("UNCHECKED_CAST")
                val payload = call.arguments as? Map<String, Any?> ?: emptyMap()
                if (googleMap == null) pendingState = payload else applyState(payload)
                result.success(null)
            }
            "setHeading" -> {
                @Suppress("UNCHECKED_CAST")
                val payload = call.arguments as? Map<String, Any?>
                heading = number(payload?.get("heading"))?.toFloat() ?: heading
                updateUserMarker(targetLocation ?: location)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun applyState(payload: Map<String, Any?>) {
        val map = googleMap ?: return
        val newLocation = coordinate(payload["location"])
        val destination = coordinate(payload["destination"])
        val route = coordinates(payload["routePoints"])
        val newFollowUser = payload["followUser"] as? Boolean ?: false
        val newUse3D = payload["use3D"] as? Boolean ?: true
        val newDarkMode = payload["darkMode"] as? Boolean ?: false
        val routeChanged = !sameRoute(route, lastRoute)
        val followChanged = followUser != newFollowUser

        followUser = newFollowUser
        use3D = newUse3D
        if (darkMode != newDarkMode) {
            darkMode = newDarkMode
            map.setMapStyle(
                if (darkMode) MapStyleOptions.loadRawResourceStyle(context, R.raw.cruizx_map_dark)
                else null,
            )
        }

        updateUserMarker(newLocation)
        updateDestination(destination)
        if (routeChanged) updateRoute(route)

        when {
            followUser && newLocation != null -> {
                hasCenteredOnUser = true
                updateFollowCamera(newLocation)
            }
            routeChanged && route.size >= 2 -> fitRoute(route)
            !hasCenteredOnUser && newLocation != null && route.isEmpty() -> {
                // Match iOS: the first valid GPS fix must leave the neutral
                // world view even before the user explicitly enables follow.
                // Use an immediate move so a closely following state payload
                // cannot cancel the initial camera animation.
                hasCenteredOnUser = true
                map.moveCamera(CameraUpdateFactory.newLatLngZoom(newLocation, 16f))
            }
            followChanged && newLocation != null -> {
                map.animateCamera(CameraUpdateFactory.newLatLngZoom(newLocation, 16f))
            }
        }
        location = newLocation
        lastRoute = route
    }

    private fun updateUserMarker(target: LatLng?) {
        if (target == null) return
        targetLocation = target
        val existing = userMarker
        if (existing == null) {
            userMarker = googleMap?.addMarker(
                MarkerOptions()
                    .position(target)
                    .anchor(0.5f, 0.58f)
                    .flat(true)
                    .rotation(heading)
                    .zIndex(20f)
                    .icon(BitmapDescriptorFactory.fromBitmap(navigationMarkerBitmap())),
            )
            renderedHeading = normalizedHeading(heading)
            if (followUser) updateFollowCamera(target, renderedHeading)
            return
        }

        val start = existing.position
        val startHeading = renderedHeading
        val headingDelta = shortestHeadingDelta(startHeading, heading)
        markerAnimator?.cancel()
        markerAnimator = ValueAnimator.ofFloat(0f, 1f).apply {
            // Location fixes arrive roughly every 250-1000 ms. Interpolating
            // position and bearing together prevents the map and marker from
            // taking separate visible steps between fixes.
            duration = if (followUser) 420 else 300
            interpolator = LinearInterpolator()
            addUpdateListener { animator ->
                val fraction = animator.animatedFraction.toDouble()
                val rendered = LatLng(
                    start.latitude + (target.latitude - start.latitude) * fraction,
                    start.longitude + (target.longitude - start.longitude) * fraction,
                )
                renderedHeading = normalizedHeading(
                    startHeading + headingDelta * fraction.toFloat(),
                )
                existing.position = rendered
                // A flat Google Maps marker must carry the same bearing as the
                // heading-up camera to remain visually straight ahead.
                existing.rotation = renderedHeading
                if (followUser) updateFollowCamera(rendered, renderedHeading)
            }
            start()
        }
    }

    private fun updateDestination(target: LatLng?) {
        if (target == null) {
            destinationMarker?.remove()
            destinationMarker = null
            return
        }
        val existing = destinationMarker
        if (existing == null) {
            destinationMarker = googleMap?.addMarker(
                MarkerOptions().position(target).title("Mål").zIndex(10f),
            )
        } else {
            existing.position = target
        }
    }

    private fun updateRoute(points: List<LatLng>) {
        routePolyline?.remove()
        routePolyline = null
        if (points.size < 2) return
        routePolyline = googleMap?.addPolyline(
            PolylineOptions()
                .addAll(points)
                .color(Color.rgb(20, 145, 255))
                .width(16f)
                .geodesic(true)
                .zIndex(5f),
        )
    }

    private fun updateFollowCamera(position: LatLng?, cameraHeading: Float = renderedHeading) {
        val map = googleMap ?: return
        val current = position ?: return
        val target = offset(current, if (use3D) 170.0 else 80.0, cameraHeading.toDouble())
        val camera = CameraPosition.Builder()
            .target(target)
            .zoom(if (use3D) 17.4f else 16.8f)
            .bearing(cameraHeading)
            .tilt(if (use3D) 58f else 0f)
            .build()
        map.moveCamera(CameraUpdateFactory.newCameraPosition(camera))
    }

    private fun normalizedHeading(value: Float): Float = ((value % 360f) + 360f) % 360f

    private fun shortestHeadingDelta(from: Float, to: Float): Float =
        ((to - from + 540f) % 360f) - 180f

    private fun fitRoute(points: List<LatLng>) {
        val map = googleMap ?: return
        if (mapView.width == 0 || mapView.height == 0) {
            mapView.post { fitRoute(points) }
            return
        }
        val bounds = LatLngBounds.Builder().apply { points.forEach(::include) }.build()
        map.animateCamera(CameraUpdateFactory.newLatLngBounds(bounds, 90))
    }

    private fun navigationMarkerBitmap(): Bitmap {
        val density = context.resources.displayMetrics.density
        val size = (52 * density).toInt()
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val center = size / 2f
        val path = Path().apply {
            moveTo(center, size * 0.10f)
            lineTo(size * 0.82f, size * 0.82f)
            lineTo(center, size * 0.68f)
            lineTo(size * 0.18f, size * 0.82f)
            close()
        }
        val outline = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            style = Paint.Style.STROKE
            strokeWidth = 5 * density
            strokeJoin = Paint.Join.ROUND
            setShadowLayer(5 * density, 0f, 3 * density, Color.BLACK)
        }
        canvas.drawPath(path, outline)
        val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(0, 185, 255)
            style = Paint.Style.FILL
        }
        canvas.drawPath(path, fill)
        return bitmap
    }

    private fun coordinate(value: Any?): LatLng? {
        @Suppress("UNCHECKED_CAST")
        val data = value as? Map<String, Any?> ?: return null
        val latitude = number(data["latitude"] ?: data["lat"]) ?: return null
        val longitude = number(data["longitude"] ?: data["lon"]) ?: return null
        return LatLng(latitude, longitude)
    }

    private fun coordinates(value: Any?): List<LatLng> =
        (value as? List<*>)?.mapNotNull(::coordinate) ?: emptyList()

    private fun number(value: Any?): Double? = when (value) {
        is Number -> value.toDouble()
        is String -> value.toDoubleOrNull()
        else -> null
    }

    private fun sameRoute(a: List<LatLng>, b: List<LatLng>): Boolean {
        if (a.size != b.size) return false
        if (a.isEmpty()) return true
        val indices = setOf(0, a.lastIndex / 2, a.lastIndex)
        return indices.all { index ->
            a[index].latitude == b[index].latitude && a[index].longitude == b[index].longitude
        }
    }

    private fun offset(origin: LatLng, distanceMeters: Double, bearingDegrees: Double): LatLng {
        val radius = 6_371_000.0
        val distance = distanceMeters / radius
        val bearing = Math.toRadians(bearingDegrees)
        val latitude = Math.toRadians(origin.latitude)
        val longitude = Math.toRadians(origin.longitude)
        val targetLatitude = asin(
            sin(latitude) * cos(distance) + cos(latitude) * sin(distance) * cos(bearing),
        )
        val targetLongitude = longitude + atan2(
            sin(bearing) * sin(distance) * cos(latitude),
            cos(distance) - sin(latitude) * sin(targetLatitude),
        )
        return LatLng(Math.toDegrees(targetLatitude), Math.toDegrees(targetLongitude))
    }
}
