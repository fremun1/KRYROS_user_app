import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
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
      ),
      home: const SplashScreen(url: 'https://kryros.com'),
    );
  }
}

class SplashScreen extends StatefulWidget {
  final String url;
  const SplashScreen({super.key, required this.url});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _blinkController;
  late AnimationController _bounceController;
  bool _isFadingOut = false;

  @override
  void initState() {
    super.initState();
    
    // Pulse rings animation
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    // Blink logo and text animation
    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    )..repeat(reverse: true);

    // Bouncing dots animation
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..repeat();

    // Navigation timer
    Timer(const Duration(milliseconds: 2200), () {
      if (mounted) {
        setState(() {
          _isFadingOut = true;
        });
        Timer(const Duration(milliseconds: 400), () {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => WebViewPage(url: widget.url),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
                transitionDuration: const Duration(milliseconds: 400),
              ),
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _blinkController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFF050816);
    const primaryColor = Color(0xFF27B9AF);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: AnimatedOpacity(
        opacity: _isFadingOut ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 400),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pulsing rings around logo
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
                  // Logo with blink effect
                  FadeTransition(
                    opacity: Tween<double>(begin: 1.0, end: 0.45).animate(
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
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              // Brand name with blink effect
              FadeTransition(
                opacity: Tween<double>(begin: 1.0, end: 0.45).animate(
                  CurvedAnimation(
                    parent: _blinkController,
                    curve: const Interval(0.125, 1.0, curve: Curves.easeInOut),
                  ),
                ),
                child: const Text(
                  'KRYROS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.6, // 0.12em
                    fontFamily: 'sans-serif',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Bouncing loading dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  return AnimatedBuilder(
                    animation: _bounceController,
                    builder: (context, child) {
                      final delay = index * 0.18;
                      double progress = (_bounceController.value - delay);
                      if (progress < 0) progress += 1.0;

                      final yOffset = progress < 0.5
                          ? -8.0 * (progress / 0.5)
                          : -8.0 * (1.0 - (progress - 0.5) / 0.5);
                      
                      final opacity = progress < 0.5
                          ? 0.35 + (0.65 * (progress / 0.5))
                          : 1.0 - (0.65 * ((progress - 0.5) / 0.5));

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3.5),
                        child: Transform.translate(
                          offset: Offset(0, yOffset),
                          child: Opacity(
                            opacity: opacity.clamp(0.35, 1.0),
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: primaryColor,
                                shape: BoxShape.circle,
                              ),
                            ),
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
  const WebViewPage({super.key, required this.url});

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> with SingleTickerProviderStateMixin {
  late final WebViewController _controller;
  bool _isLoading = true;
  late AnimationController _loadingController;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  String? _fcmToken;

  @override
  void initState() {
    super.initState();
    _setupNotifications();
    _loadingController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
        ),
      )
      ..addJavaScriptChannel(
        'MobileBridge',
        onMessageReceived: (JavaScriptMessage message) {
          if (message.message == 'user_logged_in') {
            _registerTokenWithSession();
          }
        },
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _setupNotifications() async {
    // Request permissions
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Get token for backend registration
    _fcmToken = await messaging.getToken();
    debugPrint("FCM Token: $_fcmToken");

    // Initial public registration (guest)
    if (_fcmToken != null) {
      _registerPublicToken();
    }

    // Local notifications setup
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('launcher_icon');
    const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Listen for messages while app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
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
        );
      }
    });
  }

  Future<void> _registerPublicToken() async {
    if (_fcmToken == null) return;
    debugPrint("Registering Public FCM token: $_fcmToken");
    
    final String jsCode = """
      (function() {
        fetch('/api/notifications/token/public', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ token: '$_fcmToken', platform: 'android' })
        })
        .then(response => console.log('Public Token registered:', response.status))
        .catch(error => console.error('Public Token registration failed:', error));
      })();
    """;
    
    await _controller.runJavaScript(jsCode);
  }

  Future<void> _registerTokenWithSession() async {
    if (_fcmToken == null) return;
    
    debugPrint("Registering FCM token via JS Bridge: $_fcmToken");
    
    final String jsCode = """
      (function() {
        fetch('/api/notifications/token', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ token: '$_fcmToken', platform: 'android' })
        })
        .then(response => console.log('Token registered:', response.status))
        .catch(error => console.error('Token registration failed:', error));
      })();
    """;
    
    await _controller.runJavaScript(jsCode);
  }

  @override
  void dispose() {
    _loadingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading)
              Container(
                color: const Color(0xFF050816).withOpacity(0.7),
                child: Center(
                  child: AnimatedBuilder(
                    animation: _loadingController,
                    builder: (context, child) {
                      return Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF27B9AF).withOpacity(
                              0.3 + (0.7 * _loadingController.value),
                            ),
                            width: 4,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: ClipOval(child: Image.asset('assets/logo_circular.png')),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
