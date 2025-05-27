import 'dart:html' as html;
import 'dart:developer' as developer;

class WebUtils {
  static Object createEventSource(String url) {
    developer.log('Creating EventSource for URL: $url', name: 'WebUtils');
    try {
      return html.EventSource(url);
    } catch (e) {
      developer.log('Error creating EventSource: $e',
          name: 'WebUtils', error: e);
      rethrow; // Rethrow to handle in the calling code
    }
  }

  static void onEventSourceOpen(Object eventSource, Function callback) {
    developer.log('Setting up onOpen listener', name: 'WebUtils');
    (eventSource as html.EventSource).onOpen.listen((event) {
      developer.log('EventSource opened successfully', name: 'WebUtils');
      callback();
    });
  }

  static void onEventSourceMessage(
      Object eventSource, Function(String data) callback) {
    developer.log('Setting up onMessage listener', name: 'WebUtils');
    (eventSource as html.EventSource)
        .onMessage
        .listen((html.MessageEvent event) {
      try {
        final String data = event.data?.toString() ?? '';
        developer.log(
            'Received message: ${data.substring(0, data.length > 100 ? 100 : data.length)}...',
            name: 'WebUtils');
        callback(data);
      } catch (e) {
        developer.log('Error processing message: $e',
            name: 'WebUtils', error: e);
      }
    });
  }

  static void onEventSourceError(Object eventSource, Function callback) {
    developer.log('Setting up onError listener', name: 'WebUtils');
    (eventSource as html.EventSource).onError.listen((event) {
      developer.log('EventSource error occurred', name: 'WebUtils');
      callback();
    });
  }

  static void closeEventSource(Object? eventSource) {
    if (eventSource != null) {
      developer.log('Closing EventSource', name: 'WebUtils');
      (eventSource as html.EventSource).close();
    }
  }
}
