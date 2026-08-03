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
        primaryColor: const Color(0xFFC0151B),
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
  bool _isTransitioning = false;

  @override
  void initState() {
    super.initState();
    // Auto-hide splash after 15 seconds even if WebView doesn't report ready
    Future.delayed(const Duration(seconds: 15), () {
      if (mounted && _showSplash) {
        _onWebViewReady();
      }
    });
  }
  
  void _onWebViewReady() {
    if (mounted && _showSplash && !_isTransitioning) {
      debugPrint("WebView ready, starting splash transition");
      setState(() {
        _isTransitioning = true;
      });
      // Delay to ensure the website content is rendered behind the splash
      Future.delayed(const Duration(milliseconds: 2000), () {
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
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: WebViewPage(
                url: widget.url,
                onPageFinished: _onWebViewReady,
              ),
            ),
            if (_showSplash)
              SplashScreen(
                isTransitioning: _isTransitioning,
              ),
          ],
        ),
      ),
    );
  }
}

class SplashScreen extends StatelessWidget {
  final bool isTransitioning;
  const SplashScreen({super.key, this.isTransitioning = false});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isTransitioning ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 1000),
      child: Container(
        color: Colors.white,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A237E)),
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
  bool _initialPageLoaded = false;
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

    const AndroidNotificationChannel userChannel = AndroidNotificationChannel(
      'kryros_notifications',
      'KRYROS Notifications',
      description: 'Notifications for KRYROS',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
    );
    await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(userChannel);

    FirebaseMessaging.onMessage.listen((message) async {
      final RemoteNotification? notification = message.notification;
      if (notification != null) {
        final String? imageUrl = message.data['imageUrl'] ?? message.data['image'] ?? notification.android?.imageUrl;
        final String? payload = message.data['url'] ?? message.data['link'] ??
            (message.data['click_action'] != 'FLUTTER_NOTIFICATION_CLICK' ? message.data['click_action'] : null) ??
            message.data['url'];
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

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final String? url = message.data['url'] ?? message.data['link'] ?? message.data['click_action'];
      if (url != null && url.isNotEmpty && url != 'FLUTTER_NOTIFICATION_CLICK') {
        debugPrint("Notification tapped (background): $url");
        _navigateToUrl(url);
      }
    });
  }

  Future<void> _registerNativeToken(String token) async {
    try {
      await http.post(
        Uri.parse(_notificationTokenEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': token, 'platform': Platform.isAndroid ? 'android' : 'ios'}),
      );
    } catch (e) {
      debugPrint("Token registration failed: $e");
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

  void _navigateToUrl(String url) {
    if (_isWebViewReady && _webViewController != null) {
      _webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
    } else {
      _globalPendingDeepLink = url;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: InAppWebView(
            initialUrlRequest: URLRequest(
              url: WebUri(widget.url),
              headers: {'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8'},
            ),
            initialSettings: InAppWebViewSettings(
              useShouldOverrideUrlLoading: true,
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
              useHybridComposition: true,
              allowsBackForwardNavigationGestures: true,
              javaScriptEnabled: true,
              domStorageEnabled: true,
              databaseEnabled: true,
              supportZoom: true,
              useWideViewPort: true,
              loadWithOverviewMode: true,
              userAgent: "Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Mobile Safari/537.36 KRYROS_USER_APP",
              mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
              safeBrowsingEnabled: false,
              allowFileAccessFromFileURLs: true,
              allowUniversalAccessFromFileURLs: true,
              thirdPartyCookiesEnabled: true,
            ),
            pullToRefreshController: _pullToRefreshController,
            onWebViewCreated: (controller) => _webViewController = controller,
            shouldOverrideUrlLoading: (controller, navigationAction) async {
              final uri = navigationAction.request.url;
              if (uri != null && !["http", "https", "file", "chrome", "data", "javascript", "about"].contains(uri.scheme)) {
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                  return NavigationActionPolicy.CANCEL;
                }
              }
              return NavigationActionPolicy.ALLOW;
            },
            onLoadStart: (controller, url) {
              setState(() => _isWebViewReady = false);
            },
            onLoadStop: (controller, url) async {
              _pullToRefreshController?.endRefreshing();
              if (!_initialPageLoaded) {
                _initialPageLoaded = true;
                _isWebViewReady = true;
                widget.onPageFinished();
                if (_globalPendingDeepLink != null) {
                  final urlToLoad = _globalPendingDeepLink!;
                  _globalPendingDeepLink = null;
                  controller.loadUrl(urlRequest: URLRequest(url: WebUri(urlToLoad)));
                }
              }
            },
          onReceivedError: (controller, request, error) {
            debugPrint("WebView Error: ${error.description}");
            _pullToRefreshController?.endRefreshing();
          },
          onReceivedHttpError: (controller, request, errorResponse) {
            debugPrint("HTTP Error: ${errorResponse.statusCode}");
          },
          onConsoleMessage: (controller, consoleMessage) {
            debugPrint("Console: ${consoleMessage.message}");
          },
          onProgressChanged: (controller, progress) {
            if (progress == 100) _pullToRefreshController?.endRefreshing();
            setState(() => _progress = progress / 100);
          },
        ),
        if (_progress < 1.0 && !_initialPageLoaded)
          LinearProgressIndicator(value: _progress, color: const Color(0xFFC0151B), backgroundColor: Colors.white),
        if (_isOffline)
          Container(
            color: Colors.white,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi_off, size: 64, color: Color(0xFFC0151B)),
                  const SizedBox(height: 16),
                  const Text('No Internet Connection', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => _webViewController?.reload(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
