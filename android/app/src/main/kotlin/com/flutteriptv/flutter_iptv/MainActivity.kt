package com.flutteriptv.flutter_iptv

import android.content.Intent
import android.content.res.Configuration
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.KeyEvent
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import androidx.activity.OnBackPressedCallback
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterFragmentActivity() {
    private val TAG = "MainActivity"
    private val CHANNEL = "com.flutteriptv/platform"
    private val PLAYER_CHANNEL = "com.flutteriptv/native_player"
    private val INSTALL_CHANNEL = "com.flutteriptv/install"

    private var playerFragment: NativePlayerFragment? = null
    private var multiScreenFragment: MultiScreenPlayerFragment? = null
    private var playerContainer: FrameLayout? = null
    private var playerMethodChannel: MethodChannel? = null

    private lateinit var backPressedCallback: OnBackPressedCallback

    // Remember multi-screen state
    data class ScreenState(
        var channelIndex: Int = -1,
        var channelName: String = "",
        var channelUrl: String = "",
        var currentSourceIndex: Int = 0  // Remember source index
    )
    private var savedMultiScreenStates = Array(4) { ScreenState() }
    private var savedActiveScreenIndex = 0
    private var savedFocusedScreenIndex = 0

    // Remember channel data (used for passing during switching)
    private var lastChannelUrls: List<String>? = null
    private var lastChannelNames: List<String>? = null
    private var lastChannelGroups: List<String>? = null
    private var lastChannelSources: List<List<String>>? = null
    private var lastChannelLogos: List<String>? = null
    private var lastVolumeBoostDb: Int = 0
    private var lastDefaultScreenPosition: Int = 1
    private var lastShowChannelName: Boolean = false

    // Mark if exiting from multi-screen to single channel playback
    // (in this case single channel exit should not overwrite multi-screen state)
    private var isFromMultiScreen: Boolean = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.d(TAG, "configureFlutterEngine called")

        // Platform detection channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isTV" -> {
                    result.success(isAndroidTV())
                }
                "getDeviceType" -> {
                    result.success(getDeviceType())
                }
                "getCpuAbi" -> {
                    result.success(Build.SUPPORTED_ABIS.firstOrNull() ?: "armeabi-v7a")
                }
                "setKeepScreenOn" -> {
                    val enable = call.argument<Boolean>("enable") ?: true
                    runOnUiThread {
                        if (enable) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        }
                    }
                    Log.d(TAG, "setKeepScreenOn: $enable")
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // APK install channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INSTALL_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath != null) {
                        try {
                            installApk(filePath)
                            result.success(true)
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed to install APK", e)
                            result.error("INSTALL_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_PATH", "APK file path is required", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Native player channel
        playerMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PLAYER_CHANNEL)
        playerMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "launchPlayer" -> {
                    val url = call.argument<String>("url")
                    val name = call.argument<String>("name") ?: ""
                    val index = call.argument<Int>("index") ?: 0
                    val urls = call.argument<List<String>>("urls")
                    val names = call.argument<List<String>>("names")
                    val groups = call.argument<List<String>>("groups")
                    @Suppress("UNCHECKED_CAST")
                    val sources = call.argument<List<List<String>>>("sources") // All sources for each channel
                    val logos = call.argument<List<String>>("logos") // Logo URL for each channel
                    val epgIds = call.argument<List<String>>("epgIds") // EPG ID for each channel
                    val isSeekable = call.argument<List<Boolean>>("isSeekable") // Whether each channel is seekable
                    val isDlnaMode = call.argument<Boolean>("isDlnaMode") ?: false
                    val bufferStrength = call.argument<String>("bufferStrength") ?: "fast"
                    val showFps = call.argument<Boolean>("showFps") ?: true
                    val showClock = call.argument<Boolean>("showClock") ?: true
                    val showNetworkSpeed = call.argument<Boolean>("showNetworkSpeed") ?: true
                    val showVideoInfo = call.argument<Boolean>("showVideoInfo") ?: true
                    val progressBarMode = call.argument<String>("progressBarMode") ?: "auto" // Progress bar display mode
                    val showChannelName = call.argument<Boolean>("showChannelName") ?: false // Multi-screen channel name display

                    // Save showChannelName setting, used when entering multi-screen from single screen
                    lastShowChannelName = showChannelName

                    if (url != null) {
                        Log.d(TAG, "Launching native player fragment: $name (index $index of ${urls?.size ?: 0}, isDlna=$isDlnaMode, logos=${logos?.size ?: 0}, isSeekable=${isSeekable?.getOrNull(index)}, progressBarMode=$progressBarMode, showChannelName=$showChannelName)")
                        try {
                            showPlayerFragment(url, name, index, urls, names, groups, sources, logos, epgIds, isSeekable, isDlnaMode, bufferStrength, showFps, showClock, showNetworkSpeed, showVideoInfo, progressBarMode)
                            result.success(true)
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed to launch player", e)
                            result.error("LAUNCH_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_URL", "Video URL is required", null)
                    }
                }
                "closePlayer" -> {
                    hidePlayerFragment()
                    result.success(true)
                }
                "isNativePlayerAvailable" -> {
                    result.success(isAndroidTV())
                }
                "pause" -> {
                    playerFragment?.pause()
                    result.success(true)
                }
                "play" -> {
                    playerFragment?.play()
                    result.success(true)
                }
                "seekTo" -> {
                    val position = call.argument<Number>("position")?.toLong() ?: 0L
                    Log.d(TAG, "DLNA seekTo: position=$position, playerFragment=${playerFragment != null}")
                    playerFragment?.seekTo(position)
                    result.success(true)
                }
                "setVolume" -> {
                    val volume = call.argument<Int>("volume") ?: 100
                    playerFragment?.setVolume(volume)
                    result.success(true)
                }
                "getPlaybackState" -> {
                    // Get state from NativePlayerFragment
                    val state = playerFragment?.getPlaybackState()
                    result.success(state)
                }
                "launchMultiScreen" -> {
                    val urls = call.argument<List<String>>("urls")
                    val names = call.argument<List<String>>("names")
                    val groups = call.argument<List<String>>("groups")
                    @Suppress("UNCHECKED_CAST")
                    val sources = call.argument<List<List<String>>>("sources")
                    val logos = call.argument<List<String>>("logos")
                    val initialChannelIndex = call.argument<Int>("initialChannelIndex") ?: 0
                    val volumeBoostDb = call.argument<Int>("volumeBoostDb") ?: 0
                    val defaultScreenPosition = call.argument<Int>("defaultScreenPosition") ?: 1
                    val restoreActiveIndex = call.argument<Int>("restoreActiveIndex") ?: -1
                    @Suppress("UNCHECKED_CAST")
                    val restoreScreenChannels = call.argument<List<Int?>>("restoreScreenChannels")
                    val showChannelName = call.argument<Boolean>("showChannelName") ?: false

                    if (urls != null && names != null && groups != null) {
                        Log.d(TAG, "Launching multi-screen player with ${urls.size} channels, initial=$initialChannelIndex, volumeBoost=$volumeBoostDb, defaultScreen=$defaultScreenPosition, restoreActive=$restoreActiveIndex, restoreChannels=$restoreScreenChannels, showChannelName=$showChannelName")
                        try {
                            showMultiScreenFragment(
                                urls, names, groups, sources, logos,
                                initialChannelIndex, volumeBoostDb, defaultScreenPosition,
                                restoreFromLocal = false,  // Do not restore from local
                                restoreActiveIndex = restoreActiveIndex,  // Restoration parameters passed from Flutter
                                restoreScreenChannels = restoreScreenChannels,
                                initialSourceIndex = 0,
                                showChannelName = showChannelName
                            )
                            result.success(true)
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed to launch multi-screen player", e)
                            result.error("LAUNCH_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_DATA", "Channel data is required", null)
                    }
                }
                "closeMultiScreen" -> {
                    hideMultiScreenFragment()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    fun requestEpgInfo(channelName: String, epgId: String, callback: (Map<String, Any?>?) -> Unit) {
        runOnUiThread {
            playerMethodChannel?.invokeMethod("getEpgInfo", mapOf("channelName" to channelName, "epgId" to epgId), object : MethodChannel.Result {
                override fun success(result: Any?) {
                    @Suppress("UNCHECKED_CAST")
                    callback(result as? Map<String, Any?>)
                }
                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                    Log.e(TAG, "EPG request error: $errorMessage")
                    callback(null)
                }
                override fun notImplemented() {
                    Log.e(TAG, "EPG request method not implemented on Flutter side")
                    callback(null)
                }
            })
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "onCreate called")

        // Create player container overlay
        playerContainer = FrameLayout(this).apply {
            id = View.generateViewId()
            visibility = View.GONE
            setBackgroundColor(0xFF000000.toInt())
        }

        // Add container on top of Flutter view
        addContentView(
            playerContainer,
            android.widget.FrameLayout.LayoutParams(
                android.widget.FrameLayout.LayoutParams.MATCH_PARENT,
                android.widget.FrameLayout.LayoutParams.MATCH_PARENT
            )
        )

        // Setup back press handling for Android 13+
        backPressedCallback = object : OnBackPressedCallback(false) {
            override fun handleOnBackPressed() {
                Log.d(TAG, "OnBackPressedCallback triggered, multiScreen=${multiScreenFragment != null}, player=${playerFragment != null}")
                // Prioritize multi-screen
                if (multiScreenFragment != null) {
                    multiScreenFragment?.handleBackKey()
                } else {
                    playerFragment?.handleBackKey()
                }
            }
        }
        onBackPressedDispatcher.addCallback(this, backPressedCallback)
    }

    private fun showPlayerFragment(
        url: String,
        name: String,
        index: Int,
        urls: List<String>?,
        names: List<String>?,
        groups: List<String>?,
        sources: List<List<String>>?,
        logos: List<String>?,
        epgIds: List<String>?,
        isSeekable: List<Boolean>?,
        isDlnaMode: Boolean = false,
        bufferStrength: String = "fast",
        showFps: Boolean = true,
        showClock: Boolean = true,
        showNetworkSpeed: Boolean = true,
        showVideoInfo: Boolean = true,
        progressBarMode: String = "auto",  // Progress bar display mode
        initialSourceIndex: Int = 0  // Initial source index
    ) {
        Log.d(TAG, "showPlayerFragment isDlnaMode=$isDlnaMode, bufferStrength=$bufferStrength, logos=${logos?.size ?: 0}, sourceIndex=$initialSourceIndex, isSeekable=${isSeekable?.getOrNull(index)}, progressBarMode=$progressBarMode")

        // Save channel data (used for passing when switching to multi-screen)
        lastChannelUrls = urls
        lastChannelNames = names
        lastChannelGroups = groups
        lastChannelSources = sources
        lastChannelLogos = logos

        // Enable back press callback when player is showing
        backPressedCallback.isEnabled = true

        // Hide system UI
        window.setFlags(
            WindowManager.LayoutParams.FLAG_FULLSCREEN,
            WindowManager.LayoutParams.FLAG_FULLSCREEN
        )
        window.decorView.systemUiVisibility = (
            View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
            or View.SYSTEM_UI_FLAG_FULLSCREEN
            or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
            or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
            or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
            or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
        )

        playerContainer?.visibility = View.VISIBLE

        // Convert sources to ArrayList<ArrayList<String>>
        val sourcesArrayList = sources?.map { ArrayList(it) }?.let { ArrayList(it) }
        val logosArrayList = logos?.let { ArrayList(it) }
        val epgIdsArrayList = epgIds?.let { ArrayList(it) }
        val isSeekableArrayList = isSeekable?.let { ArrayList(it) }

        playerFragment = NativePlayerFragment.newInstance(
            url,
            name,
            index,
            urls?.let { ArrayList(it) },
            names?.let { ArrayList(it) },
            groups?.let { ArrayList(it) },
            sourcesArrayList,
            logosArrayList,
            epgIdsArrayList,  // channelEpgIds
            isSeekableArrayList,  // channelIsSeekable
            isDlnaMode,
            bufferStrength,
            showFps,
            showClock,
            showNetworkSpeed,
            showVideoInfo,
            progressBarMode,  // Pass progress bar display mode
            initialSourceIndex  // Pass initial source index
        ).apply {
            onCloseListener = {
                runOnUiThread {
                    hidePlayerFragment()
                }
            }
            // Enter multi-screen mode from normal player
            onEnterMultiScreen = { channelIndex, sourceIndex ->
                runOnUiThread {
                    if (urls != null && names != null && groups != null) {
                        // Hide normal player first
                        hidePlayerFragment()
                        // Start multi-screen, restore previous state
                        showMultiScreenFragment(
                            urls, names, groups, sources, logos,
                            channelIndex,
                            lastVolumeBoostDb,
                            lastDefaultScreenPosition,
                            restoreFromLocal = true,  // Restore previous multi-screen state (from local storage)
                            initialSourceIndex = sourceIndex,  // Pass current source index
                            showChannelName = lastShowChannelName  // Use saved settings
                        )
                    }
                }
            }
        }

        supportFragmentManager.beginTransaction()
            .replace(playerContainer!!.id, playerFragment!!)
            .commit()
    }

    private fun hidePlayerFragment() {
        Log.d(TAG, "hidePlayerFragment: isFromMultiScreen=$isFromMultiScreen")

        // Get current playing channel index
        val currentChannelIndex = playerFragment?.getCurrentChannelIndex() ?: -1
        Log.d(TAG, "hidePlayerFragment: currentChannelIndex=$currentChannelIndex")

        // Disable back press callback when player is hidden
        backPressedCallback.isEnabled = false

        playerFragment?.let {
            supportFragmentManager.beginTransaction()
                .remove(it)
                .commitAllowingStateLoss()
        }
        playerFragment = null
        playerContainer?.visibility = View.GONE

        // Restore system UI
        window.clearFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN)
        window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_VISIBLE

        // Notify Flutter that player closed with current channel index
        // If exiting from multi-screen to single channel playback, pass skipSave=true to tell Flutter not to overwrite multi-screen state
        playerMethodChannel?.invokeMethod("onPlayerClosed", mapOf(
            "channelIndex" to currentChannelIndex,
            "skipSave" to isFromMultiScreen
        ))

        // Reset flag
        isFromMultiScreen = false
    }

    private fun showMultiScreenFragment(
        urls: List<String>,
        names: List<String>,
        groups: List<String>,
        sources: List<List<String>>?,
        logos: List<String>?,
        initialChannelIndex: Int = 0,
        volumeBoostDb: Int = 0,
        defaultScreenPosition: Int = 1,
        restoreFromLocal: Boolean = false,  // Whether to restore from locally saved state (single screen switch to multi-screen)
        restoreActiveIndex: Int = -1,  // Restore active screen index passed from Flutter (continue playback from home)
        restoreScreenChannels: List<Int?>? = null,  // Restore channel index passed from Flutter (continue playback from home)
        initialSourceIndex: Int = 0,  // Initial source index (passed when entering multi-screen from single screen)
        showChannelName: Boolean = false  // Whether to show channel name
    ) {
        val shouldRestoreFromFlutter = restoreActiveIndex >= 0 && restoreScreenChannels != null
        Log.d(TAG, "showMultiScreenFragment with ${urls.size} channels, initial=$initialChannelIndex, sourceIndex=$initialSourceIndex, volumeBoost=$volumeBoostDb, defaultScreen=$defaultScreenPosition, restoreFromLocal=$restoreFromLocal, restoreFromFlutter=$shouldRestoreFromFlutter, showChannelName=$showChannelName")

        // Save channel data
        lastChannelUrls = urls
        lastChannelNames = names
        lastChannelGroups = groups
        lastChannelSources = sources
        lastChannelLogos = logos
        lastVolumeBoostDb = volumeBoostDb
        lastDefaultScreenPosition = defaultScreenPosition
        lastShowChannelName = showChannelName

        // Enable back press callback
        backPressedCallback.isEnabled = true

        // Hide system UI
        window.setFlags(
            WindowManager.LayoutParams.FLAG_FULLSCREEN,
            WindowManager.LayoutParams.FLAG_FULLSCREEN
        )
        window.decorView.systemUiVisibility = (
            View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
            or View.SYSTEM_UI_FLAG_FULLSCREEN
            or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
            or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
            or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
            or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
        )

        playerContainer?.visibility = View.VISIBLE

        val sourcesArrayList = sources?.map { ArrayList(it) }?.let { ArrayList(it) } ?: arrayListOf()
        val logosArrayList = logos?.let { ArrayList(it) } ?: arrayListOf()

        // Determine source of state restoration
        val savedStatesArrayList: ArrayList<ArrayList<String>>?
        val finalRestoreActiveIndex: Int
        val finalRestoreFocusedIndex: Int

        if (shouldRestoreFromFlutter && restoreScreenChannels != null) {
            // Restore state passed from Flutter (continue playback from home)
            savedStatesArrayList = ArrayList(restoreScreenChannels.map { channelIndex ->
                if (channelIndex != null && channelIndex >= 0 && channelIndex < urls.size) {
                    arrayListOf(channelIndex.toString(), names.getOrElse(channelIndex) { "" }, urls.getOrElse(channelIndex) { "" }, "0")  // Source index defaults to 0
                } else {
                    arrayListOf("-1", "", "", "0")
                }
            })
            finalRestoreActiveIndex = restoreActiveIndex
            finalRestoreFocusedIndex = restoreActiveIndex
        } else if (restoreFromLocal) {
            // Restore state from locally saved state (single screen switch to multi-screen), including source index
            savedStatesArrayList = ArrayList(savedMultiScreenStates.map {
                arrayListOf(it.channelIndex.toString(), it.channelName, it.channelUrl, it.currentSourceIndex.toString())
            })
            finalRestoreActiveIndex = savedActiveScreenIndex
            finalRestoreFocusedIndex = savedFocusedScreenIndex
        } else {
            savedStatesArrayList = null
            finalRestoreActiveIndex = -1
            finalRestoreFocusedIndex = -1
        }

        multiScreenFragment = MultiScreenPlayerFragment.newInstance(
            ArrayList(urls),
            ArrayList(names),
            ArrayList(groups),
            sourcesArrayList,
            logosArrayList,
            initialChannelIndex,
            initialSourceIndex,  // Pass initial source index
            volumeBoostDb,
            defaultScreenPosition,
            finalRestoreActiveIndex,
            finalRestoreFocusedIndex,
            savedStatesArrayList,
            showChannelName  // Pass whether to show channel name
        ).apply {
            onCloseListener = {
                runOnUiThread {
                    // Directly hide multi-screen, hideMultiScreenFragment will automatically save state and notify Flutter
                    hideMultiScreenFragment()
                }
            }
            onExitToNormalPlayer = { channelIndex, sourceIndex ->
                runOnUiThread {
                    // Save multi-screen state to local first (used for restoration when switching from single screen back to multi-screen)
                    saveMultiScreenState()

                    // Save multi-screen state to Flutter
                    val screenStates = mutableListOf<Int?>()
                    var activeIndex = 0
                    multiScreenFragment?.let { fragment ->
                        for (i in 0..3) {
                            val state = fragment.getScreenState(i)
                            screenStates.add(state?.channelIndex?.takeIf { it >= 0 })
                        }
                        activeIndex = fragment.getActiveScreenIndex()
                    }

                    // Notify Flutter to save multi-screen state
                    playerMethodChannel?.invokeMethod("onMultiScreenClosed", mapOf(
                        "screenStates" to screenStates,
                        "activeIndex" to activeIndex
                    ))

                    // Mark as exiting from multi-screen to single channel playback
                    isFromMultiScreen = true

                    // Start normal player after exiting multi-screen
                    if (channelIndex >= 0 && channelIndex < urls.size) {
                        // Use passed source index to get correct URL
                        val url = if (sources != null && channelIndex < sources.size && sources[channelIndex].isNotEmpty()) {
                            val validSourceIndex = sourceIndex.coerceIn(0, sources[channelIndex].size - 1)
                            sources[channelIndex][validSourceIndex]
                        } else {
                            urls[channelIndex]
                        }
                        val name = names.getOrElse(channelIndex) { "" }
                        val group = groups.getOrElse(channelIndex) { "" }

                        // Hide multi-screen first (do not notify Flutter, as already notified above)
                        hideMultiScreenFragment(notifyFlutter = false)

                        // Start normal player (pass source index)
                        showPlayerFragment(
                            url, name, channelIndex,
                            urls, names, groups, sources, logos,
                            epgIds = null,  // No EPG IDs when switching from multi-screen
                            isSeekable = null,  // No isSeekable info when switching from multi-screen
                            isDlnaMode = false,
                            bufferStrength = "fast",
                            showFps = true,
                            showClock = true,
                            showNetworkSpeed = true,
                            showVideoInfo = true,
                            initialSourceIndex = sourceIndex  // Pass source index
                        )
                    }
                }
            }
        }

        supportFragmentManager.beginTransaction()
            .replace(playerContainer!!.id, multiScreenFragment!!)
            .commit()
    }

    // Save multi-screen state
    private fun saveMultiScreenState() {
        multiScreenFragment?.let { fragment ->
            for (i in 0..3) {
                val state = fragment.getScreenState(i)
                savedMultiScreenStates[i] = ScreenState(
                    channelIndex = state?.channelIndex ?: -1,
                    channelName = state?.channelName ?: "",
                    channelUrl = state?.channelUrl ?: "",
                    currentSourceIndex = state?.currentSourceIndex ?: 0  // Save source index
                )
            }
            savedActiveScreenIndex = fragment.getActiveScreenIndex()
            savedFocusedScreenIndex = fragment.getFocusedScreenIndex()
            Log.d(TAG, "Saved multi-screen state: active=$savedActiveScreenIndex, focused=$savedFocusedScreenIndex")
        }
    }

    private fun hideMultiScreenFragment(notifyFlutter: Boolean = true) {
        Log.d(TAG, "hideMultiScreenFragment: notifyFlutter=$notifyFlutter")

        // Get multi-screen state for notifying Flutter
        val screenStates = mutableListOf<Int?>()
        var activeIndex = 0
        multiScreenFragment?.let { fragment ->
            for (i in 0..3) {
                val state = fragment.getScreenState(i)
                screenStates.add(state?.channelIndex?.takeIf { it >= 0 })
            }
            activeIndex = fragment.getActiveScreenIndex()
        }

        backPressedCallback.isEnabled = false

        multiScreenFragment?.let {
            supportFragmentManager.beginTransaction()
                .remove(it)
                .commitAllowingStateLoss()
        }
        multiScreenFragment = null
        playerContainer?.visibility = View.GONE

        // Restore system UI
        window.clearFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN)
        window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_VISIBLE

        // Notify Flutter with multi-screen state (only if not transitioning to single player)
        if (notifyFlutter) {
            playerMethodChannel?.invokeMethod("onMultiScreenClosed", mapOf(
                "screenStates" to screenStates,
                "activeIndex" to activeIndex
            ))
        }
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        Log.d(TAG, "onKeyDown: keyCode=$keyCode, playerVisible=${playerContainer?.visibility == View.VISIBLE}, multiScreen=${multiScreenFragment != null}, player=${playerFragment != null}")

        // If multi-screen is showing, handle keys
        if (multiScreenFragment != null && playerContainer?.visibility == View.VISIBLE) {
            // Back key calls handleBackKey directly
            if (keyCode == KeyEvent.KEYCODE_BACK || keyCode == KeyEvent.KEYCODE_ESCAPE) {
                Log.d(TAG, "Back key pressed for multi-screen")
                val handled = multiScreenFragment?.handleBackKey() ?: false
                Log.d(TAG, "Multi-screen handleBackKey returned: $handled")
                return true  // Always consume back key
            }
            // Other keys handled through view's key listener
            if (event != null) {
                val handled = multiScreenFragment?.view?.dispatchKeyEvent(event) ?: false
                if (handled) return true
            }
        }

        // If player is showing, let the fragment handle back key
        if (playerFragment != null && playerContainer?.visibility == View.VISIBLE) {
            if (keyCode == KeyEvent.KEYCODE_BACK || keyCode == KeyEvent.KEYCODE_ESCAPE) {
                Log.d(TAG, "Back key pressed for player")
                playerFragment?.handleBackKey()
                return true
            }
        }

        return super.onKeyDown(keyCode, event)
    }

    override fun onKeyUp(keyCode: Int, event: KeyEvent?): Boolean {
        // If multi-screen is showing, forward key up events (except back key)
        if (multiScreenFragment != null && playerContainer?.visibility == View.VISIBLE && event != null) {
            if (keyCode != KeyEvent.KEYCODE_BACK && keyCode != KeyEvent.KEYCODE_ESCAPE) {
                val handled = multiScreenFragment?.view?.dispatchKeyEvent(event) ?: false
                if (handled) return true
            }
        }
        return super.onKeyUp(keyCode, event)
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        Log.d(TAG, "onBackPressed: multiScreen=${multiScreenFragment != null}, player=${playerFragment != null}")

        // If multi-screen is showing
        if (multiScreenFragment != null && playerContainer?.visibility == View.VISIBLE) {
            Log.d(TAG, "Handling back press for multi-screen")
            multiScreenFragment?.handleBackKey()
            return
        }

        // If player is showing
        if (playerFragment != null && playerContainer?.visibility == View.VISIBLE) {
            Log.d(TAG, "Handling back press for player")
            playerFragment?.handleBackKey()
            return
        }

        super.onBackPressed()
    }

    override fun onResume() {
        super.onResume()
        Log.d(TAG, "onResume called")
    }

    override fun onPause() {
        super.onPause()
        Log.d(TAG, "onPause called")
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "onDestroy called")
    }

    private fun isAndroidTV(): Boolean {
        val uiModeManager = getSystemService(UI_MODE_SERVICE) as android.app.UiModeManager
        return uiModeManager.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION
    }

    private fun getDeviceType(): String {
        return when {
            isAndroidTV() -> "tv"
            isTablet() -> "tablet"
            else -> "phone"
        }
    }

    private fun isTablet(): Boolean {
        val screenLayout = resources.configuration.screenLayout
        val screenSize = screenLayout and Configuration.SCREENLAYOUT_SIZE_MASK
        return screenSize >= Configuration.SCREENLAYOUT_SIZE_LARGE
    }

    /**
     * Get EPG info for a channel from Flutter via MethodChannel
     */
    fun getEpgInfo(channelName: String, callback: (Map<String, Any?>?) -> Unit) {
        playerMethodChannel?.invokeMethod(
            "getEpgInfo",
            mapOf("channelName" to channelName, "epgId" to null),
            object : MethodChannel.Result {
                override fun success(result: Any?) {
                    @Suppress("UNCHECKED_CAST")
                    callback(result as? Map<String, Any?>)
                }

                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                    Log.e(TAG, "getEpgInfo error: $errorCode - $errorMessage")
                    callback(null)
                }

                override fun notImplemented() {
                    Log.w(TAG, "getEpgInfo not implemented")
                    callback(null)
                }
            }
        )
    }

    /**
     * Toggle favorite status for a channel from native player
     */
    fun toggleFavorite(channelIndex: Int, callback: (Boolean?) -> Unit) {
        Log.d(TAG, "toggleFavorite: channelIndex=$channelIndex, playerMethodChannel=${playerMethodChannel != null}")
        if (playerMethodChannel == null) {
            Log.e(TAG, "toggleFavorite: playerMethodChannel is null")
            callback(null)
            return
        }
        playerMethodChannel?.invokeMethod(
            "toggleFavorite",
            mapOf("channelIndex" to channelIndex),
            object : MethodChannel.Result {
                override fun success(result: Any?) {
                    Log.d(TAG, "toggleFavorite success: result=$result")
                    callback(result as? Boolean)
                }

                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                    Log.e(TAG, "toggleFavorite error: $errorCode - $errorMessage")
                    callback(null)
                }

                override fun notImplemented() {
                    Log.w(TAG, "toggleFavorite not implemented")
                    callback(null)
                }
            }
        )
    }

    /**
     * Check if a channel is favorite
     */
    fun isFavorite(channelIndex: Int, callback: (Boolean) -> Unit) {
        playerMethodChannel?.invokeMethod(
            "isFavorite",
            mapOf("channelIndex" to channelIndex),
            object : MethodChannel.Result {
                override fun success(result: Any?) {
                    callback(result as? Boolean ?: false)
                }

                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                    Log.e(TAG, "isFavorite error: $errorCode - $errorMessage")
                    callback(false)
                }

                override fun notImplemented() {
                    Log.w(TAG, "isFavorite not implemented")
                    callback(false)
                }
            }
        )
    }

    /**
     * Add watch history for a channel
     */
    fun addWatchHistory(channelIndex: Int) {
        Log.d(TAG, "addWatchHistory: channelIndex=$channelIndex")
        playerMethodChannel?.invokeMethod(
            "addWatchHistory",
            mapOf("channelIndex" to channelIndex),
            object : MethodChannel.Result {
                override fun success(result: Any?) {
                    Log.d(TAG, "addWatchHistory success: $result")
                }

                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                    Log.e(TAG, "addWatchHistory error: $errorCode - $errorMessage")
                }

                override fun notImplemented() {
                    Log.w(TAG, "addWatchHistory not implemented")
                }
            }
        )
    }

    /**
     * Install APK file using FileProvider
     */
    private fun installApk(filePath: String) {
        Log.d(TAG, "Installing APK: $filePath")
        val file = File(filePath)
        if (!file.exists()) {
            throw Exception("APK file not found: $filePath")
        }

        val intent = Intent(Intent.ACTION_VIEW)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            // Android 7.0+ use FileProvider
            val uri = FileProvider.getUriForFile(
                this,
                "${packageName}.fileprovider",
                file
            )
            intent.setDataAndType(uri, "application/vnd.android.package-archive")
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        } else {
            // Older versions use file:// URI
            intent.setDataAndType(Uri.fromFile(file), "application/vnd.android.package-archive")
        }

        startActivity(intent)
    }
}
