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

String? _globalPendingDeepLink;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
  }

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
        primaryColor: const Color(0xFFC0151B), // KRYROS RED
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFC0151B),
          primary: const Color(0xFFC0151B),
          surface: Colors.white,
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
      backgroundColor: Colors.white,
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
    const primaryColor = Color(0xFFC0151B); // KRYROS RED
    const backgroundColor = Colors.white; // WHITE BACKGROUND
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
                child: const Text('KRYROS', style: TextStyle(color: primaryColor, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 4.0)),
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
      settings: PullToRefreshSettings(color: const Color(0xFFC0151B), backgroundColor: Colors.white),
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
    });

    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('launcher_icon');
    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(requestAlertPermission: true, requestBadgePermission: true, requestSoundPermission: true);
    const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid, iOS: initializationSettingsIOS);
    
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint("Notification tapped (foreground): ${response.payload}");
        if (response.payload != null && response.payload!.isNotEmpty) {
          Future.delayed(const Duration(milliseconds: 500), () {
            _navigateToUrl(response.payload!);
          });
        }
      },
    );

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

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final String? url = message.data['url'] ?? message.data['link'] ??
          (message.data['click_action'] != 'FLUTTER_NOTIFICATION_CLICK' ? message.data['click_action'] : null);
      debugPrint("Background notification tapped, url: $url");
      if (url != null && url.isNotEmpty) {
        _navigateToUrl(url);
      }
    });
  }

  void _navigateToUrl(String url) {
    debugPrint("Routing to URL: $url");
    if (url.isEmpty) return;

    String target = url;
    
    // If it's a relative path, ensure it starts with /
    if (!url.startsWith('http') && !url.startsWith('/')) {
      target = '/$url';
    }

    // Special case for tracking links that might be missing the track prefix
    if (target.contains('orderNumber=') && !target.contains('/track')) {
      target = '/track${target.startsWith('/') ? '' : '/'}$target';
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
        if (url.contains('?')) {
          final parts = url.split('?');
          final cleanPath = parts[0].startsWith('/') ? parts[0] : '/${parts[0]}';
          target = baseUri.replace(path: cleanPath, query: parts[1], fragment: null).toString();
        } else {
          target = baseUri.replace(path: path, query: null, fragment: null).toString();
        }
      } catch (e) {
        target = widget.url + (url.startsWith('/') ? url : '/$url');
      }
    }
    _webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(target)));
  }

  Future<void> _syncTokenWithUser() async {
    try {
      final String? token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      // Extract token from cookies to see if we are authenticated
      final cookieManager = CookieManager.instance();
      final cookies = await cookieManager.getCookies(url: WebUri(widget.url));
      final hasToken = cookies.any((c) => c.name == 'kryros_token' || c.name == 'token');

      if (hasToken) {
        debugPrint("Syncing FCM token with authenticated user...");
        final String endpoint = "${widget.url.replaceAll(RegExp(r'/$'), '')}/api/notifications/token";
        final String? authToken = cookies.firstWhere((c) => c.name == 'kryros_token' || c.name == 'token').value;

        await http.post(
          Uri.parse(endpoint),
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $authToken",
          },
          body: jsonEncode({
            "token": token,
            "platform": Theme.of(context).platform == TargetPlatform.iOS ? "ios" : "android",
          }),
        );
      }
    } catch (e) {
      debugPrint("Error syncing token with user: $e");
    }
  }

  Future<void> _handleExternalLink(Uri uri) async {
    final String urlString = uri.toString();
    debugPrint("Intercepted external link: $urlString");
    
    // 1. Aggressive WhatsApp check (schemes and domains)
    if (uri.scheme == 'whatsapp' || uri.host.contains('wa.me') || uri.host.contains('whatsapp.com')) {
      try {
        // Try launching as external application
        bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!launched && (uri.host.contains('wa.me') || uri.host.contains('whatsapp.com'))) {
          // If wa.me link fails to launch app, try forcing it as an external browser link
          await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
        }
      } catch (e) {
        debugPrint("Error launching WhatsApp: $e");
      }
      return;
    }

    // 2. Handle other common external schemes
    if (["tel", "sms", "mailto", "intent"].contains(uri.scheme)) {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: WillPopScope(
          onWillPop: () async {
            if (_webViewController != null && await _webViewController!.canGoBack()) {
              _webViewController!.goBack();
              return false;
            }
            return true;
          },
          child: Stack(
            children: [
              InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(widget.url)),
                pullToRefreshController: _pullToRefreshController,
                initialOptions: InAppWebViewGroupOptions(
                  crossPlatform: InAppWebViewOptions(
                    useShouldOverrideUrlLoading: true,
                    mediaPlaybackRequiresUserGesture: false,
                    javaScriptEnabled: true,
                    userAgent: "KRYROS_APP_ANDROID",
                    supportZoom: false,
                  ),
                  android: AndroidInAppWebViewOptions(
                    useHybridComposition: true,
                    domStorageEnabled: true,
                  ),
                ),
                onWebViewCreated: (controller) {
                  _webViewController = controller;
                  _isWebViewReady = true;
                },
                shouldOverrideUrlLoading: (controller, navigationAction) async {
                  var uri = navigationAction.request.url!;
                  debugPrint("Checking URL: ${uri.toString()}");
                  
                  // Intercept non-http(s) schemes
                  if (!["http", "https", "file", "chrome", "data", "javascript", "about"].contains(uri.scheme)) {
                    await _handleExternalLink(uri);
                    return NavigationActionPolicy.CANCEL;
                  }
                  
                  // Aggressively intercept wa.me and whatsapp.com links even if they use https
                  if (uri.host.contains("wa.me") || uri.host.contains("whatsapp.com")) {
                    await _handleExternalLink(uri);
                    return NavigationActionPolicy.CANCEL;
                  }

                  return NavigationActionPolicy.ALLOW;
                },
                onLoadStop: (controller, url) async {
                  _pullToRefreshController?.endRefreshing();
                  widget.onPageFinished();

                  // Sync FCM token with authenticated user if we are on a likely post-login page
                  if (url != null) {
                    final urlStr = url.toString();
                    if (urlStr.contains('/profile') || urlStr.contains('/orders') || urlStr.contains('/dashboard')) {
                      _syncTokenWithUser();
                    }
                  }
                  
                  if (_globalPendingDeepLink != null) {
                    final path = _globalPendingDeepLink!;
                    _globalPendingDeepLink = null;
                    _loadUrl(path);
                  }
                },
                onProgressChanged: (controller, progress) {
                  if (progress == 100) _pullToRefreshController?.endRefreshing();
                  setState(() => _progress = progress / 100);
                },
              ),
              if (_progress < 1.0)
                LinearProgressIndicator(value: _progress, color: const Color(0xFFC0151B), backgroundColor: Colors.white),
              if (_isOffline)
                Container(
                  color: Colors.white,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.wifi_off, size: 80, color: Color(0xFFC0151B)),
                        const SizedBox(height: 16),
                        const Text("No Internet Connection", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () => _webViewController?.reload(),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC0151B)),
                          child: const Text("Retry", style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
