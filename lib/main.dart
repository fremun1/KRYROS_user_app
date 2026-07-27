import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
  }
  
  // Request notification permissions for Android 13+
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
      setState(() {
        _isWebViewReady = true;
      });
      // Delay slightly to ensure smooth transition
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
      body: Stack(
        children: [
          WebViewPage(
            url: widget.url,
            onPageFinished: _onWebViewReady,
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
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
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
        duration: const Duration(milliseconds: 600),
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
                        final opacity = progress < 0.6 
                            ? (0.9 - (progress / 0.6 * 0.55))
                            : (0.35 - ((progress - 0.6) / 0.4 * 0.35));
                        return Transform.scale(
                          scale: scale,
                          child: Opacity(
                            opacity: opacity.clamp(0.0, 1.0),
                            child: Container(
                              width: 54.0 + (index + 1) * 26.0,
                              height: 54.0 + (index + 1) * 26.0,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: primaryColor.withOpacity(0.5 - (index + 1) * 0.12),
                                  width: index == 0 ? 2.0 : 1.5,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }),
                  FadeTransition(
                    opacity: Tween<double>(begin: 1.0, end: 0.4).animate(
                      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: primaryColor.withOpacity(0.8),
                          width: 2.0,
                        ),
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/logo_circular.png',
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.circle, color: primaryColor, size: 70);
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              FadeTransition(
                opacity: Tween<double>(begin: 1.0, end: 0.5).animate(
                  CurvedAnimation(
                    parent: _blinkController,
                    curve: const Interval(0.2, 1.0, curve: Curves.easeInOut),
                  ),
                ),
                child: const Text(
                  'KRYROS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4.0,
                  ),
                ),
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
                      return Transform.translate(
                        offset: Offset(0, offset),
                        child: Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: const BoxDecoration(
                            color: primaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
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
  String? _fcmToken;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;

  static const _notificationTokenEndpoint =
      'https://api.kryros.com/api/notifications/token/public';

  @override
  void initState() {
    super.initState();
    _setupNotifications();
    _checkConnectivity();
    _pullToRefreshController = PullToRefreshController(
      settings: PullToRefreshSettings(
        color: const Color(0xFF27B9AF),
        backgroundColor: const Color(0xFF050816),
      ),
      onRefresh: () async {
        if (Platform.isAndroid) {
          _webViewController?.reload();
        } else if (Platform.isIOS) {
          _webViewController?.loadUrl(urlRequest: URLRequest(url: await _webViewController?.getUrl()));
        }
      },
    );

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      setState(() {
        _isOffline = results.contains(ConnectivityResult.none);
      });
      if (!_isOffline) {
        _webViewController?.reload();
      }
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
    setState(() {
      _isOffline = results.contains(ConnectivityResult.none);
    });
  }

  Future<void> _setupNotifications() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    _fcmToken = await messaging.getToken();
    if (_fcmToken != null) {
      await _registerNativeToken(_fcmToken!);
    }
    _tokenRefreshSubscription = messaging.onTokenRefresh.listen((token) async {
      _fcmToken = token;
      await _registerNativeToken(token);
      await _registerTokens();
    });

    // Handle Initial Message (When app is closed)
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null && initialMessage.data['url'] != null) {
      _loadUrl(initialMessage.data['url']);
    }

    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('launcher_icon');
    const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          _loadUrl(response.payload!);
        }
      },
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      if (notification != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'kryros_notifications',
              'KRYROS Notifications',
              importance: Importance.max,
              priority: Priority.high,
              icon: 'launcher_icon',
            ),
          ),
          payload: message.data['url'],
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (message.data['url'] != null) {
        _loadUrl(message.data['url']);
      }
    });
  }

  Future<void> _registerNativeToken(String token) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse(_notificationTokenEndpoint));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({
        'token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
      }));
      final response = await request.close();
      await response.drain();
    } catch (_) {
      // A transient network failure is retried on token refresh and page load.
    } finally {
      client.close(force: true);
    }
  }

  void _loadUrl(String url) {
    final target = Uri.tryParse(url)?.hasScheme == true
        ? url
        : Uri.parse(widget.url).resolve(url).toString();
    _webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(target)));
  }

  Future<void> _registerTokens() async {
    final token = _fcmToken;
    if (token == null || _webViewController == null) return;
    await _registerNativeToken(token);
    final encodedToken = jsonEncode(token);
    await _webViewController?.evaluateJavascript(source: '''
      window.kryrosNativeFcmToken = $encodedToken;
      window.dispatchEvent(new CustomEvent('kryros:native-fcm-token', { detail: $encodedToken }));
    ''');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050816),
      body: SafeArea(
        child: Column(
          children: [
            if (_progress < 1.0 && !_isOffline)
              LinearProgressIndicator(
                value: _progress,
                color: const Color(0xFF27B9AF),
                backgroundColor: Colors.transparent,
                minHeight: 2,
              ),
            Expanded(
              child: Stack(
                children: [
                  PopScope(
                    canPop: false,
                    onPopInvoked: (didPop) async {
                      if (didPop) return;
                      if (await _webViewController?.canGoBack() ?? false) {
                        _webViewController?.goBack();
                      }
                    },
                    child: InAppWebView(
                      initialUrlRequest: URLRequest(url: WebUri(widget.url)),
                      initialSettings: InAppWebViewSettings(
                        javaScriptEnabled: true,
                        useShouldOverrideUrlLoading: true,
                        useOnDownloadStart: true,
                        allowFileAccessFromFileURLs: true,
                        allowUniversalAccessFromFileURLs: true,
                        verticalScrollBarEnabled: false,
                        horizontalScrollBarEnabled: false,
                        transparentBackground: true,
                        domStorageEnabled: true,
                        databaseEnabled: true,
                        mediaPlaybackRequiresUserGesture: false,
                        javaScriptCanOpenWindowsAutomatically: true,
                        cacheEnabled: true,
                        clearCache: false,
                        supportZoom: false,
                        preferredContentMode: UserPreferredContentMode.MOBILE,
                        // Signals the frontend that we are the KryrosApp to trigger custom logic
                        userAgent: "Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Mobile Safari/537.36 KryrosApp/1.0.5",
                        mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                        allowContentAccess: true,
                        builtInZoomControls: false,
                        displayZoomControls: false,
                        // Aggressive cache management to prevent blank screens on updates
                        cacheMode: CacheMode.LOAD_DEFAULT,
                      ),
                      pullToRefreshController: _pullToRefreshController,
                      onWebViewCreated: (controller) {
                        _webViewController = controller;
                        controller.addJavaScriptHandler(
                          handlerName: 'MobileBridge',
                          callback: (args) {
                            if (args.isNotEmpty && args[0] == 'user_logged_in') {
                              _registerTokens();
                            }
                          },
                        );
                      },
                      onLoadStop: (controller, url) async {
                        _pullToRefreshController?.endRefreshing();
                        setState(() {
                          _progress = 1.0;
                        });
                        widget.onPageFinished();
                        _registerTokens();
                        
                        // Detect and fix common blank screen issues after load
                        await controller.evaluateJavascript(source: """
                          if (document.getElementById('root') && document.getElementById('root').innerHTML === '') {
                            console.log('Root is empty, forcing refresh...');
                            localStorage.clear();
                            window.location.reload(true);
                          }
                        """);
                      },
                      onReceivedError: (controller, request, error) {
                        debugPrint("WebView Error: ${error.description}");
                        _pullToRefreshController?.endRefreshing();
                      },
                      onProgressChanged: (controller, progress) {
                        if (progress == 100) {
                          _pullToRefreshController?.endRefreshing();
                        }
                        setState(() {
                          _progress = progress / 100;
                        });
                      },
                      shouldOverrideUrlLoading: (controller, navigationAction) async {
                        var uri = navigationAction.request.url;
                        if (uri != null && !["http", "https", "file", "chrome", "data", "javascript", "about"].contains(uri.scheme)) {
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                            return NavigationActionPolicy.CANCEL;
                          }
                        }
                        return NavigationActionPolicy.ALLOW;
                      },
                    ),
                  ),
                  if (_isOffline)
                    Container(
                      color: const Color(0xFF050816),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.wifi_off, color: Colors.white, size: 64),
                            const SizedBox(height: 16),
                            const Text(
                              'No Internet Connection',
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Please check your network settings.',
                              style: TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: () => _webViewController?.reload(),
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF27B9AF)),
                              child: const Text('Retry', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
