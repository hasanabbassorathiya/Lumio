import 'dart:io';
import 'service_locator.dart';

/// Redirect URL cache entry
class _RedirectCacheEntry {
  final String realUrl;
  final DateTime timestamp;
  
  _RedirectCacheEntry(this.realUrl, this.timestamp);
}

/// Global redirect cache service
/// Used to cache real playback addresses from HTTP 302 redirects
class RedirectCacheService {
  static final RedirectCacheService _instance = RedirectCacheService._internal();
  factory RedirectCacheService() => _instance;
  RedirectCacheService._internal();

  final Map<String, _RedirectCacheEntry> _cache = {};
  static const _cacheExpiryDuration = Duration(hours: 24); // 24 hours expiry

  /// Resolve real playback address (handle 302 redirect with cache)
  Future<String> resolveRealPlayUrl(String url) async {
    // Check cache
    final cached = _cache[url];
    if (cached != null) {
      final now = DateTime.now();
      if (now.difference(cached.timestamp) < _cacheExpiryDuration) {
        ServiceLocator.log.d('Using cached redirect: $url -> ${cached.realUrl}');
        return cached.realUrl;
      } else {
        // Cache expired, removing
        _cache.remove(url);
        ServiceLocator.log.d('Cache expired, re-resolving: $url');
      }
    }

    // Resolving redirect
    try {
      final client = HttpClient();
      client.autoUncompress = true;
      
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set(HttpHeaders.userAgentHeader, 'miguvideo_android');
      
      // Do not follow redirects automatically, manually get Location
      request.followRedirects = false;
      
      final response = await request.close();
      
      if (response.isRedirect) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        if (location != null) {
          ServiceLocator.log.d('Resolving redirect: $url -> $location');
          await response.drain();
          client.close();
          
          // Cache result
          _cache[url] = _RedirectCacheEntry(location, DateTime.now());
          
          return location;
        }
      }
      
      await response.drain();
      client.close();
      
      // If no redirect, return original URL (no cache)
      ServiceLocator.log.d('No redirect, using original URL: $url');
      return url;
    } catch (e) {
      ServiceLocator.log.e('Failed to resolve playback address: $e');
      // Return original URL on failure
      return url;
    }
  }

  /// Clear cache for specific URL
  void clearCache(String url) {
    _cache.remove(url);
    ServiceLocator.log.d('Clear cache: $url');
  }

  /// Clear all cache
  void clearAllCache() {
    _cache.clear();
    ServiceLocator.log.d('Clear all redirect cache');
  }

  /// Clear expired cache
  void clearExpiredCache() {
    final now = DateTime.now();
    _cache.removeWhere((url, entry) {
      final expired = now.difference(entry.timestamp) >= _cacheExpiryDuration;
      if (expired) {
        ServiceLocator.log.d('Clear expired cache: $url');
      }
      return expired;
    });
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'total': _cache.length,
      'entries': _cache.entries.map((e) {
        final age = DateTime.now().difference(e.value.timestamp);
        return {
          'url': e.key,
          'realUrl': e.value.realUrl,
          'age': '${age.inMinutes}minutes',
        };
      }).toList(),
    };
  }
}
