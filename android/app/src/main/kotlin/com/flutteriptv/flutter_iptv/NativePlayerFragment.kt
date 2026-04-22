package com.flutteriptv.flutter_iptv

import android.net.TrafficStats
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.KeyEvent
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.ImageButton
import android.widget.ImageView
import android.widget.ProgressBar
import android.widget.TextView
import androidx.fragment.app.Fragment
import androidx.media3.common.C
import androidx.media3.common.Format
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.VideoSize
import androidx.media3.exoplayer.DecoderReuseEvaluation
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.analytics.AnalyticsListener
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.hls.HlsMediaSource
import androidx.media3.exoplayer.dash.DashMediaSource
import androidx.media3.ui.PlayerView
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.flutteriptv.flutter_iptv.MainActivity

class NativePlayerFragment : Fragment() {
    private val TAG = "NativePlayerFragment"

    private var player: ExoPlayer? = null
    private lateinit var playerView: PlayerView
    private lateinit var loadingIndicator: ProgressBar
    private lateinit var channelNameText: TextView
    private lateinit var statusText: TextView
    private lateinit var statusIndicator: View
    private lateinit var videoInfoText: TextView
    private lateinit var errorText: TextView
    private lateinit var backButton: ImageButton
    private lateinit var topBar: View
    private lateinit var bottomBar: View
    
    // EPG views
    private lateinit var epgContainer: View
    private lateinit var epgCurrentContainer: View
    private lateinit var epgNextContainer: View
    private lateinit var epgCurrentTitle: TextView
    private lateinit var epgCurrentTime: TextView
    private lateinit var epgNextTitle: TextView
    
    // Progress views (DLNA mode)
    private lateinit var progressContainer: View
    private lateinit var progressBar: android.widget.SeekBar
    private lateinit var progressCurrent: TextView
    private lateinit var progressDuration: TextView
    private lateinit var helpText: TextView
    
    // Category panel views
    private lateinit var categoryPanel: View
    private lateinit var categoryListContainer: View
    private lateinit var channelListContainer: View
    private lateinit var categoryList: RecyclerView
    private lateinit var channelList: RecyclerView
    private lateinit var channelListTitle: TextView
    
    // FPS display
    private lateinit var fpsText: TextView
    private var showFps: Boolean = true
    
    // Clock display
    private lateinit var clockText: TextView
    private var showClock: Boolean = true
    private var clockUpdateRunnable: Runnable? = null
    private val CLOCK_UPDATE_INTERVAL = 1000L
    
    // Source indicator
    private lateinit var sourceIndicator: View
    private lateinit var sourceText: TextView
    private var sourceIndicatorHideRunnable: Runnable? = null
    private val SOURCE_INDICATOR_HIDE_DELAY = 3000L
    
    // Focus/Active Border
    private lateinit var focusBorder: View

    // Long press detection for left key
    private var leftKeyDownTime = 0L
    private val LONG_PRESS_THRESHOLD = 500L // 500ms for long press
    private var longPressHandled = false // Prevent repeated triggering after long press
    private var isSeekingWithLeftRight = false // Mark if seeking with left/right keys
    private var seekSpeedMultiplier = 1 // Seeking speed multiplier (incremental)

    // Double click detection for left key (show category panel)
    private var lastLeftKeyUpTime = 0L
    private val LEFT_DOUBLE_CLICK_INTERVAL = 600L // Show category panel on double click within 600ms

    // Long press detection for right key (seeking)
    private var rightKeyDownTime = 0L
    private var rightLongPressHandled = false

    // Long press detection for center/enter key (favorite)
    private var centerKeyDownTime = 0L
    private var centerLongPressHandled = false
    private var isManualSwitching = false
    private var currentVerificationId = 0L

    private var currentUrl: String = ""
    private var currentName: String = ""
    private var currentIndex: Int = 0
    private var currentSourceIndex: Int = 0 // Current source index

    private var channelUrls: ArrayList<String> = arrayListOf()
    private var channelNames: ArrayList<String> = arrayListOf()
    private var channelGroups: ArrayList<String> = arrayListOf()
    private var channelSources: ArrayList<ArrayList<String>> = arrayListOf() // All sources for each channel
    private var channelLogos: ArrayList<String> = arrayListOf()
    private var channelEpgIds: ArrayList<String> = arrayListOf()
    private var channelIsSeekable: ArrayList<Boolean> = arrayListOf() // Whether each channel is seekable
    private var isDlnaMode: Boolean = false
    private var bufferStrength: String = "fast"
    private var progressBarMode: String = "auto" // Progress bar mode: auto, always, never

    // Category data
    private var categories: MutableList<CategoryItem> = mutableListOf()
    private var selectedCategoryIndex: Int = -1
    private var categoryPanelVisible = false
    private var showingChannelList = false

    // Redirect URL cache (avoid repeated resolution)
    private val redirectCache = mutableMapOf<String, Pair<String, Long>>()
    private val CACHE_EXPIRY_MS = 5 * 60 * 1000L // 5 minutes

    private val handler = Handler(Looper.getMainLooper())
    private var hideControlsRunnable: Runnable? = null
    private var controlsVisible = true
    private val CONTROLS_HIDE_DELAY = 3000L

    private var lastBackPressTime = 0L
    private val BACK_PRESS_INTERVAL = 2000L // Exit only if back pressed twice within 2 seconds

    // Double click OK to favorite
    private var lastOkPressTime = 0L
    private val OK_DOUBLE_CLICK_INTERVAL = 600L // Double click OK within 600ms to favorite

    private var videoWidth = 0
    private var videoHeight = 0
    private var videoCodec = ""
    private var isHardwareDecoder = false
    private var frameRate = 0f

    // Retry logic
    private var retryCount = 0
    private val MAX_RETRIES = 2 // 2 retries
    private val RETRY_DELAY = 500L // 0.5s for faster retry
    private var retryRunnable: Runnable? = null

    // Auto source switching flags
    private var isAutoSwitching = false // Mark if auto-switching source
    private var isAutoDetecting = false // Mark if auto-detecting source
    
    // FPS calculation
    private var lastRenderedFrameCount = 0L
    private var lastFpsUpdateTime = 0L
    private var fpsUpdateRunnable: Runnable? = null
    private val FPS_UPDATE_INTERVAL = 1000L
    
    // EPG update
    private var epgUpdateRunnable: Runnable? = null
    private val EPG_UPDATE_INTERVAL = 60000L // Update every minute

    // Progress update (DLNA mode)
    private var progressUpdateRunnable: Runnable? = null
    private val PROGRESS_UPDATE_INTERVAL = 1000L // Update every second

    // Network speed display
    private lateinit var speedText: TextView
    private var showNetworkSpeed: Boolean = true
    private var networkSpeedUpdateRunnable: Runnable? = null
    private val NETWORK_SPEED_UPDATE_INTERVAL = 1000L
    private var lastRxBytes = 0L
    private var lastSpeedUpdateTime = 0L
    private var currentSpeedBps = 0.0 // Current network speed bytes/s, used for bitrate display

    // Video info display
    private lateinit var resolutionText: TextView
    private var showVideoInfo: Boolean = true

    // Favorite icon
    private lateinit var favoriteIcon: ImageView
    private var isFavorite: Boolean = false

    var onCloseListener: (() -> Unit)? = null
    var onEnterMultiScreen: ((Int, Int) -> Unit)? = null  // Enter multi-screen mode, passing current channel and source index

    companion object {
        private const val ARG_VIDEO_URL = "video_url"
        private const val ARG_CHANNEL_NAME = "channel_name"
        private const val ARG_CHANNEL_INDEX = "channel_index"
        private const val ARG_CHANNEL_URLS = "channel_urls"
        private const val ARG_CHANNEL_NAMES = "channel_names"
        private const val ARG_CHANNEL_GROUPS = "channel_groups"
        private const val ARG_CHANNEL_SOURCES = "channel_sources"
        private const val ARG_CHANNEL_LOGOS = "channel_logos"
        private const val ARG_CHANNEL_EPG_IDS = "channel_epg_ids"
        private const val ARG_CHANNEL_IS_SEEKABLE = "channel_is_seekable"
        private const val ARG_IS_DLNA_MODE = "is_dlna_mode"
        private const val ARG_BUFFER_STRENGTH = "buffer_strength"
        private const val ARG_SHOW_FPS = "show_fps"
        private const val ARG_SHOW_CLOCK = "show_clock"
        private const val ARG_SHOW_NETWORK_SPEED = "show_network_speed"
        private const val ARG_SHOW_VIDEO_INFO = "show_video_info"
        private const val ARG_PROGRESS_BAR_MODE = "progress_bar_mode"
        private const val ARG_INITIAL_SOURCE_INDEX = "initial_source_index"

        fun newInstance(
            videoUrl: String,
            channelName: String,
            channelIndex: Int = 0,
            channelUrls: ArrayList<String>? = null,
            channelNames: ArrayList<String>? = null,
            channelGroups: ArrayList<String>? = null,
            channelSources: ArrayList<ArrayList<String>>? = null,
            channelLogos: ArrayList<String>? = null,
            channelEpgIds: ArrayList<String>? = null,
            channelIsSeekable: ArrayList<Boolean>? = null,
            isDlnaMode: Boolean = false,
            bufferStrength: String = "fast",
            showFps: Boolean = true,
            showClock: Boolean = true,
            showNetworkSpeed: Boolean = true,
            showVideoInfo: Boolean = true,
            progressBarMode: String = "auto",
            initialSourceIndex: Int = 0
        ): NativePlayerFragment {
            return NativePlayerFragment().apply {
                arguments = Bundle().apply {
                    putString(ARG_VIDEO_URL, videoUrl)
                    putString(ARG_CHANNEL_NAME, channelName)
                    putInt(ARG_CHANNEL_INDEX, channelIndex)
                    channelUrls?.let { putStringArrayList(ARG_CHANNEL_URLS, it) }
                    channelNames?.let { putStringArrayList(ARG_CHANNEL_NAMES, it) }
                    channelGroups?.let { putStringArrayList(ARG_CHANNEL_GROUPS, it) }
                    channelSources?.let { putSerializable(ARG_CHANNEL_SOURCES, it) }
                    channelLogos?.let { putStringArrayList(ARG_CHANNEL_LOGOS, it) }
                    channelEpgIds?.let { putStringArrayList(ARG_CHANNEL_EPG_IDS, it) }
                    channelIsSeekable?.let { putBooleanArray(ARG_CHANNEL_IS_SEEKABLE, it.toBooleanArray()) }
                    putBoolean(ARG_IS_DLNA_MODE, isDlnaMode)
                    putString(ARG_BUFFER_STRENGTH, bufferStrength)
                    putBoolean(ARG_SHOW_FPS, showFps)
                    putBoolean(ARG_SHOW_CLOCK, showClock)
                    putBoolean(ARG_SHOW_NETWORK_SPEED, showNetworkSpeed)
                    putBoolean(ARG_SHOW_VIDEO_INFO, showVideoInfo)
                    putString(ARG_PROGRESS_BAR_MODE, progressBarMode)
                    putInt(ARG_INITIAL_SOURCE_INDEX, initialSourceIndex)
                }
            }
        }
    }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View? {
        return inflater.inflate(R.layout.activity_native_player, container, false)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        Log.d(TAG, "onViewCreated")
        
        activity?.window?.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        arguments?.let {
            currentUrl = it.getString(ARG_VIDEO_URL, "")
            currentName = it.getString(ARG_CHANNEL_NAME, "")
            currentIndex = it.getInt(ARG_CHANNEL_INDEX, 0)
            channelUrls = it.getStringArrayList(ARG_CHANNEL_URLS) ?: arrayListOf()
            channelNames = it.getStringArrayList(ARG_CHANNEL_NAMES) ?: arrayListOf()
            channelGroups = it.getStringArrayList(ARG_CHANNEL_GROUPS) ?: arrayListOf()
            @Suppress("UNCHECKED_CAST")
            channelSources = it.getSerializable(ARG_CHANNEL_SOURCES) as? ArrayList<ArrayList<String>> ?: arrayListOf()
            channelLogos = it.getStringArrayList(ARG_CHANNEL_LOGOS) ?: arrayListOf()
            channelEpgIds = it.getStringArrayList(ARG_CHANNEL_EPG_IDS) ?: arrayListOf()
            // Read isSeekable array
            val isSeekableArray = it.getBooleanArray(ARG_CHANNEL_IS_SEEKABLE)
            channelIsSeekable = if (isSeekableArray != null) {
                ArrayList(isSeekableArray.toList())
            } else {
                arrayListOf()
            }
            isDlnaMode = it.getBoolean(ARG_IS_DLNA_MODE, false)
            bufferStrength = it.getString(ARG_BUFFER_STRENGTH, "fast") ?: "fast"
            progressBarMode = it.getString(ARG_PROGRESS_BAR_MODE, "auto") ?: "auto" // Read progress bar display mode
            showFps = it.getBoolean(ARG_SHOW_FPS, true)
            showClock = it.getBoolean(ARG_SHOW_CLOCK, true)
            showNetworkSpeed = it.getBoolean(ARG_SHOW_NETWORK_SPEED, true)
            showVideoInfo = it.getBoolean(ARG_SHOW_VIDEO_INFO, true)
            currentSourceIndex = it.getInt(ARG_INITIAL_SOURCE_INDEX, 0) // Use passed initial source index
        }

        Log.d(TAG, "=== Parameter reading completed ===")
        Log.d(TAG, "progressBarMode: $progressBarMode")
        Log.d(TAG, "isDlnaMode: $isDlnaMode")
        Log.d(TAG, "currentIndex: $currentIndex")
        Log.d(TAG, "channelIsSeekable.size: ${channelIsSeekable.size}")
        if (currentIndex >= 0 && currentIndex < channelIsSeekable.size) {
            Log.d(TAG, "Current channel isSeekable: ${channelIsSeekable[currentIndex]}")
        }
        Log.d(TAG, "Playing: $currentName (index $currentIndex of ${channelUrls.size}, isDlna=$isDlnaMode, sources=${getCurrentSources().size})")

        playerView = view.findViewById(R.id.player_view)
        loadingIndicator = view.findViewById(R.id.loading_indicator)
        channelNameText = view.findViewById(R.id.channel_name)
        statusText = view.findViewById(R.id.status_text)
        statusIndicator = view.findViewById(R.id.status_indicator)
        videoInfoText = view.findViewById(R.id.video_info)
        errorText = view.findViewById(R.id.error_text)
        backButton = view.findViewById(R.id.back_button)
        topBar = view.findViewById(R.id.top_bar)
        bottomBar = view.findViewById(R.id.bottom_bar)

        // Category panel views
        categoryPanel = view.findViewById(R.id.category_panel)
        categoryListContainer = view.findViewById(R.id.category_list_container)
        channelListContainer = view.findViewById(R.id.channel_list_container)
        categoryList = view.findViewById(R.id.category_list)
        channelList = view.findViewById(R.id.channel_list)
        channelListTitle = view.findViewById(R.id.channel_list_title)

        // EPG views
        epgContainer = view.findViewById(R.id.epg_container)
        epgCurrentContainer = view.findViewById(R.id.epg_current_container)
        epgNextContainer = view.findViewById(R.id.epg_next_container)
        epgCurrentTitle = view.findViewById(R.id.epg_current_title)
        epgCurrentTime = view.findViewById(R.id.epg_current_time)
        epgNextTitle = view.findViewById(R.id.epg_next_title)

        // Progress views (DLNA mode)
        progressContainer = view.findViewById(R.id.progress_container)
        progressBar = view.findViewById(R.id.progress_bar)
        progressCurrent = view.findViewById(R.id.progress_current)
        progressDuration = view.findViewById(R.id.progress_duration)
        helpText = view.findViewById(R.id.help_text)

        // Set progress bar seek listener
        progressBar.setOnSeekBarChangeListener(object : android.widget.SeekBar.OnSeekBarChangeListener {
            private var wasPlaying = false

            override fun onProgressChanged(seekBar: android.widget.SeekBar?, progress: Int, fromUser: Boolean) {
                if (fromUser) {
                    // Update time display in real-time when user drags
                    val p = player ?: return
                    val duration = p.duration
                    if (duration > 0) {
                        val position = (duration * progress / 100)
                        progressCurrent.text = formatTime(position)
                    }
                }
            }

            override fun onStartTrackingTouch(seekBar: android.widget.SeekBar?) {
                Log.d(TAG, "Progress bar tracking started")
                // Record playback state
                wasPlaying = player?.isPlaying ?: false
                // Pause playback
                player?.pause()
                // Stop progress updates
                stopProgressUpdate()
            }

            override fun onStopTrackingTouch(seekBar: android.widget.SeekBar?) {
                Log.d(TAG, "Progress bar tracking stopped")
                val p = player ?: return
                val duration = p.duration
                if (duration > 0) {
                    val progress = seekBar?.progress ?: 0
                    val position = (duration * progress / 100)
                    Log.d(TAG, "Seek to position: ${formatTime(position)} (${progress}%)")
                    p.seekTo(position)

                    // If it was playing before, continue playing
                    if (wasPlaying) {
                        p.play()
                    }

                    // Restart progress updates
                    startProgressUpdate()
                }
            }
        })

        // Show controls when progress bar gains focus
        progressBar.setOnFocusChangeListener { _, hasFocus ->
            if (hasFocus) {
                Log.d(TAG, "Progress bar gained focus")
                showControls()
            }
        }

        // FPS display
        fpsText = view.findViewById(R.id.fps_text)

        // Clock display
        clockText = view.findViewById(R.id.clock_text)

        // Network speed display
        speedText = view.findViewById(R.id.speed_text)

        // Video info display (resolution + bitrate)
        resolutionText = view.findViewById(R.id.resolution_text)

        // Favorite icon
        favoriteIcon = view.findViewById(R.id.favorite_icon)

        // Source indicator
        sourceIndicator = view.findViewById(R.id.source_indicator)
        sourceText = view.findViewById(R.id.source_text)

        channelNameText.text = currentName
        updateStatus("Loading")

        backButton.setOnClickListener {
            Log.d(TAG, "Back button clicked")
            closePlayer()
        }

        playerView.useController = false

        // Use unified progress bar visibility update method (based on user settings)
        Log.d(TAG, "=== Initializing progress bar visibility ===")
        updateProgressBarVisibility()

        // Setup category panel
        setupCategoryPanel()

        // Handle key events
        view.isFocusableInTouchMode = true
        view.requestFocus()
        view.setOnKeyListener { _, keyCode, event ->
            when (event.action) {
                KeyEvent.ACTION_DOWN -> handleKeyDown(keyCode, event)
                KeyEvent.ACTION_UP -> handleKeyUp(keyCode, event)
                else -> false
            }
        }

        initializePlayer()

        if (currentUrl.isNotEmpty()) {
            Log.d(TAG, "=== Starting first playback flow ===")
            Log.d(TAG, "Current URL: $currentUrl")
            Log.d(TAG, "Current channel: $currentName")

            // Detect and use first available source
            val sources = getCurrentSources()
            Log.d(TAG, "Obtained ${sources.size} sources")

            if (sources.size > 1 && currentSourceIndex == 0) {
                Log.d(TAG, "Channel has multiple sources and no specific source specified (index=0), starting detection in background thread...")

                // Show detecting status
                updateStatus("Detecting source...")
                showLoading()

                // Detect sources in background thread
                Thread {
                    var foundSourceIndex = 0
                    for (i in sources.indices) {
                        // Real-time UI update showing current detected source
                        activity?.runOnUiThread {
                            updateStatus("Detecting source ${i + 1}/${sources.size}")
                        }

                        Log.d(TAG, "Detecting source ${i + 1}/${sources.size}: ${sources[i]}")
                        if (testSource(sources[i])) {
                            foundSourceIndex = i
                            Log.d(TAG, "✓ Source ${i + 1} is available")
                            break
                        } else {
                            Log.d(TAG, "✗ Source ${i + 1} is not available")
                        }
                    }

                    val finalSourceIndex = foundSourceIndex
                    activity?.runOnUiThread {
                        currentSourceIndex = finalSourceIndex
                        val urlToPlay = sources[currentSourceIndex]
                        Log.d(TAG, "First play, using source ${currentSourceIndex + 1}/${sources.size}: $urlToPlay")
                        updateSourceIndicator()
                        playUrl(urlToPlay)
                    }
                }.start()
            } else {
                Log.d(TAG, "Playing specified source (index=$currentSourceIndex) or single-source channel directly")
                // Ensure index is within valid range
                if (currentSourceIndex < 0 || currentSourceIndex >= sources.size) {
                    currentSourceIndex = 0
                }

                val urlToPlay = if (sources.isNotEmpty()) {
                    sources[currentSourceIndex]
                } else {
                    currentUrl
                }

                Log.d(TAG, "Playback URL: $urlToPlay")
                playUrl(urlToPlay)
                updateSourceIndicator()
            }
        } else {
            Log.e(TAG, "Error: No video URL provided")
            showError("No video URL provided")
        }

        // Start clock update
        startClockUpdate()

        // Initialize EPG info
        refreshEpgInfo()

        // Start network speed update
        startNetworkSpeedUpdate()
        
        // Check initial favorite status
        checkInitialFavoriteStatus()
        
        showControls()
    }
    
    private fun setupCategoryPanel() {
        // Build category list from channel groups
        buildCategories()

        categoryList.layoutManager = LinearLayoutManager(requireContext())
        channelList.layoutManager = LinearLayoutManager(requireContext())

        // Add key listener to RecyclerView to handle back and left keys
        val recyclerKeyListener = View.OnKeyListener { _, keyCode, event ->
            if (event.action == KeyEvent.ACTION_DOWN) {
                when (keyCode) {
                    KeyEvent.KEYCODE_BACK, KeyEvent.KEYCODE_ESCAPE -> {
                        handleBackKey()
                        true
                    }
                    KeyEvent.KEYCODE_DPAD_LEFT -> {
                        handleBackKey()
                        true
                    }
                    else -> false
                }
            } else if (event.action == KeyEvent.ACTION_UP && keyCode == KeyEvent.KEYCODE_DPAD_LEFT) {
                // Reset long press flag when left key is released
                longPressHandled = false
                leftKeyDownTime = 0L
                true
            } else {
                false
            }
        }
        categoryList.setOnKeyListener(recyclerKeyListener)
        channelList.setOnKeyListener(recyclerKeyListener)

        // Category adapter
        categoryList.adapter = object : RecyclerView.Adapter<CategoryViewHolder>() {
            override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): CategoryViewHolder {
                val view = LayoutInflater.from(parent.context).inflate(R.layout.item_category, parent, false)
                return CategoryViewHolder(view)
            }

            override fun onBindViewHolder(holder: CategoryViewHolder, position: Int) {
                val item = categories[position]
                holder.nameText.text = item.name
                holder.countText.text = item.count.toString()
                // Keep selected state only when currently selected and channel list is showing
                holder.itemView.isSelected = showingChannelList && position == selectedCategoryIndex

                holder.itemView.setOnClickListener {
                    selectCategory(holder.adapterPosition)
                }

                // Add key listener to each item
                holder.itemView.setOnKeyListener { _, keyCode, event ->
                    if (event.action == KeyEvent.ACTION_DOWN) {
                        when (keyCode) {
                            KeyEvent.KEYCODE_BACK, KeyEvent.KEYCODE_ESCAPE -> {
                                handleBackKey()
                                true
                            }
                            KeyEvent.KEYCODE_DPAD_LEFT -> {
                                // If long press flag is set, ignore (user is still long-pressing)
                                if (!longPressHandled) {
                                    handleBackKey()
                                }
                                true
                            }
                            else -> false
                        }
                    } else if (event.action == KeyEvent.ACTION_UP && keyCode == KeyEvent.KEYCODE_DPAD_LEFT) {
                        // Reset long press flag when left key is released
                        longPressHandled = false
                        leftKeyDownTime = 0L
                        true
                    } else {
                        false
                    }
                }

                holder.itemView.setOnFocusChangeListener { _, hasFocus ->
                    if (hasFocus && !showingChannelList) {
                        // Temporarily show selection effect when gaining focus
                        holder.itemView.isSelected = true
                    } else if (!hasFocus && !(showingChannelList && holder.adapterPosition == selectedCategoryIndex)) {
                        // Clear selection effect when losing focus and not the currently selected category
                        holder.itemView.isSelected = false
                    }
                }
            }

            override fun getItemCount() = categories.size
        }
    }

    private fun buildCategories() {
        categories.clear()
        val groupOrder = mutableListOf<String>() // Maintain original order
        val groupMap = mutableMapOf<String, Int>()

        for (group in channelGroups) {
            val name = group.ifEmpty { getString(R.string.uncategorized) }
            if (!groupMap.containsKey(name)) {
                groupOrder.add(name) // Record order of first appearance
            }
            groupMap[name] = (groupMap[name] ?: 0) + 1
        }

        // Create category list based on original order
        for (name in groupOrder) {
            categories.add(CategoryItem(name, groupMap[name] ?: 0))
        }
    }

    private fun selectCategory(position: Int) {
        selectedCategoryIndex = position
        val category = categories[position]
        channelListTitle.text = category.name

        // Refresh category list to update selected state
        categoryList.adapter?.notifyDataSetChanged()

        // Get channels for this category
        val channelsInCategory = mutableListOf<ChannelItem>()
        val uncategorizedStr = getString(R.string.uncategorized)
        for (i in channelGroups.indices) {
            val groupName = channelGroups[i].ifEmpty { uncategorizedStr }
            if (groupName == category.name) {
                val isPlaying = i == currentIndex
                channelsInCategory.add(ChannelItem(i, channelNames.getOrElse(i) { "Channel $i" }, isPlaying))
            }
        }

        // Setup channel adapter
        channelList.adapter = object : RecyclerView.Adapter<ChannelViewHolder>() {
            override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ChannelViewHolder {
                val view = LayoutInflater.from(parent.context).inflate(R.layout.item_channel, parent, false)
                return ChannelViewHolder(view)
            }

            override fun onBindViewHolder(holder: ChannelViewHolder, position: Int) {
                val item = channelsInCategory[position]
                holder.nameText.text = item.name
                holder.playingIcon.visibility = if (item.isPlaying) View.VISIBLE else View.GONE
                holder.nameText.setTextColor(if (item.isPlaying) 0xFFE91E63.toInt() else 0xFFFFFFFF.toInt())

                holder.itemView.setOnClickListener {
                    switchChannel(item.index)
                    hideCategoryPanel()
                }

                // Add key listener to each item
                holder.itemView.setOnKeyListener { _, keyCode, event ->
                    if (event.action == KeyEvent.ACTION_DOWN) {
                        when (keyCode) {
                            KeyEvent.KEYCODE_BACK, KeyEvent.KEYCODE_ESCAPE -> {
                                handleBackKey()
                                true
                            }
                            KeyEvent.KEYCODE_DPAD_LEFT -> {
                                // If long press flag is set, ignore (user is still long-pressing)
                                if (!longPressHandled) {
                                    handleBackKey()
                                }
                                true
                            }
                            else -> false
                        }
                    } else if (event.action == KeyEvent.ACTION_UP && keyCode == KeyEvent.KEYCODE_DPAD_LEFT) {
                        // Reset long press flag when left key is released
                        longPressHandled = false
                        leftKeyDownTime = 0L
                        true
                    } else {
                        false
                    }
                }

                holder.itemView.setOnFocusChangeListener { v, hasFocus ->
                    v.isSelected = hasFocus
                }
            }

            override fun getItemCount() = channelsInCategory.size
        }

        // Show channel list
        channelListContainer.visibility = View.VISIBLE
        showingChannelList = true

        // Focus first channel
        channelList.post {
            channelList.findViewHolderForAdapterPosition(0)?.itemView?.requestFocus()
        }
    }
    private fun showCategoryPanel() {
        categoryPanelVisible = true
        showingChannelList = false
        categoryPanel.visibility = View.VISIBLE
        channelListContainer.visibility = View.GONE

        // Find the category where the current channel belongs
        val currentGroup = if (currentIndex >= 0 && currentIndex < channelGroups.size) {
            channelGroups[currentIndex].ifEmpty { getString(R.string.uncategorized) }
        } else {
            null
        }

        // Find category index
        val categoryIndex = if (currentGroup != null) {
            categories.indexOfFirst { it.name == currentGroup }
        } else {
            -1
        }

        if (categoryIndex >= 0) {
            // Auto-select category of current channel and expand channel list
            selectedCategoryIndex = categoryIndex

            // Refresh category list
            categoryList.adapter?.notifyDataSetChanged()

            // Scroll to the category
            categoryList.scrollToPosition(categoryIndex)

            // Auto-expand channel list and locate current channel
            selectCategoryAndLocateChannel(categoryIndex)
        } else {
            selectedCategoryIndex = -1
            // Refresh category list
            categoryList.adapter?.notifyDataSetChanged()

            // Focus first category
            categoryList.post {
                categoryList.findViewHolderForAdapterPosition(0)?.itemView?.requestFocus()
            }
        }

        // Cancel auto-hide
        hideControlsRunnable?.let { handler.removeCallbacks(it) }
    }

    private fun selectCategoryAndLocateChannel(position: Int) {
        selectedCategoryIndex = position
        val category = categories[position]
        channelListTitle.text = category.name

        // Refresh category list to update selected state
        categoryList.adapter?.notifyDataSetChanged()

        // Get channels for this category
        val channelsInCategory = mutableListOf<ChannelItem>()
        var currentChannelPositionInList = -1
        val uncategorizedStr = getString(R.string.uncategorized)

        for (i in channelGroups.indices) {
            val groupName = channelGroups[i].ifEmpty { uncategorizedStr }
            if (groupName == category.name) {
                val isPlaying = i == currentIndex
                if (isPlaying) {
                    currentChannelPositionInList = channelsInCategory.size
                }
                channelsInCategory.add(ChannelItem(i, channelNames.getOrElse(i) { "Channel $i" }, isPlaying))
            }
        }

        // Setup channel adapter
        channelList.adapter = object : RecyclerView.Adapter<ChannelViewHolder>() {
            override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ChannelViewHolder {
                val view = LayoutInflater.from(parent.context).inflate(R.layout.item_channel, parent, false)
                return ChannelViewHolder(view)
            }

            override fun onBindViewHolder(holder: ChannelViewHolder, position: Int) {
                val item = channelsInCategory[position]
                holder.nameText.text = item.name
                holder.playingIcon.visibility = if (item.isPlaying) View.VISIBLE else View.GONE
                holder.nameText.setTextColor(if (item.isPlaying) 0xFFE91E63.toInt() else 0xFFFFFFFF.toInt())

                holder.itemView.setOnClickListener {
                    switchChannel(item.index)
                    hideCategoryPanel()
                }

                // Add key listener to each item
                holder.itemView.setOnKeyListener { _, keyCode, event ->
                    if (event.action == KeyEvent.ACTION_DOWN) {
                        when (keyCode) {
                            KeyEvent.KEYCODE_BACK, KeyEvent.KEYCODE_ESCAPE -> {
                                handleBackKey()
                                true
                            }
                            KeyEvent.KEYCODE_DPAD_LEFT -> {
                                // If long press flag is set, ignore (user is still long-pressing)
                                if (!longPressHandled) {
                                    handleBackKey()
                                }
                                true
                            }
                            else -> false
                        }
                    } else if (event.action == KeyEvent.ACTION_UP && keyCode == KeyEvent.KEYCODE_DPAD_LEFT) {
                        // Reset long press flag when left key is released
                        longPressHandled = false
                        leftKeyDownTime = 0L
                        true
                    } else {
                        false
                    }
                }

                holder.itemView.setOnFocusChangeListener { v, hasFocus ->
                    v.isSelected = hasFocus
                }
            }

            override fun getItemCount() = channelsInCategory.size
        }

        // Show channel list
        channelListContainer.visibility = View.VISIBLE
        showingChannelList = true

        // Scroll to current channel and focus
        val focusPosition = if (currentChannelPositionInList >= 0) currentChannelPositionInList else 0
        channelList.post {
            channelList.scrollToPosition(focusPosition)
            channelList.post {
                channelList.findViewHolderForAdapterPosition(focusPosition)?.itemView?.requestFocus()
            }
        }
    }

    private fun hideCategoryPanel() {
        categoryPanelVisible = false
        showingChannelList = false
        selectedCategoryIndex = -1
        categoryPanel.visibility = View.GONE
        channelListContainer.visibility = View.GONE

        // Return focus to main view
        view?.requestFocus()
        scheduleHideControls()
    }

    fun handleBackKey(): Boolean {
        Log.d(TAG, "handleBackKey: categoryPanelVisible=$categoryPanelVisible, showingChannelList=$showingChannelList, longPressHandled=$longPressHandled")

        if (categoryPanelVisible) {
            if (showingChannelList) {
                // Go back to category list
                channelListContainer.visibility = View.GONE
                showingChannelList = false
                categoryList.findViewHolderForAdapterPosition(selectedCategoryIndex.coerceAtLeast(0))?.itemView?.requestFocus()
                return true
            }
            // Close category panel
            hideCategoryPanel()
            return true
        }

        // Double-click back to exit player
        val currentTime = System.currentTimeMillis()
        if (currentTime - lastBackPressTime < BACK_PRESS_INTERVAL) {
            closePlayer()
        } else {
            lastBackPressTime = currentTime
            // Show hint
            activity?.runOnUiThread {
                android.widget.Toast.makeText(requireContext(), getString(R.string.press_back_again_to_exit), android.widget.Toast.LENGTH_SHORT).show()
            }
        }
        return true
    }

    private fun handleKeyDown(keyCode: Int, event: KeyEvent): Boolean {
        Log.d(TAG, "handleKeyDown: keyCode=$keyCode, categoryPanelVisible=$categoryPanelVisible, isDlnaMode=$isDlnaMode, progressBarHasFocus=${progressBar.hasFocus()}")

        when (keyCode) {
            KeyEvent.KEYCODE_BACK, KeyEvent.KEYCODE_ESCAPE -> {
                // If seeking, exit seeking mode first
                if (isSeekingWithLeftRight) {
                    isSeekingWithLeftRight = false
                    showControls()
                    return true
                }
                return handleBackKey()
            }
            KeyEvent.KEYCODE_DPAD_CENTER, KeyEvent.KEYCODE_ENTER -> {
                if (!categoryPanelVisible) {
                    // Long press already handled, ignore subsequent events
                    if (centerLongPressHandled) {
                        return true
                    }
                    // Record press time
                    if (event.repeatCount == 0) {
                        centerKeyDownTime = System.currentTimeMillis()
                        centerLongPressHandled = false
                    }
                    // Detect long press - Enter multi-screen mode
                    if (event.repeatCount > 0 && !centerLongPressHandled &&
                        System.currentTimeMillis() - centerKeyDownTime >= LONG_PRESS_THRESHOLD) {
                        centerLongPressHandled = true
                        // Long press OK to enter multi-screen mode
                        if (!isDlnaMode && channelUrls.isNotEmpty()) {
                            onEnterMultiScreen?.invoke(currentIndex, currentSourceIndex)
                        }
                        return true
                    }
                }
                return true
            }
            KeyEvent.KEYCODE_DPAD_LEFT -> {
                // DLNA mode: Left key seeks back 10 seconds
                if (isDlnaMode) {
                    showControls()
                    player?.seekBack()
                    return true
                }

                // If long press already handled, continue handling repeat events (sustained seek back, incremental speed)
                if (longPressHandled) {
                    // Check if content is seekable
                    val currentIsSeekable = if (currentIndex >= 0 && currentIndex < channelIsSeekable.size) {
                        channelIsSeekable[currentIndex]
                    } else {
                        false
                    }

                    if (currentIsSeekable && progressContainer.visibility == View.VISIBLE) {
                        // Incremental speed: increase multiplier per repeat event (max 10x)
                        seekSpeedMultiplier = (seekSpeedMultiplier + 1).coerceAtMost(10)
                        val seekAmount = 5000 * seekSpeedMultiplier // 5s * multiplier

                        // Sustained seek back
                        player?.let { p ->
                            val currentPos = p.currentPosition
                            val newPos = (currentPos - seekAmount).coerceAtLeast(0)
                            p.seekTo(newPos)
                            Log.d(TAG, "Sustained seek back (${seekSpeedMultiplier}x): ${formatTime(currentPos)} -> ${formatTime(newPos)} (-${seekAmount/1000}s)")
                        }
                        showControls()
                    }
                    return true
                }

                // Don't handle long press when category panel is open, let item listener handle it
                if (categoryPanelVisible) {
                    return false
                }

                // Record press time for long press detection
                if (event.repeatCount == 0) {
                    leftKeyDownTime = System.currentTimeMillis()
                    longPressHandled = false
                    seekSpeedMultiplier = 1 // Reset speed multiplier
                    Log.d(TAG, "Left key down, starting timer")
                }

                // Detect long press - Seek (only if seekable)
                val pressDuration = System.currentTimeMillis() - leftKeyDownTime
                if (event.repeatCount > 0 && !longPressHandled && pressDuration >= LONG_PRESS_THRESHOLD) {
                    Log.d(TAG, "Detected left key long press, pressDuration=$pressDuration")

                    // Check if content is seekable
                    val currentIsSeekable = if (currentIndex >= 0 && currentIndex < channelIsSeekable.size) {
                        channelIsSeekable[currentIndex]
                    } else {
                        false
                    }

                    Log.d(TAG, "currentIsSeekable=$currentIsSeekable, progressVisible=${progressContainer.visibility == View.VISIBLE}")

                    if (currentIsSeekable && progressContainer.visibility == View.VISIBLE) {
                        longPressHandled = true
                        isSeekingWithLeftRight = true
                        seekSpeedMultiplier = 1 // Initial speed
                        // Seek back
                        player?.let { p ->
                            val currentPos = p.currentPosition
                            val newPos = (currentPos - 10000).coerceAtLeast(0) // Initial 10s seek back
                            p.seekTo(newPos)
                            Log.d(TAG, "Long press left to seek back: ${formatTime(currentPos)} -> ${formatTime(newPos)}")
                        }
                        showControls()
                        return true
                    } else {
                        Log.d(TAG, "Seek conditions not met")
                    }
                }
                return true
            }
            KeyEvent.KEYCODE_DPAD_RIGHT -> {
                // DLNA mode: Right key seeks forward 10 seconds
                if (isDlnaMode) {
                    showControls()
                    player?.seekForward()
                    return true
                }

                // If long press already handled, continue handling repeat events (sustained seek forward, incremental speed)
                if (rightLongPressHandled) {
                    // Check if content is seekable
                    val currentIsSeekable = if (currentIndex >= 0 && currentIndex < channelIsSeekable.size) {
                        channelIsSeekable[currentIndex]
                    } else {
                        false
                    }

                    if (currentIsSeekable && progressContainer.visibility == View.VISIBLE) {
                        // Incremental speed: increase multiplier per repeat event (max 10x)
                        seekSpeedMultiplier = (seekSpeedMultiplier + 1).coerceAtMost(10)
                        val seekAmount = 5000 * seekSpeedMultiplier // 5s * multiplier

                        // Sustained seek forward
                        player?.let { p ->
                            val currentPos = p.currentPosition
                            val duration = p.duration
                            val newPos = (currentPos + seekAmount).coerceAtMost(duration)
                            p.seekTo(newPos)
                            Log.d(TAG, "Sustained seek forward (${seekSpeedMultiplier}x): ${formatTime(currentPos)} -> ${formatTime(newPos)} (+${seekAmount/1000}s)")
                        }
                        showControls()
                    }
                    return true
                }

                // Don't handle when category panel is open
                if (categoryPanelVisible) {
                    return false
                }

                // Record press time for long press detection
                if (event.repeatCount == 0) {
                    rightKeyDownTime = System.currentTimeMillis()
                    rightLongPressHandled = false
                    seekSpeedMultiplier = 1 // Reset speed multiplier
                    Log.d(TAG, "Right key down, starting timer")
                }

                // Detect long press - Seek (only if seekable)
                val pressDuration = System.currentTimeMillis() - rightKeyDownTime
                if (event.repeatCount > 0 && !rightLongPressHandled && pressDuration >= LONG_PRESS_THRESHOLD) {
                    Log.d(TAG, "Detected right key long press, pressDuration=$pressDuration")

                    // Check if content is seekable
                    val currentIsSeekable = if (currentIndex >= 0 && currentIndex < channelIsSeekable.size) {
                        channelIsSeekable[currentIndex]
                    } else {
                        false
                    }

                    Log.d(TAG, "currentIsSeekable=$currentIsSeekable, progressVisible=${progressContainer.visibility == View.VISIBLE}")

                    if (currentIsSeekable && progressContainer.visibility == View.VISIBLE) {
                        rightLongPressHandled = true
                        isSeekingWithLeftRight = true
                        seekSpeedMultiplier = 1 // Initial speed
                        // Seek forward
                        player?.let { p ->
                            val currentPos = p.currentPosition
                            val duration = p.duration
                            val newPos = (currentPos + 10000).coerceAtMost(duration) // Initial 10s seek forward
                            p.seekTo(newPos)
                            Log.d(TAG, "Long press right to seek forward: ${formatTime(currentPos)} -> ${formatTime(newPos)}")
                        }
                        showControls()
                        return true
                    } else {
                        Log.d(TAG, "Seek conditions not met")
                    }
                }
                return true
            }
            KeyEvent.KEYCODE_DPAD_UP, KeyEvent.KEYCODE_CHANNEL_UP -> {
                if (!categoryPanelVisible) {
                    // DLNA mode only shows control bar
                    if (isDlnaMode) {
                        showControls()
                        return true
                    }
                    Log.d(TAG, "Channel UP pressed")
                    previousChannel()
                }
                return false // Let RecyclerView handle if panel is visible
            }
            KeyEvent.KEYCODE_DPAD_DOWN, KeyEvent.KEYCODE_CHANNEL_DOWN -> {
                if (!categoryPanelVisible) {
                    // DLNA mode only shows control bar
                    if (isDlnaMode) {
                        showControls()
                        return true
                    }
                    Log.d(TAG, "Channel DOWN pressed")
                    nextChannel()
                }
                return false // Let RecyclerView handle if panel is visible
            }
            KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE -> {
                showControls()
                player?.let {
                    if (it.isPlaying) it.pause() else it.play()
                }
                return true
            }
        }

        if (!categoryPanelVisible) {
            showControls()
        }
        return false
    }

    private fun handleKeyUp(keyCode: Int, event: KeyEvent): Boolean {
        when (keyCode) {
            KeyEvent.KEYCODE_DPAD_CENTER, KeyEvent.KEYCODE_ENTER -> {
                // Reset long press flag
                val wasLongPressHandled = centerLongPressHandled
                centerLongPressHandled = false

                // If handled by long press, don't handle again
                if (wasLongPressHandled) {
                    centerKeyDownTime = 0L
                    return true
                }

                // Don't handle when category panel is visible
                if (categoryPanelVisible) {
                    centerKeyDownTime = 0L
                    return true
                }

                // Short press handling - Play/Pause or double-click to favorite
                val pressDuration = System.currentTimeMillis() - centerKeyDownTime
                if (centerKeyDownTime > 0 && pressDuration < LONG_PRESS_THRESHOLD) {
                    val currentTime = System.currentTimeMillis()
                    val timeSinceLastOk = currentTime - lastOkPressTime
                    Log.d(TAG, "OK key up: pressDuration=$pressDuration, timeSinceLastOk=$timeSinceLastOk, lastOkPressTime=$lastOkPressTime")
                    // Detect double click - Favorite
                    if (lastOkPressTime > 0 && timeSinceLastOk < OK_DOUBLE_CLICK_INTERVAL) {
                        Log.d(TAG, "Double click detected, toggling favorite")
                        toggleFavorite()
                        lastOkPressTime = 0L
                    } else {
                        // Single click - Play/Pause
                        lastOkPressTime = currentTime
                        showControls()
                        player?.let {
                            if (it.isPlaying) it.pause() else it.play()
                        }
                    }
                }
                centerKeyDownTime = 0L
                return true
            }
            KeyEvent.KEYCODE_DPAD_LEFT -> {
                // Reset long press flag and speed multiplier
                val wasLongPressHandled = longPressHandled
                longPressHandled = false
                seekSpeedMultiplier = 1 // Reset speed multiplier

                // If handled by long press (seeking), don't handle again
                if (wasLongPressHandled) {
                    leftKeyDownTime = 0L
                    Log.d(TAG, "Left key released, speed multiplier reset")
                    return true
                }

                // DLNA mode not handled
                if (isDlnaMode) {
                    leftKeyDownTime = 0L
                    return true
                }

                // Don't handle when category panel is visible
                if (categoryPanelVisible) {
                    leftKeyDownTime = 0L
                    return true
                }

                // Short press left handling
                val pressDuration = System.currentTimeMillis() - leftKeyDownTime
                if (leftKeyDownTime > 0 && pressDuration < LONG_PRESS_THRESHOLD) {
                    val currentTime = System.currentTimeMillis()
                    val timeSinceLastLeft = currentTime - lastLeftKeyUpTime
                    Log.d(TAG, "Left key up: pressDuration=$pressDuration, timeSinceLastLeft=$timeSinceLastLeft")

                    // Detect double click - Show category panel
                    if (lastLeftKeyUpTime > 0 && timeSinceLastLeft < LEFT_DOUBLE_CLICK_INTERVAL) {
                        Log.d(TAG, "Double click left detected, showing category panel")
                        showCategoryPanel()
                        lastLeftKeyUpTime = 0L
                    } else {
                        // Single click - Switch source (if multiple sources exist)
                        lastLeftKeyUpTime = currentTime
                        if (hasMultipleSources()) {
                            previousSource()
                        }
                    }
                }
                leftKeyDownTime = 0L
                return true
            }
            KeyEvent.KEYCODE_DPAD_RIGHT -> {
                // Reset long press flag and speed multiplier
                val wasLongPressHandled = rightLongPressHandled
                rightLongPressHandled = false
                seekSpeedMultiplier = 1 // Reset speed multiplier

                // If handled by long press (seeking), don't handle again
                if (wasLongPressHandled) {
                    rightKeyDownTime = 0L
                    Log.d(TAG, "Right key released, speed multiplier reset")
                    return true
                }

                // DLNA mode not handled
                if (isDlnaMode) {
                    rightKeyDownTime = 0L
                    return true
                }

                // Don't handle when category panel is visible
                if (categoryPanelVisible) {
                    rightKeyDownTime = 0L
                    return true
                }

                // Short press right - Switch to next source
                val pressDuration = System.currentTimeMillis() - rightKeyDownTime
                if (rightKeyDownTime > 0 && pressDuration < LONG_PRESS_THRESHOLD) {
                    if (hasMultipleSources()) {
                        nextSource()
                    }
                }
                rightKeyDownTime = 0L
                return true
            }
        }
        return false
    }

    private fun initializePlayer() {
        Log.d(TAG, "Initializing ExoPlayer")
        
        // Use DefaultRenderersFactory with FFmpeg extension for MP2/AC3/DTS audio support
        val renderersFactory = DefaultRenderersFactory(requireContext())
            .setExtensionRendererMode(DefaultRenderersFactory.EXTENSION_RENDERER_MODE_PREFER)
        
        // Configure load control - based on buffer strength settings
        val (minBuffer, maxBuffer, playbackBuffer, rebufferBuffer) = when (bufferStrength) {
            "fast" -> arrayOf(15000, 30000, 500, 1500)      // Fast: 0.5s to start playback
            "balanced" -> arrayOf(30000, 60000, 1500, 3000) // Balanced: 1.5s to start playback
            "stable" -> arrayOf(50000, 120000, 2500, 5000)  // Stable: 2.5s to start playback
            else -> arrayOf(15000, 30000, 500, 1500)
        }
        Log.d(TAG, "Buffer strength: $bufferStrength (playback: ${playbackBuffer}ms)")

        val loadControl = DefaultLoadControl.Builder()
            .setBufferDurationsMs(minBuffer, maxBuffer, playbackBuffer, rebufferBuffer)
            .build()

        // Configure HTTP data source with reasonable timeouts
        val dataSourceFactory = DefaultHttpDataSource.Factory()
            .setConnectTimeoutMs(5000)  // 5s connection timeout (redirects may take longer)
            .setReadTimeoutMs(10000)    // 10s read timeout
            .setAllowCrossProtocolRedirects(true)  // Allow cross-protocol redirects (HTTP->HTTPS)
            .setUserAgent("Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36")

        // Configure MediaSourceFactory to support HLS/DASH formats
        val mediaSourceFactory = DefaultMediaSourceFactory(requireContext())
            .setDataSourceFactory(dataSourceFactory)

        player = ExoPlayer.Builder(requireContext(), renderersFactory)
            .setLoadControl(loadControl)
            .setMediaSourceFactory(mediaSourceFactory)
            .setVideoChangeFrameRateStrategy(C.VIDEO_CHANGE_FRAME_RATE_STRATEGY_OFF)
            .build().also { exoPlayer ->
            playerView.player = exoPlayer
            exoPlayer.playWhenReady = true
            exoPlayer.repeatMode = Player.REPEAT_MODE_OFF

            // Set video scaling mode
            exoPlayer.videoScalingMode = C.VIDEO_SCALING_MODE_SCALE_TO_FIT

            exoPlayer.addListener(object : Player.Listener {
                override fun onPlaybackStateChanged(playbackState: Int) {
                    when (playbackState) {
                        Player.STATE_BUFFERING -> {
                            showLoading()
                            updateStatus("Buffering")
                        }
                        Player.STATE_READY -> {
                            hideLoading()
                            updateStatus("LIVE")
                            // Delay 3s before resetting to ensure playback is truly stable
                            // This prevents short READY states from prematurely resetting retry count
                            startFpsCalculation() // Start calculating FPS
                        }
                        Player.STATE_ENDED -> {
                            updateStatus("Ended")
                            stopFpsCalculation()
                        }
                        Player.STATE_IDLE -> {
                            updateStatus("Idle")
                            stopFpsCalculation()
                        }
                    }
                }

                override fun onIsPlayingChanged(isPlaying: Boolean) {
                    if (isPlaying) {
                        updateStatus("LIVE")
                        // Wait 3s to confirm stable playback then reset retry count
                        handler.postDelayed({
                            if (player?.isPlaying == true) {
                                Log.d(TAG, "Playback stable, resetting retry count")
                                retryCount = 0
                                isAutoSwitching = false
                            }
                        }, 3000)
                    } else if (player?.playbackState == Player.STATE_READY) {
                        updateStatus("Paused")
                    }
                }

                override fun onVideoSizeChanged(videoSize: VideoSize) {
                    videoWidth = videoSize.width
                    videoHeight = videoSize.height
                    updateVideoInfoDisplay()
                }

                override fun onPlayerError(error: PlaybackException) {
                    Log.e(TAG, "Player error: ${error.message}", error)
                    Log.e(TAG, "Error type: ${error.errorCode}")
                    Log.d(TAG, "Current URL: $currentUrl")
                    error.cause?.let { cause ->
                        Log.e(TAG, "Error cause: ${cause.message}", cause)
                    }

                    // Auto retry logic
                    if (retryCount < MAX_RETRIES) {
                        retryCount++
                        Log.d(TAG, "Playback error, attempting retry ($retryCount/$MAX_RETRIES): ${error.message}")
                        updateStatus("Retrying")
                        showLoading()

                        retryRunnable?.let { handler.removeCallbacks(it) }
                        retryRunnable = Runnable {
                            if (currentUrl.isNotEmpty()) {
                                playUrl(currentUrl)
                            }
                        }
                        handler.postDelayed(retryRunnable!!, RETRY_DELAY)
                    } else {
                        // Max retries reached, check for other sources
                        val sources = getCurrentSources()
                        if (sources.size > 1) {
                            // Start auto detection
                            isAutoDetecting = true

                            // Show auto-switching status
                            updateStatus("Auto-switching source...")
                            showLoading()

                            // Asynchronously detect sources in background
                            Thread {
                                // Find next available source
                                var nextSourceIndex = currentSourceIndex + 1
                                var foundAvailableSource = false

                                // Search forward
                                while (nextSourceIndex < sources.size && isAutoDetecting) {
                                    // Update UI with current detection progress
                                    activity?.runOnUiThread {
                                        updateStatus("Checking source ${nextSourceIndex + 1}/${sources.size}")
                                    }

                                    // Check source availability
                                    Log.d(TAG, "Current source (${currentSourceIndex + 1}/${sources.size}) failed, checking source ${nextSourceIndex + 1}")
                                    if (testSource(sources[nextSourceIndex])) {
                                        Log.d(TAG, "Source ${nextSourceIndex + 1} is available")
                                        foundAvailableSource = true
                                        break
                                    } else {
                                        Log.d(TAG, "Source ${nextSourceIndex + 1} is not available, trying next")
                                    }
                                    nextSourceIndex++
                                }

                                val finalNextSourceIndex = nextSourceIndex
                                val finalFoundAvailableSource = foundAvailableSource

                                activity?.runOnUiThread {
                                    isAutoDetecting = false

                                    if (finalFoundAvailableSource) {
                                        // Found available source, switch to it
                                        Log.d(TAG, "Switching to available source ${finalNextSourceIndex + 1}")
                                        isAutoSwitching = true
                                        currentSourceIndex = finalNextSourceIndex
                                        retryCount = 0 // Reset retry count
                                        val newUrl = sources[currentSourceIndex]
                                        currentUrl = newUrl

                                        updateSourceIndicator()
                                        showSourceIndicator()
                                        playUrl(newUrl)
                                    } else {
                                        // Try fallback to next source if any
                                        val fallbackIndex = currentSourceIndex + 1
                                        if (fallbackIndex < sources.size) {
                                            Log.d(TAG, "Auto-detection failed, fallback: forcing next source ${fallbackIndex + 1}")
                                            isAutoSwitching = true
                                            currentSourceIndex = fallbackIndex
                                            retryCount = 0
                                            val newUrl = sources[currentSourceIndex]
                                            currentUrl = newUrl

                                            updateSourceIndicator()
                                            showSourceIndicator()
                                            playUrl(newUrl)
                                        } else {
                                            // All sources unavailable
                                            Log.d(TAG, "All ${sources.size} sources are unavailable")
                                            showError("Playback failed: ${error.message}")
                                            updateStatus("Offline")
                                        }
                                    }
                                }
                            }.start()
                        } else {
                            // Single source, show error
                            showError("Playback failed: ${error.message}")
                            updateStatus("Offline")
                        }
                    }
                }
            })

            exoPlayer.addAnalyticsListener(object : AnalyticsListener {
                override fun onVideoDecoderInitialized(
                    eventTime: AnalyticsListener.EventTime,
                    decoderName: String,
                    initializedTimestampMs: Long,
                    initializationDurationMs: Long
                ) {
                    isHardwareDecoder = decoderName.contains("c2.") ||
                                       decoderName.contains("OMX.") ||
                                       !decoderName.contains("sw")
                    videoCodec = decoderName
                    updateVideoInfoDisplay()
                }

                override fun onVideoInputFormatChanged(
                    eventTime: AnalyticsListener.EventTime,
                    format: Format,
                    decoderReuseEvaluation: DecoderReuseEvaluation?
                ) {
                    // Only get codec info from format, FPS is calculated via rendered frames
                    format.codecs?.let {
                        if (it.isNotEmpty()) videoCodec = it
                    }
                    updateVideoInfoDisplay()
                }
            })
        }
    }

    // Resolve real playback address (handles 302 redirects with caching)
    private fun resolveRealPlayUrl(url: String): String {
        // Check cache
        val cached = redirectCache[url]
        if (cached != null) {
            val (cachedUrl, timestamp) = cached
            if (System.currentTimeMillis() - timestamp < CACHE_EXPIRY_MS) {
                Log.d(TAG, "Using cached redirect: $url -> $cachedUrl")
                return cachedUrl
            } else {
                // Cache expired, remove
                redirectCache.remove(url)
            }
        }

        return try {
            val connection = java.net.URL(url).openConnection() as java.net.HttpURLConnection
            connection.instanceFollowRedirects = false
            connection.setRequestProperty("User-Agent", "miguvideo_android")
            connection.connectTimeout = 5000
            connection.readTimeout = 5000

            connection.connect()

            if (connection.responseCode in 300..399) {
                val location = connection.getHeaderField("Location")
                connection.disconnect()

                if (location != null) {
                    Log.d(TAG, "Resolved redirect: $url -> $location")
                    // Cache result
                    redirectCache[url] = Pair(location, System.currentTimeMillis())
                    location
                } else {
                    Log.d(TAG, "No Location header, using original URL: $url")
                    url
                }
            } else {
                connection.disconnect()
                Log.d(TAG, "No redirect, using original URL: $url")
                url
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to resolve playback address: ${e.message}", e)
            // Return original URL on failure, let player try
            url
        }
    }

    private fun playUrl(url: String) {
        Log.d(TAG, "Playing URL: $url")
        videoWidth = 0
        videoHeight = 0
        frameRate = 0f
        stopFpsCalculation()
        updateVideoInfoDisplay()

        showLoading()
        updateStatus("Loading")

        // Resolve real address in background thread
        Thread {
            val realUrl = resolveRealPlayUrl(url)

            activity?.runOnUiThread {
                Log.d(TAG, "Using playback address: $realUrl")
                val mediaItem = MediaItem.fromUri(realUrl)
                player?.setMediaItem(mediaItem)
                player?.prepare()
            }
        }.start()
    }

    // Calculate actual FPS through rendered frames
    private fun startFpsCalculation() {
        stopFpsCalculation()
        lastRenderedFrameCount = 0L
        lastFpsUpdateTime = System.currentTimeMillis()

        fpsUpdateRunnable = Runnable {
            calculateFps()
            handler.postDelayed(fpsUpdateRunnable!!, FPS_UPDATE_INTERVAL)
        }
        handler.postDelayed(fpsUpdateRunnable!!, FPS_UPDATE_INTERVAL)
    }

    private fun stopFpsCalculation() {
        fpsUpdateRunnable?.let { handler.removeCallbacks(it) }
        fpsUpdateRunnable = null
    }

    private fun calculateFps() {
        val p = player ?: return

        // Skip calculation if not playing, but update timestamp
        if (!p.isPlaying) {
            lastFpsUpdateTime = System.currentTimeMillis()
            lastRenderedFrameCount = 0L
            return
        }

        val currentTime = System.currentTimeMillis()
        val timeDelta = currentTime - lastFpsUpdateTime

        // Interval too short, skip (but don't update timestamp, wait for next accumulation)
        if (timeDelta < 800) return

        try {
            // Get rendered frames from videoDecoderCounters
            val counters = p.videoDecoderCounters
            if (counters != null) {
                val currentFrames = counters.renderedOutputBufferCount.toLong()

                if (lastRenderedFrameCount > 0 && currentFrames > lastRenderedFrameCount) {
                    val frameDelta = currentFrames - lastRenderedFrameCount
                    val calculatedFps = frameDelta * 1000f / timeDelta

                    // Update only if in reasonable range (10-120 fps)
                    if (calculatedFps in 10f..120f) {
                        frameRate = calculatedFps
                        updateVideoInfoDisplay()
                    }
                }

                lastRenderedFrameCount = currentFrames
                lastFpsUpdateTime = currentTime
            }
        } catch (e: Exception) {
            Log.d(TAG, "Failed to calculate FPS: ${e.message}")
        }
    }

    // Clock update
    private fun startClockUpdate() {
        stopClockUpdate()
        clockUpdateRunnable = Runnable {
            updateClock()
            handler.postDelayed(clockUpdateRunnable!!, CLOCK_UPDATE_INTERVAL)
        }
        handler.post(clockUpdateRunnable!!)
    }

    private fun stopClockUpdate() {
        clockUpdateRunnable?.let { handler.removeCallbacks(it) }
        clockUpdateRunnable = null
    }

    private fun updateClock() {
        activity?.runOnUiThread {
            val sdf = java.text.SimpleDateFormat("HH:mm:ss", java.util.Locale.getDefault())
            clockText.text = sdf.format(java.util.Date())
            // Show/hide clock based on settings
            clockText.visibility = if (showClock) View.VISIBLE else View.GONE
        }
    }

    // Network speed update
    private fun startNetworkSpeedUpdate() {
        stopNetworkSpeedUpdate()
        lastRxBytes = TrafficStats.getTotalRxBytes()
        lastSpeedUpdateTime = System.currentTimeMillis()

        networkSpeedUpdateRunnable = Runnable {
            updateNetworkSpeed()
            handler.postDelayed(networkSpeedUpdateRunnable!!, NETWORK_SPEED_UPDATE_INTERVAL)
        }
        handler.postDelayed(networkSpeedUpdateRunnable!!, NETWORK_SPEED_UPDATE_INTERVAL)
    }

    private fun stopNetworkSpeedUpdate() {
        networkSpeedUpdateRunnable?.let { handler.removeCallbacks(it) }
        networkSpeedUpdateRunnable = null
    }

    private fun updateNetworkSpeed() {
        if (!showNetworkSpeed) {
            activity?.runOnUiThread {
                speedText.visibility = View.GONE
            }
            return
        }

        try {
            val currentRxBytes = TrafficStats.getTotalRxBytes()
            val currentTime = System.currentTimeMillis()
            val timeDelta = currentTime - lastSpeedUpdateTime

            val speedStr: String
            if (timeDelta > 0 && lastRxBytes > 0) {
                val bytesDelta = currentRxBytes - lastRxBytes
                val speedBytesPerSecond = bytesDelta * 1000.0 / timeDelta
                currentSpeedBps = speedBytesPerSecond // Save current speed for bitrate display
                val speedKbps = speedBytesPerSecond / 1024.0 // KB/s
                val speedMbps = speedKbps / 1024.0 // MB/s

                speedStr = if (speedMbps >= 1.0) {
                    "↓%.1f MB/s".format(speedMbps)
                } else if (speedKbps >= 1.0) {
                    "↓%.0f KB/s".format(speedKbps)
                } else {
                    "↓%.0f B/s".format(speedBytesPerSecond)
                }
            } else {
                speedStr = "↓--"
            }

            lastRxBytes = currentRxBytes
            lastSpeedUpdateTime = currentTime

            activity?.runOnUiThread {
                this.speedText.text = speedStr
                this.speedText.visibility = View.VISIBLE
            }
        } catch (e: Exception) {
            Log.d(TAG, "Failed to update network speed: ${e.message}")
            activity?.runOnUiThread {
                speedText.visibility = View.GONE
            }
        }
    }

    // Get all sources for current channel
    private fun getCurrentSources(): List<String> {
        return if (currentIndex >= 0 && currentIndex < channelSources.size) {
            channelSources[currentIndex]
        } else if (currentIndex >= 0 && currentIndex < channelUrls.size) {
            listOf(channelUrls[currentIndex])
        } else {
            listOf(currentUrl)
        }
    }

    // Check if current channel has multiple sources
    private fun hasMultipleSources(): Boolean {
        return getCurrentSources().size > 1
    }

    // Switch to next source (loop detection until available source found)
    private fun nextSource() {
        switchSourceIteratively(1)
    }

    // Switch to previous source (loop detection until available source found)
    private fun previousSource() {
        switchSourceIteratively(-1)
    }

    // Common logic for loop switching sources
    private fun switchSourceIteratively(direction: Int) {
        val sources = getCurrentSources()
        if (sources.size <= 1) return
        
        // Prevent repeated manual switching
        if (isManualSwitching) {
            activity?.let {
                android.widget.Toast.makeText(it, "Detecting source, please wait...", android.widget.Toast.LENGTH_SHORT).show()
            }
            return
        }
        
        // Increment verification ID, immediately invalidating all previous background tasks
        currentVerificationId++
        val myVerificationId = currentVerificationId
        
        // Cancel ongoing auto-detection and retries
        isAutoDetecting = false
        retryRunnable?.let { handler.removeCallbacks(it) }
        
        // Reset status on manual source switch
        retryCount = 0
        isAutoSwitching = false
        
        // Lock
        isManualSwitching = true
        
        showControls()
        showLoading()
        updateStatus("Searching for available source...")
        
        val startIndex = currentSourceIndex
        
        Thread {
            if (myVerificationId != currentVerificationId) {
                activity?.runOnUiThread { isManualSwitching = false }
                return@Thread
            }
            
            try {
                var found = false
                var loopCount = 0
                // Calculate starting checkpoint based on direction
                var indexToCheck = if (direction > 0) {
                    (startIndex + 1) % sources.size
                } else {
                    (startIndex - 1 + sources.size) % sources.size
                }
                
                // Loop detection, trying up to sources.size times
                while (loopCount < sources.size) {
                    if (myVerificationId != currentVerificationId) {
                        activity?.runOnUiThread { isManualSwitching = false }
                        return@Thread
                    }

                    // Stop if back to starting point (except first check)
                    if (indexToCheck == startIndex) {
                        break
                    }

                    activity?.runOnUiThread {
                        if (myVerificationId == currentVerificationId) {
                            updateStatus("Detecting source ${indexToCheck + 1}/${sources.size}")
                            showControls()
                        }
                    }
                    
                    Log.d(TAG, "Detecting source ${indexToCheck + 1}/${sources.size}: ${sources[indexToCheck]}")
                    if (testSource(sources[indexToCheck])) {
                        found = true
                        break
                    }
                    
                    Log.d(TAG, "Source ${indexToCheck + 1} not available, trying next")
                    
                    // Continue to next
                    if (direction > 0) {
                        indexToCheck = (indexToCheck + 1) % sources.size
                    } else {
                        indexToCheck = (indexToCheck - 1 + sources.size) % sources.size
                    }
                    loopCount++
                }
                
                if (myVerificationId != currentVerificationId) {
                    activity?.runOnUiThread { isManualSwitching = false }
                    return@Thread
                }
                
                val finalIndex = indexToCheck
                activity?.runOnUiThread {
                    if (myVerificationId != currentVerificationId) {
                        isManualSwitching = false
                        return@runOnUiThread
                    }
                    
                    // Unlock
                    isManualSwitching = false
                    
                    if (found) {
                        Log.d(TAG, "Found available source ${finalIndex + 1}, switching")
                        currentSourceIndex = finalIndex
                        currentUrl = sources[currentSourceIndex]
                        updateSourceIndicator()
                        playUrl(currentUrl)
                    } else {
                        Log.d(TAG, "No other available sources found (all failed), forcing next source")
                        // Fallback
                        val fallbackIndex = if (direction > 0) {
                            (startIndex + 1) % sources.size
                        } else {
                            (startIndex - 1 + sources.size) % sources.size
                        }
                        
                        currentSourceIndex = fallbackIndex
                        currentUrl = sources[currentSourceIndex]
                        updateSourceIndicator()
                        playUrl(currentUrl)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Source switching error: ${e.message}")
                activity?.runOnUiThread {
                    isManualSwitching = false
                    hideLoading()
                }
            }
        }.start()
    }
    
    // Show source indicator
    private fun showSourceIndicator() {
        updateSourceIndicator()
    }
    
    // Update source indicator display
    private fun updateSourceIndicator() {
        val sources = getCurrentSources()
        activity?.runOnUiThread {
            if (sources.size > 1) {
                // Update source indicator text
                sourceText.text = getString(R.string.source_indicator, currentSourceIndex + 1, sources.size)
                sourceIndicator.visibility = View.VISIBLE
                // Channel name no longer shows source info
                channelNameText.text = currentName
            } else {
                channelNameText.text = currentName
                sourceIndicator.visibility = View.GONE
            }
        }
    }
    
    private fun switchChannel(newIndex: Int) {
        Log.d(TAG, "=== switchChannel called ===")
        Log.d(TAG, "New channel index: $newIndex, total channels: ${channelUrls.size}")
        
        if (channelUrls.isEmpty() || newIndex < 0 || newIndex >= channelUrls.size) {
            Log.e(TAG, "Invalid channel index")
            return
        }
        
        // Increment verification ID, immediately invalidating all previous background tasks
        currentVerificationId++
        val myVerificationId = currentVerificationId
        
        // Reset manual switching status
        isManualSwitching = false
        
        // Stop current playback immediately for "switched" feedback
        player?.stop()
        player?.clearMediaItems()
        
        // Reset retry count and cancel auto-detection
        retryCount = 0
        isAutoSwitching = false
        isAutoDetecting = false
        retryRunnable?.let { handler.removeCallbacks(it) }
        
        currentIndex = newIndex
        currentSourceIndex = 0 // Reset source index
        currentUrl = channelUrls[newIndex]
        currentName = if (newIndex < channelNames.size) channelNames[newIndex] else "Channel ${newIndex + 1}"
        
        // Update progress bar visibility
        updateProgressBarVisibility()
        
        // Show control bar immediately (channel info etc.)
        showControls()
        // Update EPG info
        refreshEpgInfo()
        
        Log.d(TAG, "Switching to channel: $currentName")
        
        // Detect and use first available source
        val sources = getCurrentSources()
        Log.d(TAG, "Channel has ${sources.size} sources")
        
        if (sources.size > 1) {
            Log.d(TAG, "Starting source detection in background thread...")
            
            // Show detecting status
            updateStatus("Detecting source...")
            showLoading()
            
            // Detecting source in background thread
            Thread {
                if (myVerificationId != currentVerificationId) return@Thread
                
                var foundSourceIndex = 0
                for (i in sources.indices) {
                    // Stop immediately if new operation performed
                    if (myVerificationId != currentVerificationId) return@Thread
                    
                    // Update UI in real-time showing current detected source
                    activity?.runOnUiThread {
                        if (myVerificationId != currentVerificationId) return@runOnUiThread
                        updateStatus("Detecting source...i + 1}/${sources.size}")
                        currentSourceIndex = i
                        updateSourceIndicator()
                        showControls()
                    }
                    
                    Log.d(TAG, "Detecting source...i + 1}/${sources.size}: ${sources[i]}")
                    if (testSource(sources[i])) {
                        foundSourceIndex = i
                        Log.d(TAG, "✓ Source ${i + 1} available")
                        break
                    } else {
                        Log.d(TAG, "✗ Source ${i + 1} not available")
                    }
                }
                
                if (myVerificationId != currentVerificationId) return@Thread
                
                val finalSourceIndex = foundSourceIndex
                activity?.runOnUiThread {
                    if (myVerificationId != currentVerificationId) return@runOnUiThread
                    
                    currentSourceIndex = finalSourceIndex
                    val urlToPlay = sources[currentSourceIndex]
                    Log.d(TAG, "Using source ${currentSourceIndex + 1}/${sources.size}: $urlToPlay")
                    
                    updateSourceIndicator()
                    playUrl(urlToPlay)
                    
                    // Check favorite status for new channel
                    checkInitialFavoriteStatus()
                    
                    showControls()
                }
            }.start()
        } else {
            Log.d(TAG, "Channel has only one source, playing directly")
            val urlToPlay = if (sources.isNotEmpty() && currentSourceIndex < sources.size) {
                sources[currentSourceIndex]
            } else {
                currentUrl
            }
            
            updateSourceIndicator()
            playUrl(urlToPlay)
            
            // Check favorite status for new channel
            checkInitialFavoriteStatus()
            
            showControls()
        }
    }

    private fun refreshEpgInfo() {
        // Simple check if attached
        if (!isAdded || activity == null) return

        if (isDlnaMode || channelNames.isEmpty() || currentIndex < 0 || currentIndex >= channelNames.size) {
             activity?.runOnUiThread {
                 try {
                     if (view != null) epgContainer.visibility = View.GONE
                 } catch (e: Exception) {}
             }
             return
        }
        
        val name = channelNames[currentIndex]
        val epgId = if (currentIndex < channelEpgIds.size) channelEpgIds[currentIndex] else ""
        
        (activity as? MainActivity)?.requestEpgInfo(name, epgId) { result ->
            activity?.runOnUiThread {
                try {
                    if (view == null) return@runOnUiThread
                    
                    if (result != null) {
                        val currentTitle = result["currentTitle"] as? String
                        val nextTitle = result["nextTitle"] as? String
                        
                        var hasContent = false
                        
                        if (!currentTitle.isNullOrEmpty()) {
                            epgCurrentTitle.text = currentTitle
                            epgCurrentContainer.visibility = View.VISIBLE
                            hasContent = true
                        } else {
                            epgCurrentContainer.visibility = View.GONE
                        }
                        
                        if (!nextTitle.isNullOrEmpty()) {
                            epgNextTitle.text = nextTitle
                            epgNextContainer.visibility = View.VISIBLE
                            hasContent = true
                        } else {
                            epgNextContainer.visibility = View.GONE
                        }
                        
                        epgContainer.visibility = if (hasContent) View.VISIBLE else View.GONE
                    } else {
                        epgContainer.visibility = View.GONE
                    }
                } catch (e: Exception) {
                    // Ignore
                }
            }
        }
    }
    
    // Detect if source is available (executed in background thread)
    private fun testSource(url: String): Boolean {
        return try {
            val urlConnection = java.net.URL(url).openConnection() as java.net.HttpURLConnection
            urlConnection.connectTimeout = 1500 // 1.5s timeout
            urlConnection.readTimeout = 1500
            urlConnection.requestMethod = "HEAD" // Use HEAD request, faster
            urlConnection.setRequestProperty("User-Agent", "Mozilla/5.0")
            urlConnection.setRequestProperty("Accept", "*/*")
            urlConnection.setRequestProperty("Connection", "keep-alive")
            
            val responseCode = urlConnection.responseCode
            urlConnection.disconnect()
            
            val isAvailable = responseCode in 200..399
            Log.d(TAG, "testSource: $url -> $responseCode (${if (isAvailable) "Available" else "Unavailable"})")
            isAvailable
        } catch (e: Exception) {
            Log.d(TAG, "testSource: $url -> Exception: ${e.message}")
            false
        }
    }
    
    private fun nextChannel() {
        if (channelUrls.isEmpty()) return
        val newIndex = if (currentIndex < channelUrls.size - 1) currentIndex + 1 else 0
        switchChannel(newIndex)
    }
    
    private fun previousChannel() {
        if (channelUrls.isEmpty()) return
        val newIndex = if (currentIndex > 0) currentIndex - 1 else channelUrls.size - 1
        switchChannel(newIndex)
    }

    private fun updateStatus(status: String) {
        activity?.runOnUiThread {
            statusText.text = status
            val color = when (status) {
                "LIVE" -> 0xFF4CAF50.toInt()  // Green
                "Buffering", "Loading" -> 0xFFFF9800.toInt()  // Orange
                "Paused" -> 0xFF2196F3.toInt()  // Blue
                "Offline", "Error" -> 0xFFF44336.toInt()  // Red
                else -> 0xFF9E9E9E.toInt()  // Gray
            }
            statusText.setTextColor(color)
            
            // Update indicator dot color
            val drawable = android.graphics.drawable.GradientDrawable()
            drawable.shape = android.graphics.drawable.GradientDrawable.OVAL
            drawable.setColor(color)
            statusIndicator.background = drawable
        }
    }

    private fun updateVideoInfoDisplay() {
        activity?.runOnUiThread {
            val parts = mutableListOf<String>()
            if (videoWidth > 0 && videoHeight > 0) {
                parts.add("${videoWidth}x${videoHeight}")
            }
            if (frameRate > 0) {
                parts.add("${frameRate.toInt()}fps")
            }
            if (isHardwareDecoder) {
                parts.add(getString(R.string.hardware_decode))
            } else {
                parts.add(getString(R.string.software_decode))
            }
            
            if (parts.isNotEmpty()) {
                videoInfoText.text = parts.joinToString(" · ")
                videoInfoText.visibility = View.VISIBLE
            } else {
                videoInfoText.visibility = View.GONE
            }
            
            // Update top-right FPS display
            if (showFps && frameRate > 0) {
                fpsText.text = "${frameRate.toInt()} FPS"
                fpsText.visibility = View.VISIBLE
            } else {
                fpsText.visibility = View.GONE
            }

            // Update top-right resolution display (no bitrate)
            if (showVideoInfo && videoWidth > 0 && videoHeight > 0) {
                val resInfo = "${videoWidth}x${videoHeight}"
                resolutionText.text = resInfo
                resolutionText.visibility = View.VISIBLE
            } else {
                resolutionText.visibility = View.GONE
            }
        }
    }

    private fun showLoading() {
        loadingIndicator.visibility = View.VISIBLE
        errorText.visibility = View.GONE
    }

    private fun hideLoading() {
        loadingIndicator.visibility = View.GONE
        errorText.visibility = View.GONE
    }

    private fun showError(message: String) {
        loadingIndicator.visibility = View.GONE
        errorText.visibility = View.VISIBLE
        errorText.text = message
    }
    
    private fun showControls() {
        controlsVisible = true
        topBar.visibility = View.VISIBLE
        bottomBar.visibility = View.VISIBLE
        topBar.animate().alpha(1f).setDuration(200).start()
        bottomBar.animate().alpha(1f).setDuration(200).start()
        scheduleHideControls()
        updateEpgInfo()
    }
    
    private fun updateEpgInfo() {
        // Request EPG info from Flutter via MethodChannel
        val activity = activity as? MainActivity ?: return
        activity.getEpgInfo(currentName) { epgInfo ->
            activity.runOnUiThread {
                if (epgInfo != null) {
                    val currentTitle = epgInfo["currentTitle"] as? String
                    val currentRemaining = epgInfo["currentRemaining"] as? Int
                    val nextTitle = epgInfo["nextTitle"] as? String
                    
                    if (currentTitle != null || nextTitle != null) {
                        epgContainer.visibility = View.VISIBLE
                        
                        if (currentTitle != null) {
                            epgCurrentContainer.visibility = View.VISIBLE
                            epgCurrentTitle.text = currentTitle
                            epgCurrentTime.text = if (currentRemaining != null) getString(R.string.epg_ends_in_minutes, currentRemaining) else ""
                        } else {
                            epgCurrentContainer.visibility = View.GONE
                        }
                        
                        if (nextTitle != null) {
                            epgNextContainer.visibility = View.VISIBLE
                            epgNextTitle.text = nextTitle
                        } else {
                            epgNextContainer.visibility = View.GONE
                        }
                    } else {
                        epgContainer.visibility = View.GONE
                    }
                } else {
                    epgContainer.visibility = View.GONE
                }
            }
        }
    }
    
    private fun hideControls() {
        controlsVisible = false
        topBar.animate().alpha(0f).setDuration(200).withEndAction {
            if (!controlsVisible) {
                topBar.visibility = View.GONE
            }
        }.start()
        bottomBar.animate().alpha(0f).setDuration(200).withEndAction {
            if (!controlsVisible) {
                bottomBar.visibility = View.GONE
            }
        }.start()
    }
    
    private fun scheduleHideControls() {
        hideControlsRunnable?.let { handler.removeCallbacks(it) }
        hideControlsRunnable = Runnable { 
            // Hide control bar if not in category panel
            if (!categoryPanelVisible) {
                hideControls() 
            }
        }
        handler.postDelayed(hideControlsRunnable!!, CONTROLS_HIDE_DELAY)
    }
    
    // DLNA mode: start progress update
    private fun startProgressUpdate() {
        progressUpdateRunnable?.let { handler.removeCallbacks(it) }
        progressUpdateRunnable = Runnable {
            updateProgress()
            handler.postDelayed(progressUpdateRunnable!!, PROGRESS_UPDATE_INTERVAL)
        }
        handler.post(progressUpdateRunnable!!)
    }
    
    // DLNA mode: stop progress update
    private fun stopProgressUpdate() {
        progressUpdateRunnable?.let { handler.removeCallbacks(it) }
        progressUpdateRunnable = null
    }
    
    // Update progress bar visibility (based on content type, DLNA mode, and user settings)
    private fun updateProgressBarVisibility() {
        Log.d(TAG, "=== updateProgressBarVisibility called ===")
        Log.d(TAG, "progressBarMode: $progressBarMode")
        Log.d(TAG, "isDlnaMode: $isDlnaMode")
        Log.d(TAG, "currentIndex: $currentIndex")
        Log.d(TAG, "channelIsSeekable.size: ${channelIsSeekable.size}")
        
        // Force progress bar display in DLNA mode
        if (isDlnaMode) {
            Log.d(TAG, "DLNA mode - forcing progress bar visibility")
            progressContainer.visibility = View.VISIBLE
            helpText.visibility = View.GONE
            startProgressUpdate() // Start progress update
            return
        }
        
        // Determine whether to show progress bar based on user settings
        val shouldShow = when (progressBarMode) {
            "never" -> {
                Log.d(TAG, "Mode: never - hiding progress bar")
                false  // Never show
            }
            "always" -> {
                Log.d(TAG, "Mode: always - always showing progress bar")
                true  // Always show
            }
            "auto" -> {  // Auto-detect
                // Show progress bar for DLNA mode or seekable content
                val currentIsSeekable = if (currentIndex >= 0 && currentIndex < channelIsSeekable.size) {
                    channelIsSeekable[currentIndex]
                } else {
                    false
                }
                Log.d(TAG, "Mode: auto - currentIsSeekable: $currentIsSeekable")
                val result = isDlnaMode || currentIsSeekable
                Log.d(TAG, "Mode: auto - result: $result")
                result
            }
            else -> {  // Default auto-detect
                Log.d(TAG, "Mode: unknown($progressBarMode) - using default auto-detect")
                val currentIsSeekable = if (currentIndex >= 0 && currentIndex < channelIsSeekable.size) {
                    channelIsSeekable[currentIndex]
                } else {
                    false
                }
                Log.d(TAG, "Default mode - currentIsSeekable: $currentIsSeekable")
                val result = isDlnaMode || currentIsSeekable
                Log.d(TAG, "Default mode - result: $result")
                result
            }
        }
        
        Log.d(TAG, "Final decision: shouldShow = $shouldShow")
        
        if (shouldShow) {
            // Showing progress bar
            Log.d(TAG, "Showing progress bar, hiding help text")
            progressContainer.visibility = View.VISIBLE
            helpText.visibility = View.GONE
            if (!isDlnaMode) {
                // Seekable content in non-DLNA mode also needs progress update
                Log.d(TAG, "Start progress update")
                startProgressUpdate()
            }
            // Don	 request focus automatically, let user activate via key press
        } else {
            // Hiding progress bar, showing help text
            Log.d(TAG, "Hiding progress bar, showing help text")
            progressContainer.visibility = View.GONE
            helpText.visibility = View.VISIBLE
            if (!isDlnaMode) {
                Log.d(TAG, "Stop progress update")
                stopProgressUpdate()
            }
        }
    }
    
    // DLNA mode: update progress bar
    private fun updateProgress() {
        val p = player ?: return
        val position = p.currentPosition
        val duration = p.duration
        
        if (duration > 0) {
            val progress = (position * 100 / duration).toInt()
            progressBar.progress = progress
            progressCurrent.text = formatTime(position)
            progressDuration.text = formatTime(duration)
        }
    }
    
    // Format time (ms -> HH:MM:SS or MM:SS)
    private fun formatTime(ms: Long): String {
        val totalSeconds = ms / 1000
        val hours = totalSeconds / 3600
        val minutes = (totalSeconds % 3600) / 60
        val seconds = totalSeconds % 60
        
        return if (hours > 0) {
            String.format("%d:%02d:%02d", hours, minutes, seconds)
        } else {
            String.format("%02d:%02d", minutes, seconds)
        }
    }
    
    private fun toggleFavorite() {
        Log.d(TAG, "toggleFavorite called: currentIndex=$currentIndex, isDlnaMode=$isDlnaMode")
        if (currentIndex < 0 || isDlnaMode) {
            Log.d(TAG, "toggleFavorite: skipped - invalid index or DLNA mode")
            return
        }
        
        val activity = activity as? MainActivity
        if (activity == null) {
            Log.e(TAG, "toggleFavorite: activity is null")
            return
        }
        
        Log.d(TAG, "toggleFavorite: calling MainActivity.toggleFavorite")
        activity.toggleFavorite(currentIndex) { newFavoriteStatus ->
            Log.d(TAG, "toggleFavorite callback: newFavoriteStatus=$newFavoriteStatus")
            activity.runOnUiThread {
                if (newFavoriteStatus != null) {
                    isFavorite = newFavoriteStatus
                    updateFavoriteIcon()
                    val message = if (newFavoriteStatus) {
                        getString(R.string.added_to_favorites)
                    } else {
                        getString(R.string.removed_from_favorites)
                    }
                    android.widget.Toast.makeText(requireContext(), message, android.widget.Toast.LENGTH_SHORT).show()
                } else {
                    Log.e(TAG, "toggleFavorite: operation failed")
                    android.widget.Toast.makeText(requireContext(), getString(R.string.operation_failed), android.widget.Toast.LENGTH_SHORT).show()
                }
            }
        }
    }
    
    private fun updateFavoriteIcon() {
        favoriteIcon.visibility = if (isFavorite) View.VISIBLE else View.GONE
    }
    
    private fun checkInitialFavoriteStatus() {
        if (currentIndex < 0 || isDlnaMode) return
        
        val activity = activity as? MainActivity ?: return
        activity.isFavorite(currentIndex) { favoriteStatus ->
            activity.runOnUiThread {
                isFavorite = favoriteStatus
                updateFavoriteIcon()
                Log.d(TAG, "Initial favorite status: $isFavorite for channel index $currentIndex")
            }
        }
    }
    
    private fun closePlayer() {
        Log.d(TAG, "closePlayer called")
        try {
            player?.stop()
            player?.release()
            player = null
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing player", e)
        }
        onCloseListener?.invoke()
    }
    
    // DLNA control methods
    fun pause() {
        activity?.runOnUiThread {
            player?.pause()
        }
    }
    
    fun play() {
        activity?.runOnUiThread {
            player?.play()
        }
    }
    
    fun seekTo(positionMs: Long) {
        activity?.runOnUiThread {
            player?.seekTo(positionMs)
        }
    }
    
    fun setVolume(volume: Int) {
        activity?.runOnUiThread {
            player?.volume = volume / 100f
        }
    }
    
    fun getPlaybackState(): Map<String, Any?> {
        val p = player
        return mapOf(
            "isPlaying" to (p?.isPlaying ?: false),
            "position" to (p?.currentPosition ?: 0L),
            "duration" to (p?.duration ?: 0L),
            "fps" to frameRate,
            "state" to when (p?.playbackState) {
                Player.STATE_IDLE -> "idle"
                Player.STATE_BUFFERING -> "buffering"
                Player.STATE_READY -> if (p.isPlaying) "playing" else "paused"
                Player.STATE_ENDED -> "ended"
                else -> "unknown"
            }
        )
    }

    fun getCurrentChannelIndex(): Int {
        return currentIndex
    }

    override fun onResume() {
        super.onResume()
        Log.d(TAG, "onResume")
        // Ensure screen stays on
        activity?.window?.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        
        // Check player status, if player exists but not playing, try to resume
        player?.let { p ->
            if (p.playbackState == Player.STATE_IDLE || p.playbackState == Player.STATE_ENDED) {
                // Player is idle or ended, needs reloading
                Log.d(TAG, "Player in IDLE/ENDED state, reloading media...")
                val sources = getCurrentSources()
                if (sources.isNotEmpty() && currentSourceIndex < sources.size) {
                    val urlToPlay = sources[currentSourceIndex]
                    playUrl(urlToPlay)
                }
            } else {
                // Player status normal, resume playback directly
                p.playWhenReady = true
            }
        } ?: run {
            // Player doesn	 exist, re-initialize and play
            Log.d(TAG, "Player is null, reinitializing...")
            initializePlayer()
            val sources = getCurrentSources()
            if (sources.isNotEmpty() && currentSourceIndex < sources.size) {
                val urlToPlay = sources[currentSourceIndex]
                playUrl(urlToPlay)
            }
        }
    }

    override fun onPause() {
        super.onPause()
        Log.d(TAG, "onPause")
        player?.playWhenReady = false
    }

    override fun onDestroyView() {
        super.onDestroyView()
        Log.d(TAG, "onDestroyView")
        hideControlsRunnable?.let { handler.removeCallbacks(it) }
        retryRunnable?.let { handler.removeCallbacks(it) }
        sourceIndicatorHideRunnable?.let { handler.removeCallbacks(it) }
        stopProgressUpdate() // Stop progress update
        stopFpsCalculation() // Stop FPS calculation
        stopClockUpdate() // Stop clock update
        stopNetworkSpeedUpdate() // Stop network speed update
        redirectCache.clear() // Clear redirect cache
        player?.release()
        player = null
        activity?.window?.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }
    
    // Data classes
    data class CategoryItem(val name: String, val count: Int)
    data class ChannelItem(val index: Int, val name: String, val isPlaying: Boolean)
    
    // ViewHolders
    class CategoryViewHolder(view: View) : RecyclerView.ViewHolder(view) {
        val nameText: TextView = view.findViewById(R.id.category_name)
        val countText: TextView = view.findViewById(R.id.category_count)
    }
    
    class ChannelViewHolder(view: View) : RecyclerView.ViewHolder(view) {
        val nameText: TextView = view.findViewById(R.id.channel_name)
        val playingIcon: ImageView = view.findViewById(R.id.playing_icon)
    }
}
