import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

// ─── FIX #1 ───────────────────────────────────────────────────────────────────
// The pending deep-link URL must survive across widget rebuilds.  We store it
// in a top-level variable so it is accessible both from the background-message
// handler (which runs before the widget tree exists) and from the WebView's
// onLoadStop callback (which runs after the widget tree is ready).
// Previously it was only stored inside _WebViewPageState, so a terminated-app
// launch (getInitialMessage) could set it before the state object existed, and
// it was lost.
String? _globalPendingDeepLink;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
  }

  // ─── FIX #2 ─────────────────────────────────────────────────────────────────
  // Capture the deep-link URL from a terminated-app launch BEFORE runApp() is
  // called.  The old code called getInitialMessage() inside initState(), which
  // runs after the widget tree is built and after the WebView has already
  // started loading the homepage — so the pending URL was often set too late
  // and the "already on target page" guard cleared it immediately.
  try {
    final RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      final String? url = initialMessage.data['url'] ??
          initialMessage.data['link'] ??
          initialMessage.data['click_action'];
      if (url != null && url.isNotEmpty && url != 'FLUTTER_NOTIFICATION_CLICK') {
        _globalPendingDeepLink = url;
        debugPrint("Terminated-app deep link captured at startup: $url");
      }
    }
  } catch (e) {
    debugPrint("getInitialMessage failed: $e");
  }

  if (Platform.isAndroid) {
    await Permission.notification.request();
  }
  runApp(const KryrosUserApp());
}

class KryrosUserApp extends StatelessWidget {
  const KryrosUserApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KRYROS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF27B9AF),
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF27B9AF),
          primary: const Color(0xFF27B9AF),
          surface: const Color(0xFF050816),
        ),
      ),
      home: const MainContainer(url: 'https://kryros.com'),
    );
  }
}

class MainContainer extends StatefulWidget {
  final String url;
  const MainContainer({super.key, required this.url});
  @override
  State<MainContainer> createState() => _MainContainerState();
}

class _MainContainerState extends State<MainContainer> {
  bool _showSplash = true;
  bool _isWebViewReady = false;
  
  void _onWebViewReady() {
    if (mounted && _showSplash) {
      debugPrint("WebView ready, starting splash transition");
      setState(() {
        _isWebViewReady = true;
      });
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() {
            _showSplash = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050816),
      body: Stack(
        children: [
          Offstage(
            offstage: false,
            child: WebViewPage(
              url: widget.url,
              onPageFinished: _onWebViewReady,
            ),
          ),
          if (_showSplash)
            SplashScreen(
              isTransitioning: _isWebViewReady,
            ),
        ],
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  final bool isTransitioning;
  const SplashScreen({super.key, this.isTransitioning = false});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _bounceController;
  late AnimationController _blinkController;
  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _bounceController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
    _blinkController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
  }
  @override
  void dispose() {
    _pulseController.dispose();
    _bounceController.dispose();
    _blinkController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF27B9AF);
    const backgroundColor = Color(0xFF050816);
    return Scaffold(
      backgroundColor: backgroundColor,
      body: AnimatedOpacity(
        opacity: widget.isTransitioning ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 800),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  ...List.generate(3, (index) {
                    return AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final delay = index * 0.35;
                        double progress = (_pulseController.value - delay);
                        if (progress < 0) progress += 1.0;
                        final scale = 0.85 + (progress * 0.4);
                        final opacity = progress < 0.6 ? (0.9 - (progress / 0.6 * 0.55)) : (0.35 - ((progress - 0.6) / 0.4 * 0.35));
                        return Transform.scale(
                          scale: scale,
                          child: Opacity(
                            opacity: opacity.clamp(0.0, 1.0),
                            child: Container(
                              width: 54.0 + (index + 1) * 26.0,
                              height: 54.0 + (index + 1) * 26.0,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: primaryColor.withOpacity(0.5 - (index + 1) * 0.12), width: index == 0 ? 2.0 : 1.5),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }),
                  FadeTransition(
                    opacity: Tween<double>(begin: 1.0, end: 0.4).animate(CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut)),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: primaryColor.withOpacity(0.8), width: 2.0)),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/logo_circular.png',
                          width: 70, height: 70, fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.circle, color: primaryColor, size: 70),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              FadeTransition(
                opacity: Tween<double>(begin: 1.0, end: 0.5).animate(CurvedAnimation(parent: _blinkController, curve: const Interval(0.2, 1.0, curve: Curves.easeInOut))),
                child: const Text('KRYROS', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 4.0)),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  return AnimatedBuilder(
                    animation: _bounceController,
                    builder: (context, child) {
                      final delay = index * 0.2;
                      double progress = (_bounceController.value - delay);
                      if (progress < 0) progress += 1.0;
                      final offset = -8.0 * (1.0 - (progress - 0.5).abs() * 2.0).clamp(0.0, 1.0);
                      return Transform.translate(offset: Offset(0, offset), child: Container(width: 6, height: 6, margin: const EdgeInsets.symmetric(horizontal: 4), decoration: const BoxDecoration(color: primaryColor, shape: BoxShape.circle)));
                    },
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WebViewPage extends StatefulWidget {
  final String url;
  final VoidCallback onPageFinished;
  const WebViewPage({super.key, required this.url, required this.onPageFinished});
  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  InAppWebViewController? _webViewController;
  PullToRefreshController? _pullToRefreshController;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  double _progress = 0;
  bool _isOffline = false;
  bool _isWebViewReady = false;
  String? _fcmToken;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  static const _notificationTokenEndpoint = 'https://api.kryros.com/api/notifications/token/public';

  @override
  void initState() {
    super.initState();
    _setupNotifications();
    _checkConnectivity();
    _pullToRefreshController = PullToRefreshController(
      settings: PullToRefreshSettings(color: const Color(0xFF27B9AF), backgroundColor: const Color(0xFF050816)),
      onRefresh: () async {
        if (Platform.isAndroid) _webViewController?.reload();
        else if (Platform.isIOS) _webViewController?.loadUrl(urlRequest: URLRequest(url: await _webViewController?.getUrl()));
      },
    );
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      setState(() => _isOffline = results.contains(ConnectivityResult.none));
      if (!_isOffline) _webViewController?.reload();
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _tokenRefreshSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    var results = await Connectivity().checkConnectivity();
    setState(() => _isOffline = results.contains(ConnectivityResult.none));
  }

  Future<void> _setupNotifications() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    _fcmToken = await messaging.getToken();
    if (_fcmToken != null) await _registerNativeToken(_fcmToken!);
    _tokenRefreshSubscription = messaging.onTokenRefresh.listen((token) async {
      _fcmToken = token;
      await _registerNativeToken(token);
      await _registerTokens();
    });

    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('launcher_icon');
    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(requestAlertPermission: true, requestBadgePermission: true, requestSoundPermission: true);
    const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid, iOS: initializationSettingsIOS);
    
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint("Notification tapped (foreground): ${response.payload}");
        if (response.payload != null && response.payload!.isNotEmpty) {
          // Use a small delay for foreground taps to ensure the app is focused
          Future.delayed(const Duration(milliseconds: 500), () {
            _navigateToUrl(response.payload!);
          });
        }
      },
    );

    // ─── FIX #2 (continued) ────────────────────────────────────────────────────
    // getInitialMessage() is now called in main() before runApp(), so we no
    // longer call it here.  The result is already stored in _globalPendingDeepLink
    // and will be consumed in onLoadStop below.

    // ─── Foreground messages ───────────────────────────────────────────────────
    FirebaseMessaging.onMessage.listen((message) async {
      final RemoteNotification? notification = message.notification;
      if (notification != null) {
        final String? imageUrl = message.data['imageUrl'] ?? message.data['image'] ?? notification.android?.imageUrl;
        final String? payload = message.data['url'] ?? message.data['link'] ??
            (message.data['click_action'] != 'FLUTTER_NOTIFICATION_CLICK' ? message.data['click_action'] : null);
        debugPrint("Foreground notification received, payload: $payload");
        BigPictureStyleInformation? bigPictureStyleInformation;
        if (imageUrl != null && imageUrl.isNotEmpty) {
          try {
            final String filePath = await _downloadAndSaveFile(imageUrl, 'notif_banner_${notification.hashCode}');
            bigPictureStyleInformation = BigPictureStyleInformation(
              FilePathAndroidBitmap(filePath),
              largeIcon: FilePathAndroidBitmap(filePath),
              contentTitle: notification.title,
              summaryText: notification.body,
            );
          } catch (e) {
            debugPrint('Failed to download notification banner image: $e');
          }
        }
        await flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'kryros_notifications',
              'KRYROS Notifications',
              importance: Importance.max,
              priority: Priority.high,
              icon: 'launcher_icon',
              styleInformation: bigPictureStyleInformation,
            ),
            iOS: const DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
          ),
          payload: (payload != null && payload.isNotEmpty) ? payload : null,
        );
      }
    });

    // ─── Background / app-in-background tap ───────────────────────────────────
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final String? url = message.data['url'] ?? message.data['link'] ??
          (message.data['click_action'] != 'FLUTTER_NOTIFICATION_CLICK' ? message.data['click_action'] : null);
      debugPrint("Background notification tapped, url: $url");
      if (url != null && url.isNotEmpty) {
        _navigateToUrl(url);
      }
    });
  }

  // ─── FIX #3 ─────────────────────────────────────────────────────────────────
  // The old _navigateToUrl stored the URL in the instance field _pendingDeepLinkUrl.
  // But when the WebView is already ready (app was in background), it called
  // _loadUrl() directly — which is correct.  However, when the app was terminated
  // and relaunched, the URL was stored in the instance field which was created
  // AFTER getInitialMessage() had already been called in initState, causing a
  // race condition.  Now we always write to _globalPendingDeepLink as the single
  // source of truth, and _loadUrl() is called from onLoadStop.
  void _navigateToUrl(String url) {
    debugPrint("Routing to URL: $url");
    if (url.isEmpty) return;

    // Normalise relative paths
    String target = url;
    if (!url.startsWith('http') && !url.startsWith('/')) {
      target = '/$url';
    }

    if (_isWebViewReady && _webViewController != null) {
      _loadUrl(target);
    } else {
      _globalPendingDeepLink = target;
    }
  }

  Future<String> _downloadAndSaveFile(String url, String fileName) async {
    final Directory directory = await getApplicationDocumentsDirectory();
    final String filePath = '${directory.path}/$fileName';
    final http.Response response = await http.get(Uri.parse(url));
    final File file = File(filePath);
    await file.writeAsBytes(response.bodyBytes);
    return filePath;
  }

  Future<void> _registerNativeToken(String token) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse(_notificationTokenEndpoint));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'token': token, 'platform': Platform.isIOS ? 'ios' : 'android'}));
      final response = await request.close();
      await response.drain();
    } catch (_) {} finally { client.close(force: true); }
  }

  void _loadUrl(String url) {
    if (url.isEmpty) return;
    debugPrint("WebView loading: $url");
    
    String target = url;
    
    if (url.startsWith('http')) {
      target = url;
    } else {
      try {
        final baseUri = Uri.parse(widget.url);
        final path = url.startsWith('/') ? url : '/$url';
        // ─── FIX #4 ───────────────────────────────────────────────────────────
        // The old code called baseUri.replace(...).resolve(path) which double-
        // resolved the path and could produce a malformed URL such as
        // "https://kryros.com/product" being resolved against "/shop" to give
        // "https://kryros.com/shop" correctly, but then the extra .resolve()
        // call would re-resolve it against the already-replaced URI, sometimes
        // stripping query parameters or producing an incorrect path.
        // We now simply replace the path on the base URI and handle query
        // parameters separately.
        if (url.contains('?')) {
          final parts = url.split('?');
          final cleanPath = parts[0].startsWith('/') ? parts[0] : '/${parts[0]}';
          target = baseUri.replace(path: cleanPath, query: parts[1], fragment: null).toString();
        } else {
          target = baseUri.replace(path: path, query: null, fragment: null).toString();
        }
      } catch (e) {
        debugPrint("Error resolving relative URL: $e");
        target = widget.url + (url.startsWith('/') ? url : '/$url');
      }
    }
    
    debugPrint("Final resolved target: $target");
    _webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(target)));
  }

  Future<void> _registerTokens() async {
    final token = _fcmToken;
    if (token == null || _webViewController == null) return;
    await _registerNativeToken(token);
    final encodedToken = jsonEncode(token);
    await _webViewController?.evaluateJavascript(source: """
      window.kryrosIsNativeApp = true;
      window.kryrosNativeFcmToken = $encodedToken;
      window.dispatchEvent(new CustomEvent('kryros:native-fcm-token', { detail: $encodedToken }));
    """);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050816),
      body: SafeArea(
        child: Column(
          children: [
            if (_progress < 1.0 && !_isOffline) LinearProgressIndicator(value: _progress, color: const Color(0xFF27B9AF), backgroundColor: Colors.transparent, minHeight: 2),
            Expanded(
              child: Stack(
                children: [
                  PopScope(
                    canPop: false,
                    onPopInvoked: (didPop) async {
                      if (didPop) return;
                      if (await _webViewController?.canGoBack() ?? false) _webViewController?.goBack();
                    },
                    child: InAppWebView(
                      initialUrlRequest: URLRequest(url: WebUri(widget.url)),
                      initialSettings: InAppWebViewSettings(
                        javaScriptEnabled: true,
                        domStorageEnabled: true,
                        databaseEnabled: true,
                        useShouldOverrideUrlLoading: true,
                        useOnDownloadStart: true,
                        allowFileAccessFromFileURLs: true,
                        allowUniversalAccessFromFileURLs: true,
                        verticalScrollBarEnabled: false,
                        horizontalScrollBarEnabled: false,
                        transparentBackground: true, 
                        mediaPlaybackRequiresUserGesture: false,
                        javaScriptCanOpenWindowsAutomatically: true,
                        cacheEnabled: true,
                        clearCache: false,
                        supportZoom: false,
                        preferredContentMode: UserPreferredContentMode.MOBILE,
                        userAgent: "Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Mobile Safari/537.36 KryrosApp",
                        mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                        allowContentAccess: true,
                        builtInZoomControls: false,
                        displayZoomControls: false,
                        cacheMode: CacheMode.LOAD_DEFAULT,
                        hardwareAcceleration: true,
                        safeBrowsingEnabled: false,
                        allowFileAccess: true,
                        geolocationEnabled: true,
                      ),
                      pullToRefreshController: _pullToRefreshController,
                      onWebViewCreated: (controller) {
                        _webViewController = controller;
                        controller.addJavaScriptHandler(handlerName: 'MobileBridge', callback: (args) { if (args.isNotEmpty && args[0] == 'user_logged_in') _registerTokens(); });
                      },
                      onLoadStop: (controller, url) async {
                        debugPrint("WebView finished loading: $url");
                        _pullToRefreshController?.endRefreshing();
                        setState(() => _progress = 1.0);
                        
                        widget.onPageFinished();
                        _registerTokens();

                        if (!_isWebViewReady) {
                          _isWebViewReady = true;
                        }
                        
                        // ─── FIX #1 + #2 (consumption) ──────────────────────
                        // Consume the global pending deep link.  We only act on
                        // it when the current page is the homepage (base URL),
                        // meaning this is the very first load after a cold start
                        // triggered by a notification tap.  If the WebView has
                        // already navigated to the target page (e.g. a second
                        // onLoadStop fires after _loadUrl), we clear it without
                        // re-navigating to avoid an infinite loop.
                        if (_globalPendingDeepLink != null) {
                          final pending = _globalPendingDeepLink!;
                          final currentUrl = url?.toString() ?? '';
                          
                          // Resolve the pending URL so we can compare properly
                          String resolvedPending = pending;
                          if (!pending.startsWith('http')) {
                            final path = pending.startsWith('/') ? pending : '/$pending';
                            try {
                              resolvedPending = Uri.parse(widget.url).replace(path: path.split('?')[0], query: path.contains('?') ? path.split('?')[1] : null).toString();
                            } catch (_) {}
                          }

                          if (currentUrl == resolvedPending || currentUrl.startsWith(resolvedPending)) {
                            // Already on the target page — just clear
                            debugPrint("Already on target page ($currentUrl), clearing pending link");
                            _globalPendingDeepLink = null;
                          } else {
                            // Navigate to the deep link after React hydration
                            _globalPendingDeepLink = null;
                            debugPrint("Processing pending deep link: $pending");
                            Future.delayed(const Duration(milliseconds: 2000), () {
                              if (mounted) _loadUrl(pending);
                            });
                          }
                        }
                      },
                      onReceivedError: (controller, request, error) { debugPrint("WebView Error: ${error.description}"); _pullToRefreshController?.endRefreshing(); },
                      onProgressChanged: (controller, progress) { if (progress == 100) _pullToRefreshController?.endRefreshing(); setState(() => _progress = progress / 100); },
                      shouldOverrideUrlLoading: (controller, navigationAction) async {
                        var uri = navigationAction.request.url;
                        if (uri != null && !["http", "https", "file", "chrome", "data", "javascript", "about"].contains(uri.scheme)) {
                          if (await canLaunchUrl(uri)) { await launchUrl(uri, mode: LaunchMode.externalApplication); return NavigationActionPolicy.CANCEL; }
                        }
                        return NavigationActionPolicy.ALLOW;
                      },
                    ),
                  ),
                  if (_isOffline) Container(color: const Color(0xFF050816), child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.wifi_off, color: Colors.white, size: 64), const SizedBox(height: 16), const Text('No Internet Connection', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 8), const Text('Please check your network settings.', style: TextStyle(color: Colors.white70)), const SizedBox(height: 24), ElevatedButton(onPressed: () => _webViewController?.reload(), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF27B9AF)), child: const Text('Retry', style: TextStyle(color: Colors.white)))]))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
