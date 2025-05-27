class WebUtils {
  static Object createEventSource(String url) {
    throw UnsupportedError('EventSource is only available on web');
  }

  static void onEventSourceOpen(Object eventSource, Function callback) {
    // No-op on mobile
  }

  static void onEventSourceMessage(
      Object eventSource, Function(String data) callback) {
    // No-op on mobile
  }

  /// Stub for handling error events - not used on mobile
  static void onEventSourceError(Object eventSource, Function callback) {
    // No-op on mobile
  }

  /// Stub for closing EventSource - not used on mobile
  static void closeEventSource(Object? eventSource) {
    // No-op on mobile
  }
}
