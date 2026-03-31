import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart' as flutter_webview;
import 'package:webview_windows/webview_windows.dart' as windows_webview;

typedef CodingAgentEmbeddedBrowserHostFactory =
    CodingAgentEmbeddedBrowserHost Function(
      CodingAgentEmbeddedBrowserCallbacks callbacks,
    );

class CodingAgentEmbeddedBrowserCallbacks {
  const CodingAgentEmbeddedBrowserCallbacks({
    required this.onUrlChanged,
    required this.onLoadError,
    required this.openExternalUrl,
  });

  final ValueChanged<String> onUrlChanged;
  final ValueChanged<String> onLoadError;
  final Future<void> Function(Uri url) openExternalUrl;
}

abstract class CodingAgentEmbeddedBrowserHost {
  Future<void> load(Uri initialUrl);
  Future<void> reload();
  Widget buildView();
  Future<void> dispose();
}

CodingAgentEmbeddedBrowserHost createDefaultCodingAgentEmbeddedBrowserHost(
  CodingAgentEmbeddedBrowserCallbacks callbacks,
) {
  if (Platform.isMacOS) {
    return _MacOsCodingAgentEmbeddedBrowserHost(callbacks);
  }
  if (Platform.isWindows) {
    return _WindowsCodingAgentEmbeddedBrowserHost(callbacks);
  }
  throw const CodingAgentEmbeddedBrowserException(
    'Embedded browser hosting is only available on macOS and Windows.',
  );
}

class CodingAgentEmbeddedBrowserException implements Exception {
  const CodingAgentEmbeddedBrowserException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _MacOsCodingAgentEmbeddedBrowserHost
    implements CodingAgentEmbeddedBrowserHost {
  _MacOsCodingAgentEmbeddedBrowserHost(this._callbacks);

  final CodingAgentEmbeddedBrowserCallbacks _callbacks;
  late final flutter_webview.WebViewController _controller =
      flutter_webview.WebViewController();

  @override
  Future<void> load(Uri initialUrl) async {
    final Uri origin = _originOf(initialUrl);
    final flutter_webview.NavigationDelegate navigationDelegate =
        flutter_webview.NavigationDelegate(
      onNavigationRequest: (flutter_webview.NavigationRequest request) {
        final Uri? requested = Uri.tryParse(request.url);
        if (requested == null) {
          return flutter_webview.NavigationDecision.navigate;
        }

        final bool isHttpLike =
            requested.scheme == 'http' || requested.scheme == 'https';
        final bool sameOrigin =
            requested.scheme == origin.scheme &&
            requested.host == origin.host &&
            requested.port == origin.port;

        if (!isHttpLike || sameOrigin) {
          return flutter_webview.NavigationDecision.navigate;
        }

        unawaited(_callbacks.openExternalUrl(requested));
        return flutter_webview.NavigationDecision.prevent;
      },
      onWebResourceError: (flutter_webview.WebResourceError error) {
        if (error.isForMainFrame == false) {
          return;
        }
        _callbacks.onLoadError(error.description.trim());
      },
      onPageStarted: _callbacks.onUrlChanged,
      onPageFinished: _callbacks.onUrlChanged,
    );

    await _controller.setJavaScriptMode(
      flutter_webview.JavaScriptMode.unrestricted,
    );
    await _controller.setNavigationDelegate(navigationDelegate);
    await _controller.loadRequest(initialUrl);
  }

  @override
  Future<void> reload() => _controller.reload();

  @override
  Widget buildView() {
    return flutter_webview.WebViewWidget(controller: _controller);
  }

  @override
  Future<void> dispose() async {}
}

class _WindowsCodingAgentEmbeddedBrowserHost
    implements CodingAgentEmbeddedBrowserHost {
  _WindowsCodingAgentEmbeddedBrowserHost(this._callbacks);

  final CodingAgentEmbeddedBrowserCallbacks _callbacks;
  final windows_webview.WebviewController _controller =
      windows_webview.WebviewController();
  StreamSubscription<String>? _urlSubscription;
  StreamSubscription<windows_webview.WebErrorStatus>? _errorSubscription;
  bool _controllerInitialized = false;

  @override
  Future<void> load(Uri initialUrl) async {
    final String? webViewVersion =
        await windows_webview.WebviewController.getWebViewVersion();
    if (webViewVersion == null || webViewVersion.trim().isEmpty) {
      throw const CodingAgentEmbeddedBrowserException(
        'Microsoft Edge WebView2 Runtime is required to use the embedded Coding Agent view on Windows. Install WebView2 or use Open in Browser.',
      );
    }

    await _controller.initialize();
    _controllerInitialized = true;
    _urlSubscription = _controller.url.listen(_callbacks.onUrlChanged);
    _errorSubscription = _controller.onLoadError.listen(
      (windows_webview.WebErrorStatus status) {
        _callbacks.onLoadError('Embedded browser error: $status');
      },
    );
    await _controller.loadUrl(initialUrl.toString());
    _callbacks.onUrlChanged(initialUrl.toString());
  }

  @override
  Future<void> reload() => _controller.reload();

  @override
  Widget buildView() {
    return windows_webview.Webview(_controller);
  }

  @override
  Future<void> dispose() async {
    await _urlSubscription?.cancel();
    await _errorSubscription?.cancel();
    if (!_controllerInitialized) {
      return;
    }
    try {
      await _controller.dispose();
    } catch (error) {
      if (error.runtimeType.toString() == 'LateInitializationError') {
        // `webview_windows` can throw here if initialization failed before its
        // internal creation completer was set up. Treat that as already disposed.
        return;
      }
      rethrow;
    }
  }
}

Uri _originOf(Uri uri) {
  if (uri.hasPort) {
    return Uri(scheme: uri.scheme, host: uri.host, port: uri.port);
  }
  return Uri(scheme: uri.scheme, host: uri.host);
}
