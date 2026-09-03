package com.cruizx.slowride

import android.os.Handler
import android.os.Looper
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.ActionStrip
import androidx.car.app.model.CarColor
import androidx.car.app.model.CarIcon
import androidx.car.app.model.DateTimeWithZone
import androidx.car.app.model.Distance
import androidx.car.app.model.ItemList
import androidx.car.app.model.ListTemplate
import androidx.car.app.model.MessageTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.SearchTemplate
import androidx.car.app.model.Template
import androidx.car.app.navigation.model.NavigationTemplate
import androidx.car.app.navigation.model.RoutingInfo
import androidx.car.app.navigation.model.Step
import androidx.car.app.navigation.model.TravelEstimate
import androidx.core.graphics.drawable.IconCompat
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import org.json.JSONArray
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.util.TimeZone
import java.util.concurrent.Executors

class CruizXNavigationScreen(
    carContext: CarContext,
    private val renderer: CruizXAutoMapRenderer,
) : Screen(carContext) {
    private var snapshot = AndroidAutoStateStore.snapshot
    private var shownTrafficProposalID: String? = null
    private var shownTrafficWarningKey: String? = null
    private val stateListener: (AndroidAutoStateStore.Snapshot) -> Unit = {
        snapshot = it
        showTrafficProposalIfNeeded(it.trafficProposal)
        showTrafficWarningIfNeeded(it.trafficWarning)
        invalidate()
    }

    private fun showTrafficProposalIfNeeded(proposal: Map<String, Any?>) {
        val id = proposal["id"]?.toString()?.takeIf(String::isNotBlank) ?: return
        if (id == shownTrafficProposalID) return
        shownTrafficProposalID = id
        Handler(Looper.getMainLooper()).post {
            screenManager.push(CruizXTrafficRerouteScreen(carContext, proposal))
        }
    }

    private fun showTrafficWarningIfNeeded(warning: Map<String, Any?>) {
        val message = warning["message"]?.toString()?.takeIf(String::isNotBlank) ?: return
        // Use the message text as a simple dedup key.
        if (message == shownTrafficWarningKey) return
        // Don't overlay a reroute proposal with a warning.
        if (snapshot.trafficProposal.isNotEmpty()) return
        shownTrafficWarningKey = message
        Handler(Looper.getMainLooper()).post {
            screenManager.push(CruizXTrafficWarningScreen(carContext, message))
        }
    }

    init {
        AndroidAutoStateStore.addListener(stateListener)
        lifecycle.addObserver(object : DefaultLifecycleObserver {
            override fun onDestroy(owner: LifecycleOwner) {
                AndroidAutoStateStore.removeListener(stateListener)
            }
        })
    }

    override fun onGetTemplate(): Template {
        val navigation = snapshot.navigation
        val navigating = navigation["isNavigating"] as? Boolean ?: false
        val builder = NavigationTemplate.Builder().setBackgroundColor(CarColor.BLUE)

        val actions = ActionStrip.Builder()
            .addAction(
                Action.Builder()
                    .setTitle("Översikt")
                    .setOnClickListener(renderer::overview)
                    .build(),
            )
        if (navigating) {
            actions.addAction(
                Action.Builder()
                    .setTitle("Stopp")
                    .setOnClickListener(AndroidAutoStateStore::stopNavigation)
                    .build(),
            )
        }
        builder.setActionStrip(actions.build())

        builder.setMapActionStrip(
            ActionStrip.Builder()
                .addAction(iconAction(android.R.drawable.ic_menu_search) {
                    screenManager.push(CruizXSearchScreen(carContext, renderer))
                })
                .addAction(iconAction(android.R.drawable.ic_menu_recent_history) {
                    screenManager.push(CruizXRecentsScreen(carContext, renderer))
                })
                .addAction(iconAction(android.R.drawable.ic_menu_myplaces) {
                    screenManager.push(CruizXConvoyScreen(carContext, renderer))
                })
                .addAction(Action.Builder(Action.PAN).build())
                .build(),
        )
        builder.setPanModeListener { }

        if (navigating) {
            buildRoutingInfo(navigation)?.let(builder::setNavigationInfo)
            buildTravelEstimate(navigation)?.let(builder::setDestinationTravelEstimate)
        }
        return builder.build()
    }

    private fun iconAction(resourceId: Int, onClick: () -> Unit): Action =
        Action.Builder()
            .setIcon(
                CarIcon.Builder(IconCompat.createWithResource(carContext, resourceId)).build(),
            )
            .setOnClickListener(onClick)
            .build()

    @Suppress("UNCHECKED_CAST")
    private fun buildRoutingInfo(navigation: Map<String, Any?>): RoutingInfo? {
        val maneuvers = navigation["upcomingManeuvers"] as? List<*> ?: emptyList<Any>()
        val first = maneuvers.firstOrNull() as? Map<String, Any?>
        val cue = first?.get("text")?.toString()?.trim().orEmpty().ifEmpty {
            navigation["nextManeuverText"]?.toString()?.trim().orEmpty()
        }
        if (cue.isEmpty()) return null
        val street = first?.get("streetName")?.toString()?.trim().orEmpty().ifEmpty {
            navigation["currentStreetName"]?.toString()?.trim().orEmpty()
        }
        val distanceMeters = number(first?.get("distanceMeters")) ?: 0.0
        val currentStep = Step.Builder(cue).apply {
            if (street.isNotEmpty()) setRoad(street)
        }.build()
        val info = RoutingInfo.Builder().setCurrentStep(
            currentStep,
            Distance.create(distanceMeters.coerceAtLeast(0.0), Distance.UNIT_METERS),
        )
        val second = maneuvers.drop(1).firstOrNull() as? Map<String, Any?>
        val nextText = second?.get("text")?.toString()?.trim().orEmpty()
        if (nextText.isNotEmpty()) {
            info.setNextStep(Step.Builder(nextText).build())
        }
        return info.build()
    }

    private fun buildTravelEstimate(navigation: Map<String, Any?>): TravelEstimate? {
        val distanceMeters = number(navigation["remainingDistanceMeters"]) ?: return null
        val durationSeconds = (number(navigation["remainingDurationSeconds"]) ?: 0.0)
            .coerceAtLeast(0.0)
            .toLong()
        val arrivalMillis = System.currentTimeMillis() + durationSeconds * 1000
        val zone = TimeZone.getDefault()
        val date = DateTimeWithZone.create(
            arrivalMillis,
            zone.getOffset(arrivalMillis) / 1000,
            zone.id,
        )
        return TravelEstimate.Builder(
            Distance.create(distanceMeters.coerceAtLeast(0.0), Distance.UNIT_METERS),
            date,
        ).setRemainingTimeSeconds(durationSeconds).build()
    }

    private fun number(value: Any?): Double? = when (value) {
        is Number -> value.toDouble()
        is String -> value.toDoubleOrNull()
        else -> null
    }
}

private class CruizXTrafficRerouteScreen(
    carContext: CarContext,
    private val proposal: Map<String, Any?>,
) : Screen(carContext) {
    private val handler = Handler(Looper.getMainLooper())
    private val proposalID = proposal["id"]?.toString().orEmpty()
    private var resolved = false
    private val timeout = Runnable { finish(false) }

    init {
        val timeoutSeconds = (proposal["timeoutSeconds"] as? Number)
            ?.toLong()?.coerceIn(5, 60) ?: 20L
        handler.postDelayed(timeout, timeoutSeconds * 1000)
        lifecycle.addObserver(object : DefaultLifecycleObserver {
            override fun onDestroy(owner: LifecycleOwner) {
                handler.removeCallbacks(timeout)
                if (!resolved) {
                    resolved = true
                    AndroidAutoStateStore.resolveTrafficRerouteProposal(proposalID, false)
                }
            }
        })
    }

    override fun onGetTemplate(): Template {
        val title = proposal["title"]?.toString()?.trim().orEmpty()
            .ifEmpty { "Snabbare rutt hittad" }
        val body = proposal["body"]?.toString()?.trim().orEmpty()
            .ifEmpty { "En snabbare verifierad rutt finns." }
        val keepLabel = proposal["keepLabel"]?.toString()?.trim().orEmpty()
            .ifEmpty { "Behåll" }
        val useLabel = proposal["useLabel"]?.toString()?.trim().orEmpty()
            .ifEmpty { "Byt rutt" }
        return MessageTemplate.Builder(body)
            .setTitle(title)
            .addAction(
                Action.Builder()
                    .setTitle(keepLabel)
                    .setOnClickListener { finish(false) }
                    .build(),
            )
            .addAction(
                Action.Builder()
                    .setTitle(useLabel)
                    .setOnClickListener { finish(true) }
                    .build(),
            )
            .build()
    }

    private fun finish(accepted: Boolean) {
        if (resolved) return
        resolved = true
        handler.removeCallbacks(timeout)
        AndroidAutoStateStore.resolveTrafficRerouteProposal(proposalID, accepted)
        screenManager.pop()
    }
}

private class CruizXTrafficWarningScreen(
    carContext: CarContext,
    private val message: String,
) : Screen(carContext) {
    override fun onGetTemplate(): Template =
        MessageTemplate.Builder(message)
            .setTitle("CruizX")
            .addAction(
                Action.Builder()
                    .setTitle("OK")
                    .setOnClickListener { screenManager.pop() }
                    .build(),
            )
            .build()
}

private data class AutoDestination(
    val title: String,
    val address: String,
    val latitude: Double,
    val longitude: Double,
)

private class CruizXSearchScreen(
    carContext: CarContext,
    private val renderer: CruizXAutoMapRenderer,
) : Screen(carContext) {
    private val executor = Executors.newSingleThreadExecutor()
    private val handler = Handler(Looper.getMainLooper())
    private var searchRunnable: Runnable? = null
    private var query = ""
    private var results: List<AutoDestination> = emptyList()
    private var loading = false

    override fun onGetTemplate(): Template {
        val list = ItemList.Builder().apply {
            if (results.isEmpty() && !loading) setNoItemsMessage("Sök efter en adress eller plats")
            results.forEach { destination ->
                addItem(
                    Row.Builder()
                        .setTitle(destination.title)
                        .addText(destination.address)
                        .setOnClickListener { select(destination) }
                        .build(),
                )
            }
        }.build()
        val builder = SearchTemplate.Builder(object : SearchTemplate.SearchCallback {
            override fun onSearchTextChanged(searchText: String) {
                query = searchText.trim()
                scheduleSearch()
            }

            override fun onSearchSubmitted(searchTerm: String) {
                query = searchTerm.trim()
                if (results.isNotEmpty()) select(results.first()) else scheduleSearch(immediate = true)
            }
        })
            .setHeaderAction(Action.BACK)
            .setShowKeyboardByDefault(true)
            .setInitialSearchText(query)
        if (loading) builder.setLoading(true) else builder.setItemList(list)
        return builder.build()
    }

    private fun scheduleSearch(immediate: Boolean = false) {
        searchRunnable?.let(handler::removeCallbacks)
        if (query.length < 2) {
            loading = false
            results = emptyList()
            invalidate()
            return
        }
        val runnable = Runnable { performSearch(query) }
        searchRunnable = runnable
        handler.postDelayed(runnable, if (immediate) 0 else 500)
    }

    private fun performSearch(term: String) {
        loading = true
        invalidate()
        executor.execute {
            val found = try {
                val encoded = URLEncoder.encode(term, Charsets.UTF_8.name())
                val connection = URL(
                                    "https://nominatim.openstreetmap.org/search?format=jsonv2&addressdetails=1&limit=6&q=$encoded",
                ).openConnection() as HttpURLConnection
                connection.connectTimeout = 7000
                connection.readTimeout = 7000
                connection.setRequestProperty("User-Agent", "CruizX/1.2 AndroidAuto")
                connection.inputStream.bufferedReader().use { reader ->
                    val array = JSONArray(reader.readText())
                    buildList {
                        for (index in 0 until array.length()) {
                            val item = array.getJSONObject(index)
                            val display = item.optString("display_name")
                            val title = item.optString("name").ifBlank {
                                display.substringBefore(',').ifBlank { term }
                            }
                            add(
                                AutoDestination(
                                    title = title,
                                    address = display,
                                    latitude = item.optDouble("lat"),
                                    longitude = item.optDouble("lon"),
                                ),
                            )
                        }
                    }
                }
            } catch (_: Exception) {
                emptyList()
            }
            handler.post {
                if (term == query) {
                    results = found
                    loading = false
                    invalidate()
                }
            }
        }
    }

    private fun select(destination: AutoDestination) {
        renderer.focusOn(destination.latitude, destination.longitude)
        screenManager.push(CruizXDestinationPreviewScreen(carContext, destination))
    }
}

private class CruizXRecentsScreen(
    carContext: CarContext,
    private val renderer: CruizXAutoMapRenderer,
) : Screen(carContext) {
    override fun onGetTemplate(): Template {
        val recents = destinations("recents")
        val list = ItemList.Builder().apply {
            if (recents.isEmpty()) setNoItemsMessage("Inga senaste mål")
            recents.forEach { destination ->
                addItem(
                    Row.Builder()
                        .setTitle(destination.title)
                        .addText(destination.address)
                        .setOnClickListener {
                            renderer.focusOn(destination.latitude, destination.longitude)
                            screenManager.push(
                                CruizXDestinationPreviewScreen(carContext, destination),
                            )
                        }.build(),
                )
            }
        }.build()
        return ListTemplate.Builder()
            .setTitle("Senaste")
            .setHeaderAction(Action.BACK)
            .setSingleList(list)
            .build()
    }

    @Suppress("UNCHECKED_CAST")
    private fun destinations(key: String): List<AutoDestination> =
        (AndroidAutoStateStore.snapshot.destinations[key] as? List<*>)?.mapNotNull { raw ->
            val item = raw as? Map<String, Any?> ?: return@mapNotNull null
            val lat = number(item["latitude"] ?: item["lat"]) ?: return@mapNotNull null
            val lon = number(item["longitude"] ?: item["lon"]) ?: return@mapNotNull null
            AutoDestination(
                item["title"]?.toString() ?: "Mål",
                (item["subtitle"] ?: item["address"])?.toString() ?: "",
                lat,
                lon,
            )
        } ?: emptyList()
}

private class CruizXDestinationPreviewScreen(
    carContext: CarContext,
    private val destination: AutoDestination,
) : Screen(carContext) {
    override fun onGetTemplate(): Template = MessageTemplate.Builder(
        destination.address.ifBlank { destination.title },
    )
        .setTitle(destination.title)
        .setHeaderAction(Action.BACK)
        .addAction(
            Action.Builder()
                .setTitle("Starta")
                .setBackgroundColor(CarColor.BLUE)
                .setOnClickListener {
                    AndroidAutoStateStore.startNavigation(
                        destination.latitude,
                        destination.longitude,
                        destination.title,
                        destination.address,
                    )
                    screenManager.popToRoot()
                }.build(),
        )
        .build()
}

private class CruizXConvoyScreen(
    carContext: CarContext,
    private val renderer: CruizXAutoMapRenderer,
) : Screen(carContext) {
    override fun onGetTemplate(): Template {
        val convoy = AndroidAutoStateStore.snapshot.convoy
        val active = convoy["isActive"] as? Boolean ?: false
        val members = members()
        val list = ItemList.Builder().apply {
            if (!active || members.isEmpty()) {
                setNoItemsMessage("Öppna en konvoj på mobilen så visas deltagarna här")
            } else {
                addItem(
                    Row.Builder()
                        .setTitle("Visa hela konvojen")
                        .addText("${members.size} deltagare")
                        .setOnClickListener {
                            renderer.showAllConvoyMembers()
                            screenManager.popToRoot()
                        }.build(),
                )
                members.forEach { member ->
                    addItem(
                        Row.Builder()
                            .setTitle(member.title)
                            .addText("Visa på kartan")
                            .setOnClickListener {
                                renderer.focusOn(member.latitude, member.longitude)
                                screenManager.popToRoot()
                            }.build(),
                    )
                }
            }
        }.build()
        return ListTemplate.Builder()
            .setTitle(convoy["convoyName"]?.toString()?.ifBlank { "Konvoj" } ?: "Konvoj")
            .setHeaderAction(Action.BACK)
            .setSingleList(list)
            .build()
    }

    @Suppress("UNCHECKED_CAST")
    private fun members(): List<AutoDestination> =
        (AndroidAutoStateStore.snapshot.convoy["members"] as? List<*>)?.mapNotNull { raw ->
            val item = raw as? Map<String, Any?> ?: return@mapNotNull null
            if (item["userId"]?.toString() ==
                AndroidAutoStateStore.snapshot.convoy["currentUserId"]?.toString()
            ) {
                return@mapNotNull null
            }
            val lat = number(item["latitude"] ?: item["lat"]) ?: return@mapNotNull null
            val lon = number(item["longitude"] ?: item["lon"]) ?: return@mapNotNull null
            AutoDestination(item["label"]?.toString() ?: "Deltagare", "", lat, lon)
        } ?: emptyList()
}

private fun number(value: Any?): Double? = when (value) {
    is Number -> value.toDouble()
    is String -> value.toDoubleOrNull()
    else -> null
}
