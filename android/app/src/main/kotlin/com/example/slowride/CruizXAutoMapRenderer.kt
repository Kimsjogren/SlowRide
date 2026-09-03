package com.cruizx.slowride

import android.app.Presentation
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Rect
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.widget.FrameLayout
import androidx.car.app.AppManager
import androidx.car.app.CarContext
import androidx.car.app.SurfaceCallback
import androidx.car.app.SurfaceContainer
import com.google.android.gms.maps.CameraUpdateFactory
import com.google.android.gms.maps.GoogleMap
import com.google.android.gms.maps.MapView
import com.google.android.gms.maps.MapsInitializer
import com.google.android.gms.maps.model.BitmapDescriptorFactory
import com.google.android.gms.maps.model.CameraPosition
import com.google.android.gms.maps.model.LatLng
import com.google.android.gms.maps.model.LatLngBounds
import com.google.android.gms.maps.model.MapStyleOptions
import com.google.android.gms.maps.model.Marker
import com.google.android.gms.maps.model.MarkerOptions
import com.google.android.gms.maps.model.Polyline
import com.google.android.gms.maps.model.PolylineOptions
import kotlin.math.asin
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.sin

class CruizXAutoMapRenderer(private val carContext: CarContext) : SurfaceCallback {
    private var virtualDisplay: VirtualDisplay? = null
    private var presentation: Presentation? = null
    private var mapView: MapView? = null
    private var googleMap: GoogleMap? = null
    private var speedGauge: CruizXSpeedGaugeView? = null
    private var userMarker: Marker? = null
    private var destinationMarker: Marker? = null
    private var routePolyline: Polyline? = null
    private val trafficPolylines = mutableListOf<Polyline>()
    private var renderedRoute: List<LatLng> = emptyList()
    private var renderedTrafficSections: List<TrafficSection> = emptyList()
    private val convoyMarkers = mutableMapOf<String, Marker>()
    private var visibleArea = Rect()
    private var snapshot = AndroidAutoStateStore.snapshot
    private val stateListener: (AndroidAutoStateStore.Snapshot) -> Unit = {
        snapshot = it
        applySnapshot()
    }

    init {
        MapsInitializer.initialize(carContext, MapsInitializer.Renderer.LATEST) {}
        carContext.getCarService(AppManager::class.java).setSurfaceCallback(this)
        AndroidAutoStateStore.addListener(stateListener)
    }

    override fun onSurfaceAvailable(surfaceContainer: SurfaceContainer) {
        destroySurface()
        val manager = carContext.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
        val display = manager.createVirtualDisplay(
            "CruizX Android Auto map",
            surfaceContainer.width,
            surfaceContainer.height,
            surfaceContainer.dpi,
            surfaceContainer.surface,
            0,
        ) ?: return
        virtualDisplay = display
        val createdPresentation = Presentation(carContext, display.display)
        presentation = createdPresentation

        val root = FrameLayout(createdPresentation.context)
        val map = MapView(createdPresentation.context)
        mapView = map
        map.onCreate(Bundle())
        map.onStart()
        map.onResume()
        root.addView(
            map,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            ),
        )

        val gauge = CruizXSpeedGaugeView(createdPresentation.context)
        speedGauge = gauge
        val density = createdPresentation.context.resources.displayMetrics.density
        root.addView(
            gauge,
            FrameLayout.LayoutParams((58 * density).toInt(), (112 * density).toInt()).apply {
                gravity = Gravity.TOP or Gravity.END
                topMargin = (94 * density).toInt()
                marginEnd = (18 * density).toInt()
            },
        )
        createdPresentation.setContentView(root)
        createdPresentation.show()
        map.getMapAsync { readyMap ->
            googleMap = readyMap
            configureMap(readyMap)
            applySnapshot()
        }
    }

    override fun onSurfaceDestroyed(surfaceContainer: SurfaceContainer) = destroySurface()

    override fun onVisibleAreaChanged(visibleArea: Rect) {
        this.visibleArea = Rect(visibleArea)
        applyPadding()
    }

    override fun onStableAreaChanged(stableArea: Rect) {
        if (visibleArea.isEmpty) visibleArea = Rect(stableArea)
        applyPadding()
    }

    override fun onScroll(distanceX: Float, distanceY: Float) {
        googleMap?.moveCamera(CameraUpdateFactory.scrollBy(distanceX, distanceY))
    }

    override fun onScale(focusX: Float, focusY: Float, scaleFactor: Float) {
        val zoom = if (scaleFactor > 1f) 0.5f else -0.5f
        googleMap?.animateCamera(CameraUpdateFactory.zoomBy(zoom))
    }

    override fun onFling(velocityX: Float, velocityY: Float) {
        googleMap?.animateCamera(CameraUpdateFactory.scrollBy(-velocityX * 0.12f, -velocityY * 0.12f))
    }

    fun refreshTheme() {
        googleMap?.setMapStyle(
            if (carContext.isDarkMode) {
                MapStyleOptions.loadRawResourceStyle(carContext, R.raw.cruizx_map_dark)
            } else {
                null
            },
        )
    }

    fun recenter() {
        updateFollowCamera(animated = true)
    }

    fun overview() {
        val points = routePoints()
        if (points.size >= 2) fitPoints(points) else showAllConvoyMembers()
    }

    fun showAllConvoyMembers() {
        val members = convoyMembers().mapNotNull { coordinate(it) }.toMutableList()
        currentLocation()?.let(members::add)
        if (members.isNotEmpty()) fitPoints(members)
    }

    fun focusOn(latitude: Double, longitude: Double) {
        googleMap?.animateCamera(CameraUpdateFactory.newLatLngZoom(LatLng(latitude, longitude), 16.5f))
    }

    fun destroy() {
        AndroidAutoStateStore.removeListener(stateListener)
        carContext.getCarService(AppManager::class.java).setSurfaceCallback(null)
        destroySurface()
    }

    private fun configureMap(map: GoogleMap) {
        map.mapType = GoogleMap.MAP_TYPE_NORMAL
        map.isTrafficEnabled = false
        map.isIndoorEnabled = false
        map.uiSettings.isCompassEnabled = false
        map.uiSettings.isMapToolbarEnabled = false
        map.uiSettings.isMyLocationButtonEnabled = false
        map.uiSettings.isZoomControlsEnabled = false
        refreshTheme()
        applyPadding()
    }

    private fun applyPadding() {
        val map = googleMap ?: return
        if (visibleArea.isEmpty) return
        val view = mapView ?: return
        val right = max(0, view.width - visibleArea.right)
        val bottom = max(0, view.height - visibleArea.bottom)
        map.setPadding(visibleArea.left, visibleArea.top, right, bottom)
        speedGauge?.let { gauge ->
            val density = gauge.resources.displayMetrics.density
            (gauge.layoutParams as? FrameLayout.LayoutParams)?.let { params ->
                params.topMargin = visibleArea.top + (20 * density).toInt()
                params.marginEnd = right + (18 * density).toInt()
                gauge.layoutParams = params
            }
        }
    }

    private fun applySnapshot() {
        val map = googleMap ?: return
        val navigation = snapshot.navigation
        val navigating = navigation["isNavigating"] as? Boolean ?: false
        val location = currentLocation()
        val heading = number(navigation["headingDegrees"] ?: snapshot.convoy["headingDegrees"])?.toFloat() ?: 0f

        if (location != null) {
            val icon = if (navigating) navigationArrowBitmap() else locationDotBitmap()
            val marker = userMarker
            if (marker == null) {
                userMarker = map.addMarker(
                    MarkerOptions()
                        .position(location)
                        .flat(true)
                        .anchor(0.5f, 0.58f)
                        .rotation(if (navigating) heading else 0f)
                        .zIndex(30f)
                        .icon(BitmapDescriptorFactory.fromBitmap(icon)),
                )
            } else {
                marker.position = location
                marker.rotation = if (navigating) heading else 0f
                marker.setIcon(BitmapDescriptorFactory.fromBitmap(icon))
            }
        }

        val route = routePoints()
        map.isTrafficEnabled = route.size >= 2
        if (route != renderedRoute) {
            routePolyline?.remove()
            routePolyline = if (route.size >= 2) {
                map.addPolyline(
                    PolylineOptions().addAll(route).color(Color.rgb(25, 145, 255)).width(16f).zIndex(5f),
                )
            } else {
                null
            }
            renderedRoute = route
        }
        val trafficSections = trafficSections()
        if (trafficSections != renderedTrafficSections) {
            trafficPolylines.forEach(Polyline::remove)
            trafficPolylines.clear()
            trafficSections.forEach { section ->
                val color = when (section.level) {
                    "severe" -> Color.rgb(140, 0, 22)
                    "heavy" -> Color.rgb(235, 20, 31)
                    else -> Color.rgb(255, 143, 0)
                }
                map.addPolyline(
                    PolylineOptions().addAll(section.points).color(color).width(18f).zIndex(6f),
                ).let(trafficPolylines::add)
            }
            renderedTrafficSections = trafficSections
        }

        @Suppress("UNCHECKED_CAST")
        val destinationData = navigation["destination"] as? Map<String, Any?>
        val destination = coordinate(destinationData)
        if (destination == null) {
            destinationMarker?.remove()
            destinationMarker = null
        } else if (destinationMarker == null) {
            destinationMarker = map.addMarker(MarkerOptions().position(destination).title("Mål"))
        } else {
            destinationMarker?.position = destination
        }

        updateConvoyMarkers()
        speedGauge?.update(
            speed = number(navigation["currentSpeed"]) ?: 0.0,
            roadLimit = number(navigation["roadSpeedLimit"]),
            vehicleLimit = number(navigation["vehicleSpeedLimit"]),
            unit = navigation["speedUnitLabel"]?.toString() ?: "km/h",
            visible = navigating,
        )

        if (navigating && location != null) updateFollowCamera(animated = false)
    }

    private fun updateConvoyMarkers() {
        val map = googleMap ?: return
        val members = convoyMembers()
        val ids = members.mapNotNull { it["userId"]?.toString() }.toSet()
        convoyMarkers.keys.filterNot(ids::contains).forEach { id -> convoyMarkers.remove(id)?.remove() }
        members.forEach { member ->
            val id = member["userId"]?.toString() ?: return@forEach
            val point = coordinate(member) ?: return@forEach
            val icon = convoyBitmap(member)
            val existing = convoyMarkers[id]
            if (existing == null) {
                convoyMarkers[id] = map.addMarker(
                    MarkerOptions()
                        .position(point)
                        .title(member["label"]?.toString() ?: "Deltagare")
                        .flat(true)
                        .anchor(0.5f, 0.5f)
                        .zIndex(20f)
                        .icon(BitmapDescriptorFactory.fromBitmap(icon)),
                ) ?: return@forEach
            } else {
                val old = existing.position
                existing.rotation = bearing(old, point).toFloat()
                existing.position = point
                existing.setIcon(BitmapDescriptorFactory.fromBitmap(icon))
            }
        }
    }

    private fun updateFollowCamera(animated: Boolean) {
        val map = googleMap ?: return
        val location = currentLocation() ?: return
        val heading = number(snapshot.navigation["headingDegrees"])?.toFloat() ?: 0f
        val target = offset(offset(location, 68.0, heading.toDouble()), 88.0, heading + 90.0)
        val camera = CameraPosition.Builder()
            .target(target)
            .zoom(17.1f)
            .bearing(heading)
            .tilt(46f)
            .build()
        if (animated) map.animateCamera(CameraUpdateFactory.newCameraPosition(camera))
        else map.moveCamera(CameraUpdateFactory.newCameraPosition(camera))
    }

    private fun fitPoints(points: List<LatLng>) {
        val map = googleMap ?: return
        val view = mapView ?: return
        if (view.width == 0 || view.height == 0) {
            view.post { fitPoints(points) }
            return
        }
        val bounds = LatLngBounds.Builder().apply { points.forEach(::include) }.build()
        map.animateCamera(CameraUpdateFactory.newLatLngBounds(bounds, 100))
    }

    @Suppress("UNCHECKED_CAST")
    private fun routePoints(): List<LatLng> =
        (snapshot.route["points"] as? List<*>)?.mapNotNull { coordinate(it as? Map<String, Any?>) }
            ?: emptyList()

    private data class TrafficSection(val level: String, val points: List<LatLng>)

    @Suppress("UNCHECKED_CAST")
    private fun trafficSections(): List<TrafficSection> =
        (snapshot.route["trafficSections"] as? List<*>)?.mapNotNull { raw ->
            val values = raw as? Map<String, Any?> ?: return@mapNotNull null
            val points = (values["points"] as? List<*>)?.mapNotNull {
                coordinate(it as? Map<String, Any?>)
            } ?: emptyList()
            if (points.size < 2) return@mapNotNull null
            TrafficSection(values["level"]?.toString() ?: "moderate", points)
        } ?: emptyList()

    @Suppress("UNCHECKED_CAST")
    private fun convoyMembers(): List<Map<String, Any?>> =
        (snapshot.convoy["members"] as? List<*>)
            ?.mapNotNull { it as? Map<String, Any?> }
            ?.filter { it["userId"]?.toString() != snapshot.convoy["currentUserId"]?.toString() }
            ?: emptyList()

    @Suppress("UNCHECKED_CAST")
    private fun currentLocation(): LatLng? =
        coordinate(snapshot.navigation["currentLocation"] as? Map<String, Any?>)
            ?: coordinate(snapshot.convoy["currentLocation"] as? Map<String, Any?>)

    private fun coordinate(data: Map<String, Any?>?): LatLng? {
        data ?: return null
        val lat = number(data["latitude"] ?: data["lat"]) ?: return null
        val lon = number(data["longitude"] ?: data["lon"]) ?: return null
        return LatLng(lat, lon)
    }

    private fun number(value: Any?): Double? = when (value) {
        is Number -> value.toDouble()
        is String -> value.toDoubleOrNull()
        else -> null
    }

    private fun convoyBitmap(member: Map<String, Any?>): Bitmap {
        val assetPath = member["assetPath"]?.toString()
        if (!assetPath.isNullOrBlank()) {
            try {
                carContext.assets.open("flutter_assets/$assetPath").use { stream ->
                    val decoded = BitmapFactory.decodeStream(stream)
                    if (decoded != null) {
                        val size = (34 * carContext.resources.displayMetrics.density).toInt()
                        return Bitmap.createScaledBitmap(decoded, size, size, true)
                    }
                }
            } catch (_: Exception) {
            }
        }
        return navigationArrowBitmap(sizeDp = 34)
    }

    private fun navigationArrowBitmap(sizeDp: Int = 38): Bitmap {
        val density = carContext.resources.displayMetrics.density
        val size = (sizeDp * density).toInt().coerceAtLeast(32)
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val center = size / 2f
        val path = Path().apply {
            moveTo(center, size * 0.08f)
            lineTo(size * 0.82f, size * 0.84f)
            lineTo(center, size * 0.68f)
            lineTo(size * 0.18f, size * 0.84f)
            close()
        }
        canvas.drawPath(path, Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            style = Paint.Style.STROKE
            strokeWidth = 4 * density
            strokeJoin = Paint.Join.ROUND
        })
        canvas.drawPath(path, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.rgb(0, 165, 255) })
        return bitmap
    }

    private fun locationDotBitmap(): Bitmap {
        val density = carContext.resources.displayMetrics.density
        val size = (28 * density).toInt()
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawCircle(size / 2f, size / 2f, size * 0.42f, Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
        })
        canvas.drawCircle(size / 2f, size / 2f, size * 0.31f, Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(0, 145, 255)
        })
        return bitmap
    }

    private fun destroySurface() {
        googleMap = null
        userMarker = null
        destinationMarker = null
        routePolyline = null
        trafficPolylines.clear()
        renderedRoute = emptyList()
        renderedTrafficSections = emptyList()
        convoyMarkers.clear()
        mapView?.onPause()
        mapView?.onStop()
        mapView?.onDestroy()
        mapView = null
        presentation?.dismiss()
        presentation = null
        virtualDisplay?.release()
        virtualDisplay = null
    }

    private fun offset(origin: LatLng, distanceMeters: Double, bearingDegrees: Double): LatLng {
        val radius = 6_371_000.0
        val distance = distanceMeters / radius
        val bearing = Math.toRadians(bearingDegrees)
        val latitude = Math.toRadians(origin.latitude)
        val longitude = Math.toRadians(origin.longitude)
        val targetLatitude = asin(sin(latitude) * cos(distance) + cos(latitude) * sin(distance) * cos(bearing))
        val targetLongitude = longitude + atan2(
            sin(bearing) * sin(distance) * cos(latitude),
            cos(distance) - sin(latitude) * sin(targetLatitude),
        )
        return LatLng(Math.toDegrees(targetLatitude), Math.toDegrees(targetLongitude))
    }

    private fun bearing(from: LatLng, to: LatLng): Double {
        val fromLat = Math.toRadians(from.latitude)
        val toLat = Math.toRadians(to.latitude)
        val delta = Math.toRadians(to.longitude - from.longitude)
        return (Math.toDegrees(atan2(sin(delta) * cos(toLat), cos(fromLat) * sin(toLat) - sin(fromLat) * cos(toLat) * cos(delta))) + 360) % 360
    }
}

private class CruizXSpeedGaugeView(context: Context) : View(context) {
    private var speed = 0.0
    private var limit: Double? = null
    private var unit = "km/h"

    fun update(speed: Double, roadLimit: Double?, vehicleLimit: Double?, unit: String, visible: Boolean) {
        this.speed = speed.coerceAtLeast(0.0)
        limit = roadLimit ?: vehicleLimit
        this.unit = unit
        visibility = if (visible) VISIBLE else GONE
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val density = resources.displayMetrics.density
        val cx = width / 2f
        val cy = 27 * density
        val radius = 23 * density
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = 3.2f * density
            strokeCap = Paint.Cap.ROUND
        }
        val fraction = limit?.takeIf { it > 0 }?.let { (speed / it).coerceIn(0.0, 1.0) } ?: 0.0
        val segments = 28
        for (index in 0 until segments) {
            paint.color = if (index < (fraction * segments).toInt()) {
                if (limit != null && speed > limit!! + 0.5) Color.rgb(255, 75, 80) else Color.rgb(255, 145, 35)
            } else {
                Color.argb(110, 205, 210, 220)
            }
            val start = -90f + index * 360f / segments + 2f
            canvas.drawArc(cx - radius, cy - radius, cx + radius, cy + radius, start, 360f / segments - 4f, false, paint)
        }
        drawCentered(canvas, speed.toInt().toString(), cx, cy + 2 * density, 18f * density, Color.WHITE)
        drawCentered(canvas, unit, cx, cy + 15 * density, 7f * density, Color.LTGRAY)

        val signCy = 82 * density
        val signRadius = 18 * density
        canvas.drawCircle(cx, signCy, signRadius, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE })
        canvas.drawCircle(cx, signCy, signRadius, Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = if (limit != null) Color.rgb(195, 20, 25) else Color.GRAY
            style = Paint.Style.STROKE
            strokeWidth = 3.5f * density
        })
        drawCentered(canvas, limit?.toInt()?.toString() ?: "--", cx, signCy + 5 * density, 13f * density, Color.BLACK)
    }

    private fun drawCentered(canvas: Canvas, text: String, x: Float, baseline: Float, size: Float, color: Int) {
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            textAlign = Paint.Align.CENTER
            textSize = size
            this.color = color
            isFakeBoldText = true
        }
        canvas.drawText(text, x, baseline, paint)
    }
}
