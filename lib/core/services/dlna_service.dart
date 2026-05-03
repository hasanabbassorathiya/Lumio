import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import './service_locator.dart';

/// DLNA Renderer Service (DMR - Digital Media Renderer)
/// Allows mobile apps to discover and cast to this device
class DlnaService {
  static final DlnaService _instance = DlnaService._internal();
  factory DlnaService() => _instance;
  DlnaService._internal();

  // SSDP multicast address and port
  static const String _ssdpAddress = '239.255.255.250';
  static const int _ssdpPort = 1900;

  // Service port
  int _httpPort = 8200;

  // Device info
  String _deviceUuid = '';
  String _deviceName = 'Lumio IPTV';
  String? _localIp;

  // Service status
  RawDatagramSocket? _ssdpSocket;
  HttpServer? _httpServer;
  Timer? _notifyTimer; // SSDP periodic broadcast
  bool _isRunning = false;

  // Playback callbacks
  Function(String url, String? title)? onPlayUrl;
  Function()? onPause;
  Function()? onStop;
  Function(int volume)? onSetVolume;
  Function(Duration position)? onSeek;

  // Current playback status
  // State: NO_MEDIA_PRESENT, STOPPED, TRANSITIONING, PLAYING, PAUSED_PLAYBACK
  String _transportState = 'NO_MEDIA_PRESENT';
  String _currentUri = '';
  String _currentTitle = '';
  Duration _currentPosition = Duration.zero;
  Duration _currentDuration = Duration.zero;
  int _volume = 100;
  DateTime? _playStartTime; // Playback start time, used to calculate simulated position
  
  // Event subscription management
  final Map<String, String> _eventSubscriptions = {}; // SID -> callback URL

  bool get isRunning => _isRunning;
  String get deviceName => _deviceName;

  /// Start DLNA service
  Future<bool> start({String? customName}) async {
    if (_isRunning) return true;

    try {
      // Generate device UUID
      await _generateDeviceUuid();
      
      if (customName != null) {
        _deviceName = customName;
      }

      // Get local IP
      _localIp = await _getLocalIpAddress();
      if (_localIp == null) {
        ServiceLocator.log.d('DLNA: Unable to get local IP');
        return false;
      }

      // Start HTTP server
      if (!await _startHttpServer()) {
        return false;
      }

      // Start SSDP service
      if (!await _startSsdpService()) {
        await _httpServer?.close();
        return false;
      }

      _isRunning = true;
      ServiceLocator.log.d('DLNA: Service started - $_deviceName ($_localIp:$_httpPort)');
      return true;
    } catch (e) {
      ServiceLocator.log.d('DLNA: Initialization failed - $e');
      return false;
    }
  }

  /// Stop DLNA service
  Future<void> stop() async {
    if (!_isRunning) return;
    
    _isRunning = false;
    
    // Cancel timer
    _notifyTimer?.cancel();
    _notifyTimer = null;
    
    // Send SSDP byebye notification
    _sendSsdpByebye();
    
    // Wait for byebye message to be sent
    await Future.delayed(const Duration(milliseconds: 100));
    
    // Clear subscriptions
    _eventSubscriptions.clear();
    
    _ssdpSocket?.close();
    _ssdpSocket = null;
    await _httpServer?.close(force: true);
    _httpServer = null;
    ServiceLocator.log.d('DLNA: Service stopped');
  }
  
  /// Send SSDP byebye notification (device offline)
  void _sendSsdpByebye() {
    if (_ssdpSocket == null) return;

    final byebye = '''NOTIFY * HTTP/1.1\r
HOST: $_ssdpAddress:$_ssdpPort\r
NT: urn:schemas-upnp-org:device:MediaRenderer:1\r
NTS: ssdp:byebye\r
USN: $_deviceUuid::urn:schemas-upnp-org:device:MediaRenderer:1\r
\r
''';

    try {
      // Send multiple times to ensure reception
      for (int i = 0; i < 3; i++) {
        _ssdpSocket?.send(
          utf8.encode(byebye),
          InternetAddress(_ssdpAddress),
          _ssdpPort,
        );
      }
    } catch (e) {
      // Ignore send error
    }
  }

  /// Update playback status
  void updatePlayState({
    String? state,
    Duration? position,
    Duration? duration,
  }) {
    if (state != null && state != _transportState) {
      _transportState = state;
      // Notify subscribers when state changes
      _notifyAllSubscribers();
    }
    if (position != null) {
      _currentPosition = position;
      // If playing, reset play start time to maintain position sync
      if (_transportState == 'PLAYING') {
        _playStartTime = DateTime.now();
      }
    }
    if (duration != null) _currentDuration = duration;
  }

  /// Generate device UUID
  Future<void> _generateDeviceUuid() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        _deviceUuid = 'uuid:${info.id}-lumio-iptv';
        _deviceName = 'Lumio IPTV (${info.model})';
      } else if (Platform.isWindows) {
        final info = await deviceInfo.windowsInfo;
        _deviceUuid = 'uuid:${info.deviceId}-lumio-iptv';
        _deviceName = 'Lumio IPTV (${info.computerName})';
      } else {
        _deviceUuid = 'uuid:lumio-iptv-${DateTime.now().millisecondsSinceEpoch}';
      }
    } catch (e) {
      _deviceUuid = 'uuid:lumio-iptv-${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// Get local IP address
  Future<String?> _getLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      for (var interface in interfaces) {
        final name = interface.name.toLowerCase();
        // Skip virtual network cards
        if (name.contains('virtual') || name.contains('vmware') ||
            name.contains('docker') || name.contains('veth')) {
          continue;
        }

        for (var addr in interface.addresses) {
          if (!addr.isLoopback && addr.address.startsWith('192.168.')) {
            return addr.address;
          }
        }
      }

      // If no 192.168 address found, return first non-loopback address
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (!addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      // Failed to get IP
    }
    return null;
  }

  /// Start HTTP server
  Future<bool> _startHttpServer() async {
    try {
      _httpServer = await HttpServer.bind(InternetAddress.anyIPv4, _httpPort);

      _httpServer!.listen(_handleHttpRequest);
      return true;
    } catch (e) {
      ServiceLocator.log.d('DLNA: HTTP server failed to start - $e');
      return false;
    }
  }

  /// Start SSDP service
  Future<bool> _startSsdpService() async {
    try {
      // Find corresponding network interface
      NetworkInterface? targetInterface;
      try {
        final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
        for (var iface in interfaces) {
          for (var addr in iface.addresses) {
            if (addr.address == _localIp) {
              targetInterface = iface;
              break;
            }
          }
          if (targetInterface != null) break;
        }
      } catch (e) {
        // Failed to get network interface, continue using default
      }

      // Try binding to multicast address 239.255.255.250:1900
      try {
        _ssdpSocket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          _ssdpPort,
          reuseAddress: true,
          reusePort: true,
        );
      } catch (e) {
        // If port 1900 is occupied, use a random port
        _ssdpSocket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          0,
          reuseAddress: true,
        );
      }

      // Join multicast group
      try {
        final multicastAddr = InternetAddress(_ssdpAddress);
        if (targetInterface != null) {
          _ssdpSocket!.joinMulticast(multicastAddr, targetInterface);
        } else {
          _ssdpSocket!.joinMulticast(multicastAddr);
        }
      } catch (e) {
        // Continue running even if joining multicast group fails
      }

      // Set multicast TTL
      _ssdpSocket!.multicastHops = 4;
      
      // Enable multicast loopback (for local testing)
      _ssdpSocket!.multicastLoopback = true;

      // Listen for requests
      _ssdpSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _ssdpSocket!.receive();
          if (datagram != null) {
            _handleSsdpRequest(datagram);
          }
        }
      }, onError: (e) {
        ServiceLocator.log.d('DLNA: SSDP error - $e');
      });

      // Immediately send multiple NOTIFY broadcasts
      for (int i = 0; i < 3; i++) {
        _sendSsdpNotify();
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Send periodic broadcasts
      _notifyTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        if (_isRunning) _sendSsdpNotify();
      });

      return true;
    } catch (e) {
      ServiceLocator.log.d('DLNA: SSDP failed to start - $e');
      return false;
    }
  }

  /// Handle SSDP request
  void _handleSsdpRequest(Datagram datagram) {
    final message = utf8.decode(datagram.data);
    
    // Only handle M-SEARCH requests, ignore other NOTIFY messages
    if (message.startsWith('M-SEARCH')) {
      // Check if searching for media renderer
      if (message.contains('ssdp:all') ||
          message.contains('upnp:rootdevice') ||
          message.contains('urn:schemas-upnp-org:device:MediaRenderer:1') ||
          message.contains('urn:schemas-upnp-org:service:AVTransport:1')) {
        _sendSsdpResponse(datagram.address, datagram.port);
      }
    }
  }

  /// Send SSDP response
  void _sendSsdpResponse(InternetAddress address, int port) {
    final response = '''HTTP/1.1 200 OK\r
CACHE-CONTROL: max-age=1800\r
DATE: ${HttpDate.format(DateTime.now())}\r
EXT:\r
LOCATION: http://$_localIp:$_httpPort/description.xml\r
SERVER: Lumio IPTV/1.0 UPnP/1.0 DLNADOC/1.50\r
ST: urn:schemas-upnp-org:device:MediaRenderer:1\r
USN: $_deviceUuid::urn:schemas-upnp-org:device:MediaRenderer:1\r
\r
''';

    _ssdpSocket?.send(utf8.encode(response), address, port);
  }

  /// Send SSDP NOTIFY broadcast
  void _sendSsdpNotify() {
    final notify = '''NOTIFY * HTTP/1.1\r
HOST: $_ssdpAddress:$_ssdpPort\r
CACHE-CONTROL: max-age=1800\r
LOCATION: http://$_localIp:$_httpPort/description.xml\r
NT: urn:schemas-upnp-org:device:MediaRenderer:1\r
NTS: ssdp:alive\r
SERVER: Lumio IPTV/1.0 UPnP/1.0 DLNADOC/1.50\r
USN: $_deviceUuid::urn:schemas-upnp-org:device:MediaRenderer:1\r
\r
''';

    _ssdpSocket?.send(
      utf8.encode(notify),
      InternetAddress(_ssdpAddress),
      _ssdpPort,
    );
  }

  /// Handle HTTP request
  void _handleHttpRequest(HttpRequest request) async {
    final path = request.uri.path;

    try {
      if (path == '/description.xml') {
        await _handleDeviceDescription(request);
      } else if (path == '/AVTransport/scpd.xml') {
        await _handleAvTransportScpd(request);
      } else if (path == '/RenderingControl/scpd.xml') {
        await _handleRenderingControlScpd(request);
      } else if (path == '/ConnectionManager/scpd.xml') {
        await _handleConnectionManagerScpd(request);
      } else if (path == '/AVTransport/control') {
        await _handleAvTransportControl(request);
      } else if (path == '/RenderingControl/control') {
        await _handleRenderingControlControl(request);
      } else if (path == '/ConnectionManager/control') {
        await _handleConnectionManagerControl(request);
      } else if (path.endsWith('/event')) {
        await _handleEventSubscription(request);
      } else {
        request.response.statusCode = 404;
        await request.response.close();
      }
    } catch (e) {
      ServiceLocator.log.d('DLNA: HTTP error - $e');
      request.response.statusCode = 500;
      await request.response.close();
    }
  }

  /// Handle event subscription request
  Future<void> _handleEventSubscription(HttpRequest request) async {
    if (request.method == 'SUBSCRIBE') {
      final callback = request.headers.value('CALLBACK');
      final sid = 'uuid:${DateTime.now().millisecondsSinceEpoch}';
      
      if (callback != null) {
        final urlMatch = RegExp(r'<([^>]+)>').firstMatch(callback);
        if (urlMatch != null) {
          _eventSubscriptions[sid] = urlMatch.group(1)!;
        }
      }
      
      request.response.statusCode = 200;
      request.response.headers.set('SID', sid);
      request.response.headers.set('TIMEOUT', 'Second-1800');
      request.response.headers.set('Server', 'Lumio IPTV/1.0 UPnP/1.0');
      request.response.headers.set('Content-Length', '0');
      await request.response.close();
      
      _sendEventNotification(sid);
    } else if (request.method == 'UNSUBSCRIBE') {
      final sid = request.headers.value('SID');
      if (sid != null) {
        _eventSubscriptions.remove(sid);
      }
      request.response.statusCode = 200;
      await request.response.close();
    } else {
      request.response.statusCode = 405;
      await request.response.close();
    }
  }
  
  /// Send event notification to subscriber
  void _sendEventNotification(String sid) async {
    final callbackUrl = _eventSubscriptions[sid];
    if (callbackUrl == null) return;
    
    try {
      final uri = Uri.parse(callbackUrl);
      final client = HttpClient();
      final request = await client.openUrl('NOTIFY', uri);
      
      request.headers.set('Content-Type', 'text/xml; charset="utf-8"');
      request.headers.set('NT', 'upnp:event');
      request.headers.set('NTS', 'upnp:propchange');
      request.headers.set('SID', sid);
      request.headers.set('SEQ', '0');
      
      final body = '''<?xml version="1.0" encoding="utf-8"?>
<e:propertyset xmlns:e="urn:schemas-upnp-org:event-1-0">
  <e:property>
    <LastChange>&lt;Event xmlns=&quot;urn:schemas-upnp-org:metadata-1-0/AVT/&quot;&gt;&lt;InstanceID val=&quot;0&quot;&gt;&lt;TransportState val=&quot;$_transportState&quot;/&gt;&lt;TransportStatus val=&quot;OK&quot;/&gt;&lt;CurrentPlayMode val=&quot;NORMAL&quot;/&gt;&lt;/InstanceID&gt;&lt;/Event&gt;</LastChange>
  </e:property>
</e:propertyset>''';
      
      request.write(body);
      await request.close();
    } catch (e) {
      // Event notification failed, ignore
    }
  }
  
  /// Notify all subscribers of state change
  void _notifyAllSubscribers() {
    for (final sid in _eventSubscriptions.keys) {
      _sendEventNotification(sid);
    }
  }

  /// Device description XML
  Future<void> _handleDeviceDescription(HttpRequest request) async {
    final xml = '''<?xml version="1.0" encoding="UTF-8"?>
<root xmlns="urn:schemas-upnp-org:device-1-0" xmlns:dlna="urn:schemas-dlna-org:device-1-0">
  <specVersion>
    <major>1</major>
    <minor>0</minor>
  </specVersion>
  <device>
    <deviceType>urn:schemas-upnp-org:device:MediaRenderer:1</deviceType>
    <friendlyName>$_deviceName</friendlyName>
    <manufacturer>Lumio IPTV</manufacturer>
    <manufacturerURL>https://github.com/shnulaa/FlutterIPTV</manufacturerURL>
    <modelDescription>Lumio IPTV Media Renderer</modelDescription>
    <modelName>Lumio IPTV</modelName>
    <modelNumber>1.0</modelNumber>
    <modelURL>https://github.com/shnulaa/FlutterIPTV</modelURL>
    <UDN>$_deviceUuid</UDN>
    <dlna:X_DLNADOC>DMR-1.50</dlna:X_DLNADOC>
    <serviceList>
      <service>
        <serviceType>urn:schemas-upnp-org:service:AVTransport:1</serviceType>
        <serviceId>urn:upnp-org:serviceId:AVTransport</serviceId>
        <SCPDURL>/AVTransport/scpd.xml</SCPDURL>
        <controlURL>/AVTransport/control</controlURL>
        <eventSubURL>/AVTransport/event</eventSubURL>
      </service>
      <service>
        <serviceType>urn:schemas-upnp-org:service:RenderingControl:1</serviceType>
        <serviceId>urn:upnp-org:serviceId:RenderingControl</serviceId>
        <SCPDURL>/RenderingControl/scpd.xml</SCPDURL>
        <controlURL>/RenderingControl/control</controlURL>
        <eventSubURL>/RenderingControl/event</eventSubURL>
      </service>
      <service>
        <serviceType>urn:schemas-upnp-org:service:ConnectionManager:1</serviceType>
        <serviceId>urn:upnp-org:serviceId:ConnectionManager</serviceId>
        <SCPDURL>/ConnectionManager/scpd.xml</SCPDURL>
        <controlURL>/ConnectionManager/control</controlURL>
        <eventSubURL>/ConnectionManager/event</eventSubURL>
      </service>
    </serviceList>
  </device>
</root>''';

    request.response.headers.contentType = ContentType('text', 'xml', charset: 'utf-8');
    request.response.write(xml);
    await request.response.close();
  }

  /// AVTransport SCPD
  Future<void> _handleAvTransportScpd(HttpRequest request) async {
    final xml = _getAvTransportScpd();
    request.response.headers.contentType = ContentType('text', 'xml', charset: 'utf-8');
    request.response.write(xml);
    await request.response.close();
  }

  /// RenderingControl SCPD
  Future<void> _handleRenderingControlScpd(HttpRequest request) async {
    final xml = _getRenderingControlScpd();
    request.response.headers.contentType = ContentType('text', 'xml', charset: 'utf-8');
    request.response.write(xml);
    await request.response.close();
  }

  /// ConnectionManager SCPD
  Future<void> _handleConnectionManagerScpd(HttpRequest request) async {
    final xml = _getConnectionManagerScpd();
    request.response.headers.contentType = ContentType('text', 'xml', charset: 'utf-8');
    request.response.write(xml);
    await request.response.close();
  }

  /// Handle AVTransport control request
  Future<void> _handleAvTransportControl(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();

    String response;

    if (body.contains('SetAVTransportURI')) {
      final uriMatch = RegExp(r'<CurrentURI>([^<]*)</CurrentURI>').firstMatch(body);
      final metaMatch = RegExp(r'<CurrentURIMetaData>([^<]*)</CurrentURIMetaData>').firstMatch(body);
      
      final uri = uriMatch?.group(1) ?? '';
      final meta = metaMatch?.group(1) ?? '';
      final decodedUri = _decodeXmlEntities(uri);
      
      String? title;
      if (meta.isNotEmpty) {
        final decodedMeta = _decodeXmlEntities(meta);
        final titleMatch = RegExp(r'<dc:title>([^<]*)</dc:title>').firstMatch(decodedMeta);
        title = titleMatch?.group(1);
      }

      _currentUri = decodedUri;
      _currentTitle = title ?? 'Unknown';
      _transportState = 'STOPPED';
      _currentPosition = Duration.zero;
      _playStartTime = null;
      
      ServiceLocator.log.d('DLNA: SetURI - $title');
      _notifyAllSubscribers();
      
      response = _createSoapResponse('SetAVTransportURI', '');
    } else if (body.contains('"Play"') || body.contains(':Play') || body.contains('Play</')) {
      ServiceLocator.log.d('DLNA: Play');
      // Only trigger playback when URL exists
      if (_currentUri.isNotEmpty) {
        _transportState = 'TRANSITIONING';
        _notifyAllSubscribers();
        onPlayUrl?.call(_currentUri, _currentTitle);
        
        Future.delayed(const Duration(milliseconds: 300), () {
          _transportState = 'PLAYING';
          _playStartTime = DateTime.now();
          _notifyAllSubscribers();
        });
      } else {
        ServiceLocator.log.d('DLNA: Play ignored - no URL');
      }
      
      response = _createSoapResponse('Play', '');
    } else if (body.contains('"Pause"') || body.contains(':Pause') || body.contains('Pause</')) {
      ServiceLocator.log.d('DLNA: Pause');
      if (_playStartTime != null) {
        _currentPosition = DateTime.now().difference(_playStartTime!);
      }
      _transportState = 'PAUSED_PLAYBACK';
      _playStartTime = null;
      onPause?.call();
      _notifyAllSubscribers();
      response = _createSoapResponse('Pause', '');
    } else if (body.contains('"Stop"') || body.contains(':Stop') || body.contains('Stop</')) {
      ServiceLocator.log.d('DLNA: Stop');
      _transportState = 'STOPPED';
      _currentPosition = Duration.zero;
      _playStartTime = null;
      onStop?.call();
      _notifyAllSubscribers();
      response = _createSoapResponse('Stop', '');
    } else if (body.contains('GetTransportInfo')) {
      response = _createSoapResponse('GetTransportInfo', '''<CurrentTransportState>$_transportState</CurrentTransportState>
        <CurrentTransportStatus>OK</CurrentTransportStatus>
        <CurrentSpeed>1</CurrentSpeed>''');
    } else if (body.contains('GetPositionInfo')) {
      Duration currentPos = _currentPosition;
      if (_transportState == 'PLAYING' && _playStartTime != null) {
        currentPos = _currentPosition + DateTime.now().difference(_playStartTime!);
      }
      final posStr = _formatDuration(currentPos);
      final durStr = _currentDuration == Duration.zero ? '00:00:00' : _formatDuration(_currentDuration);
      
      response = _createSoapResponse('GetPositionInfo', '''<Track>1</Track>
        <TrackDuration>$durStr</TrackDuration>
        <TrackMetaData></TrackMetaData>
        <TrackURI>${_escapeXml(_currentUri)}</TrackURI>
        <RelTime>$posStr</RelTime>
        <AbsTime>$posStr</AbsTime>
        <RelCount>2147483647</RelCount>
        <AbsCount>2147483647</AbsCount>''');
    } else if (body.contains('GetMediaInfo')) {
      final durStr = _currentDuration == Duration.zero ? '00:00:00' : _formatDuration(_currentDuration);
      response = _createSoapResponse('GetMediaInfo', '''<NrTracks>1</NrTracks>
        <MediaDuration>$durStr</MediaDuration>
        <CurrentURI>${_escapeXml(_currentUri)}</CurrentURI>
        <CurrentURIMetaData></CurrentURIMetaData>
        <NextURI></NextURI>
        <NextURIMetaData></NextURIMetaData>
        <PlayMedium>NETWORK</PlayMedium>
        <RecordMedium>NOT_IMPLEMENTED</RecordMedium>
        <WriteStatus>NOT_IMPLEMENTED</WriteStatus>''');
    } else if (body.contains('Seek')) {
      final targetMatch = RegExp(r'<Target>([^<]*)</Target>').firstMatch(body);
      final unitMatch = RegExp(r'<Unit>([^<]*)</Unit>').firstMatch(body);
      if (targetMatch != null) {
        final target = targetMatch.group(1)!;
        final unit = unitMatch?.group(1) ?? 'REL_TIME';
        
        if (unit == 'REL_TIME' || unit == 'ABS_TIME') {
          final position = _parseDuration(target);
          _currentPosition = position;
          _playStartTime = DateTime.now();
          onSeek?.call(position);
          ServiceLocator.log.d('DLNA: Seek $target');
        }
      }
      response = _createSoapResponse('Seek', '');
    } else if (body.contains('GetTransportSettings')) {
      response = _createSoapResponse('GetTransportSettings', '''<PlayMode>NORMAL</PlayMode>
        <RecQualityMode>NOT_IMPLEMENTED</RecQualityMode>''');
    } else if (body.contains('GetDeviceCapabilities')) {
      response = _createSoapResponse('GetDeviceCapabilities', '''<PlayMedia>NETWORK</PlayMedia>
        <RecMedia>NOT_IMPLEMENTED</RecMedia>
        <RecQualityModes>NOT_IMPLEMENTED</RecQualityModes>''');
    } else {
      response = _createSoapResponse('Unknown', '');
    }

    request.response.headers.contentType = ContentType('text', 'xml', charset: 'utf-8');
    request.response.write(response);
    await request.response.close();
  }

  /// Handle RenderingControl control request
  Future<void> _handleRenderingControlControl(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();

    String response;

    if (body.contains('GetVolume')) {
      response = _createSoapResponse('GetVolume', '<CurrentVolume>$_volume</CurrentVolume>', service: 'RenderingControl');
    } else if (body.contains('SetVolume')) {
      final volumeMatch = RegExp(r'<DesiredVolume>(\d+)</DesiredVolume>').firstMatch(body);
      if (volumeMatch != null) {
        _volume = int.parse(volumeMatch.group(1)!);
        onSetVolume?.call(_volume);
      }
      response = _createSoapResponse('SetVolume', '', service: 'RenderingControl');
    } else if (body.contains('GetMute')) {
      response = _createSoapResponse('GetMute', '<CurrentMute>0</CurrentMute>', service: 'RenderingControl');
    } else {
      response = _createSoapResponse('Unknown', '', service: 'RenderingControl');
    }

    request.response.headers.contentType = ContentType('text', 'xml', charset: 'utf-8');
    request.response.write(response);
    await request.response.close();
  }

  /// Handle ConnectionManager control request
  Future<void> _handleConnectionManagerControl(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();

    String response;

    if (body.contains('GetProtocolInfo')) {
      response = _createSoapResponse('GetProtocolInfo', '''
        <Source></Source>
        <Sink>http-get:*:video/mp4:*,http-get:*:video/x-matroska:*,http-get:*:video/avi:*,http-get:*:video/mpeg:*,http-get:*:audio/mpeg:*,http-get:*:audio/mp4:*,http-get:*:application/x-mpegURL:*,http-get:*:video/x-flv:*</Sink>''', service: 'ConnectionManager');
    } else if (body.contains('GetCurrentConnectionIDs')) {
      response = _createSoapResponse('GetCurrentConnectionIDs', '<ConnectionIDs>0</ConnectionIDs>', service: 'ConnectionManager');
    } else {
      response = _createSoapResponse('Unknown', '', service: 'ConnectionManager');
    }

    request.response.headers.contentType = ContentType('text', 'xml', charset: 'utf-8');
    request.response.write(response);
    await request.response.close();
  }

  /// Create SOAP response
  String _createSoapResponse(String action, String body, {String service = 'AVTransport'}) {
    return '''<?xml version="1.0" encoding="UTF-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:${action}Response xmlns:u="urn:schemas-upnp-org:service:$service:1">
      $body
    </u:${action}Response>
  </s:Body>
</s:Envelope>''';
  }

  /// Decode XML entities
  String _decodeXmlEntities(String text) {
    return text
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
  }
  
  /// Escape XML special characters
  String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  /// Format duration to HH:MM:SS
  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  /// Parse duration string
  Duration _parseDuration(String str) {
    final parts = str.split(':');
    if (parts.length == 3) {
      return Duration(
        hours: int.tryParse(parts[0]) ?? 0,
        minutes: int.tryParse(parts[1]) ?? 0,
        seconds: int.tryParse(parts[2]) ?? 0,
      );
    }
    return Duration.zero;
  }


  /// AVTransport SCPD XML
  String _getAvTransportScpd() {
    return '''<?xml version="1.0" encoding="UTF-8"?>
<scpd xmlns="urn:schemas-upnp-org:service-1-0">
  <specVersion>
    <major>1</major>
    <minor>0</minor>
  </specVersion>
  <actionList>
    <action>
      <name>SetAVTransportURI</name>
      <argumentList>
        <argument>
          <name>InstanceID</name>
          <direction>in</direction>
          <relatedStateVariable>A_ARG_TYPE_InstanceID</relatedStateVariable>
        </argument>
        <argument>
          <name>CurrentURI</name>
          <direction>in</direction>
          <relatedStateVariable>AVTransportURI</relatedStateVariable>
        </argument>
        <argument>
          <name>CurrentURIMetaData</name>
          <direction>in</direction>
          <relatedStateVariable>AVTransportURIMetaData</relatedStateVariable>
        </argument>
      </argumentList>
    </action>
    <action>
      <name>Play</name>
      <argumentList>
        <argument>
          <name>InstanceID</name>
          <direction>in</direction>
          <relatedStateVariable>A_ARG_TYPE_InstanceID</relatedStateVariable>
        </argument>
        <argument>
          <name>Speed</name>
          <direction>in</direction>
          <relatedStateVariable>TransportPlaySpeed</relatedStateVariable>
        </argument>
      </argumentList>
    </action>
    <action>
      <name>Pause</name>
      <argumentList>
        <argument>
          <name>InstanceID</name>
          <direction>in</direction>
          <relatedStateVariable>A_ARG_TYPE_InstanceID</relatedStateVariable>
        </argument>
      </argumentList>
    </action>
    <action>
      <name>Stop</name>
      <argumentList>
        <argument>
          <name>InstanceID</name>
          <direction>in</direction>
          <relatedStateVariable>A_ARG_TYPE_InstanceID</relatedStateVariable>
        </argument>
      </argumentList>
    </action>
    <action>
      <name>Seek</name>
      <argumentList>
        <argument>
          <name>InstanceID</name>
          <direction>in</direction>
          <relatedStateVariable>A_ARG_TYPE_InstanceID</relatedStateVariable>
        </argument>
        <argument>
          <name>Unit</name>
          <direction>in</direction>
          <relatedStateVariable>A_ARG_TYPE_SeekMode</relatedStateVariable>
        </argument>
        <argument>
          <name>Target</name>
          <direction>in</direction>
          <relatedStateVariable>A_ARG_TYPE_SeekTarget</relatedStateVariable>
        </argument>
      </argumentList>
    </action>
    <action>
      <name>GetTransportInfo</name>
      <argumentList>
        <argument>
          <name>InstanceID</name>
          <direction>in</direction>
          <relatedStateVariable>A_ARG_TYPE_InstanceID</relatedStateVariable>
        </argument>
        <argument>
          <name>CurrentTransportState</name>
          <direction>out</direction>
          <relatedStateVariable>TransportState</relatedStateVariable>
        </argument>
        <argument>
          <name>CurrentTransportStatus</name>
          <direction>out</direction>
          <relatedStateVariable>TransportStatus</relatedStateVariable>
        </argument>
        <argument>
          <name>CurrentSpeed</name>
          <direction>out</direction>
          <relatedStateVariable>TransportPlaySpeed</relatedStateVariable>
        </argument>
      </argumentList>
    </action>
    <action>
      <name>GetPositionInfo</name>
      <argumentList>
        <argument>
          <name>InstanceID</name>
          <direction>in</direction>
          <relatedStateVariable>A_ARG_TYPE_InstanceID</relatedStateVariable>
        </argument>
        <argument>
          <name>Track</name>
          <direction>out</direction>
          <relatedStateVariable>CurrentTrack</relatedStateVariable>
        </argument>
        <argument>
          <name>TrackDuration</name>
          <direction>out</direction>
          <relatedStateVariable>CurrentTrackDuration</relatedStateVariable>
        </argument>
        <argument>
          <name>TrackMetaData</name>
          <direction>out</direction>
          <relatedStateVariable>CurrentTrackMetaData</relatedStateVariable>
        </argument>
        <argument>
          <name>TrackURI</name>
          <direction>out</direction>
          <relatedStateVariable>CurrentTrackURI</relatedStateVariable>
        </argument>
        <argument>
          <name>RelTime</name>
          <direction>out</direction>
          <relatedStateVariable>RelativeTimePosition</relatedStateVariable>
        </argument>
        <argument>
          <name>AbsTime</name>
          <direction>out</direction>
          <relatedStateVariable>AbsoluteTimePosition</relatedStateVariable>
        </argument>
        <argument>
          <name>RelCount</name>
          <direction>out</direction>
          <relatedStateVariable>RelativeCounterPosition</relatedStateVariable>
        </argument>
        <argument>
          <name>AbsCount</name>
          <direction>out</direction>
          <relatedStateVariable>AbsoluteCounterPosition</relatedStateVariable>
        </argument>
      </argumentList>
    </action>
  </actionList>
  <serviceStateTable>
    <stateVariable sendEvents="no">
      <name>A_ARG_TYPE_InstanceID</name>
      <dataType>ui4</dataType>
    </stateVariable>
    <stateVariable sendEvents="no">
      <name>AVTransportURI</name>
      <dataType>string</dataType>
    </stateVariable>
    <stateVariable sendEvents="no">
      <name>AVTransportURIMetaData</name>
      <dataType>string</dataType>
    </stateVariable>
    <stateVariable sendEvents="yes">
      <name>TransportState</name>
      <dataType>string</dataType>
      <allowedValueList>
        <allowedValue>STOPPED</allowedValue>
        <allowedValue>PLAYING</allowedValue>
        <allowedValue>TRANSITIONING</allowedValue>
        <allowedValue>PAUSED_PLAYBACK</allowedValue>
        <allowedValue>NO_MEDIA_PRESENT</allowedValue>
      </allowedValueList>
    </stateVariable>
    <stateVariable sendEvents="no">
      <name>TransportStatus</name>
      <dataType>string</dataType>
    </stateVariable>
    <stateVariable sendEvents="no">
      <name>TransportPlaySpeed</name>
      <dataType>string</dataType>
    </stateVariable>
    <stateVariable sendEvents="no">
      <name>CurrentTrack</name>
      <dataType>ui4</dataType>
    </stateVariable>
    <stateVariable sendEvents="no">
      <name>CurrentTrackDuration</name>
      <dataType>string</dataType>
    </stateVariable>
    <stateVariable sendEvents="no">
      <name>CurrentTrackMetaData</name>
      <dataType>string</dataType>
    </stateVariable>
    <stateVariable sendEvents="no">
      <name>CurrentTrackURI</name>
      <dataType>string</dataType>
    </stateVariable>
    <stateVariable sendEvents="no">
      <name>RelativeTimePosition</name>
      <dataType>string</dataType>
    </stateVariable>
    <stateVariable sendEvents="no">
      <name>AbsoluteTimePosition</name>
      <dataType>string</dataType>
    </stateVariable>
    <stateVariable sendEvents="no">
      <name>RelativeCounterPosition</name>
      <dataType>i4</dataType>
    </stateVariable>
    <stateVariable sendEvents="no">
      <name>AbsoluteCounterPosition</name>
      <dataType>i4</dataType>
    </stateVariable>
    <stateVariable sendEvents="no">
      <name>A_ARG_TYPE_SeekMode</name>
      <dataType>string</dataType>
    </stateVariable>
    <stateVariable sendEvents="no">
      <name>A_ARG_TYPE_SeekTarget</name>
      <dataType>string</dataType>
    </stateVariable>
  </serviceStateTable>
</scpd>''';
  }

  /// RenderingControl SCPD XML
  String _getRenderingControlScpd() {
    return '''<?xml version="1.0" encoding="UTF-8"?>
<scpd xmlns="urn:schemas-upnp-org:service-1-0">
  <specVersion>
    <major>1</major>
    <minor>0</minor>
  </specVersion>
  <actionList>
    <action>
      <name>GetVolume</name>
      <argumentList>
        <argument>
          <name>InstanceID</name>
          <direction>in</direction>
          <relatedStateVariable>A_ARG_TYPE_InstanceID</relatedStateVariable>
        </argument>
        <argument>
          <name>Channel</name>
          <direction>in</direction>
          <relatedStateVariable>A_ARG_TYPE_Channel</relatedStateVariable>
        </argument>
        <argument>
          <name>CurrentVolume</name>
          <direction>out</direction>
          <relatedStateVariable>Volume</relatedStateVariable>
        </argument>
      </argumentList>
    </action>
    <action>
      <name>SetVolume</name>
      <argumentList>
        <argument>
          <name>InstanceID</name>
          <direction>in</direction>
          <relatedStateVariable>A_ARG_TYPE_InstanceID</relatedStateVariable>
        </argument>
        <argument>
          <name>Channel</name>
          <direction>in</direction>
          <relatedStateVariable>A_ARG_TYPE_Channel</relatedStateVariable>
        </argument>
        <argument>
          <name>DesiredVolume</name>
          <direction>in</direction>
          <relatedStateVariable>Volume</relatedStateVariable>
        </argument>
      </argumentList>
    </action>
    <action>
      <name>GetMute</name>
      <argumentList>
        <argument>
          <name>InstanceID</name>
          <direction>in</direction>
          <relatedStateVariable>A_ARG_TYPE_InstanceID</relatedStateVariable>
        </argument>
        <argument>
          <name>Channel</name>
          <direction>in</direction>
          <relatedStateVariable>A_ARG_TYPE_Channel</relatedStateVariable>
        </argument>
        <argument>
          <name>CurrentMute</name>
          <direction>out</direction>
          <relatedStateVariable>Mute</relatedStateVariable>
        </argument>
      </argumentList>
    </action>
  </actionList>
  <serviceStateTable>
    <stateVariable sendEvents="no">
      <name>A_ARG_TYPE_InstanceID</name>
      <dataType>ui4</dataType>
    </stateVariable>
    <stateVariable sendEvents="no">
      <name>A_ARG_TYPE_Channel</name>
      <dataType>string</dataType>
    </stateVariable>
    <stateVariable sendEvents="no">
      <name>Volume</name>
      <dataType>ui2</dataType>
      <allowedValueRange>
        <minimum>0</minimum>
        <maximum>100</maximum>
        <step>1</step>
      </allowedValueRange>
    </stateVariable>
    <stateVariable sendEvents="no">
      <name>Mute</name>
      <dataType>boolean</dataType>
    </stateVariable>
  </serviceStateTable>
</scpd>''';
  }

  /// ConnectionManager SCPD XML
  String _getConnectionManagerScpd() {
    return '''<?xml version="1.0" encoding="UTF-8"?>
<scpd xmlns="urn:schemas-upnp-org:service-1-0">
  <specVersion>
    <major>1</major>
    <minor>0</minor>
  </specVersion>
  <actionList>
    <action>
      <name>GetProtocolInfo</name>
      <argumentList>
        <argument>
          <name>Source</name>
          <direction>out</direction>
          <relatedStateVariable>SourceProtocolInfo</relatedStateVariable>
        </argument>
        <argument>
          <name>Sink</name>
          <direction>out</direction>
          <relatedStateVariable>SinkProtocolInfo</relatedStateVariable>
        </argument>
      </argumentList>
    </action>
    <action>
      <name>GetCurrentConnectionIDs</name>
      <argumentList>
        <argument>
          <name>ConnectionIDs</name>
          <direction>out</direction>
          <relatedStateVariable>CurrentConnectionIDs</relatedStateVariable>
        </argument>
      </argumentList>
    </action>
  </actionList>
  <serviceStateTable>
    <stateVariable sendEvents="no">
      <name>SourceProtocolInfo</name>
      <dataType>string</dataType>
    </stateVariable>
    <stateVariable sendEvents="no">
      <name>SinkProtocolInfo</name>
      <dataType>string</dataType>
    </stateVariable>
    <stateVariable sendEvents="no">
      <name>CurrentConnectionIDs</name>
      <dataType>string</dataType>
    </stateVariable>
  </serviceStateTable>
</scpd>''';
  }
}
