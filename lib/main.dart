import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:auth/auth.dart';
import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:videocall/videocall.dart';
import 'package:livestream/livestream.dart' as livestream;
import 'config/firebase_options.dart';
import 'presentation/pages/home_page.dart';

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (critical - must be sync)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Set up FCM background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize FCM Service asynchronously (non-blocking)
  FCMService.instance.initialize();

  // Initialize FCM Token Manager
  final authRepository = FirebaseAuthRepository();
  final fcmTokenManager = FCMTokenManager(authRepository);
  await fcmTokenManager.initialize();

  // Start app immediately without waiting for database warmup
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Create global VideoCallBloc instance
    final database = FirebaseDatabase.instance;
    final dataSource = VideoCallFirebaseDataSource(database);
    final repository = VideoCallRepositoryImpl(dataSource);
    final agoraService = AgoraServiceImpl();
    final authRepository = FirebaseAuthRepository();
    final videoCallService = VideoCallService(repository, agoraService, authRepository);
    final videoCallBloc = VideoCallBloc(videoCallService);

    // Subscribe to FCM notification stream and forward incoming calls to Bloc
    FCMService.instance.notificationStream.listen((data) async {
      if (data['type'] == 'incoming_call') {
        final callId = data['callId'] as String?;
        if (callId == null) return;

        // Prefer channelName/token from payload (if Cloud Functions supplied)
        var channelName = data['channelName'] as String?;
        var callerId = data['callerId'] as String?;
        var callerName = data['callerName'] as String?;
        var callerAvatar = data['callerAvatar'] as String?;

        // If channel info missing, try to fetch from Firestore then RTDB as fallback
        if (channelName == null || channelName.isEmpty) {
          try {
            final fs = FirebaseFirestore.instance;
            final doc = await fs.collection('calls').doc(callId).get();
            final data = doc.data();
            if (data != null) {
              channelName = (data['channelName'] as String?) ?? channelName;
              callerId = (data['callerId'] as String?) ?? callerId;
              callerName = (data['callerName'] as String?) ?? callerName;
              callerAvatar = (data['callerAvatar'] as String?) ?? callerAvatar;
            }
          } catch (_) {}
          if (channelName == null || channelName.isEmpty) {
            try {
              final rtdb = FirebaseDatabase.instance;
              final snap = await rtdb.ref('calls/$callId').get();
              if (snap.exists) {
                final m = Map<String, dynamic>.from(snap.value as Map);
                channelName = (m['channelName'] as String?) ?? channelName;
                callerId = (m['callerId'] as String?) ?? callerId;
                callerName = (m['callerName'] as String?) ?? callerName;
                callerAvatar = (m['callerAvatar'] as String?) ?? callerAvatar;
              }
            } catch (_) {}
          }

        }

        if (channelName != null &&
            callerId != null &&
            callerName != null &&
            callerAvatar != null) {
          VideoCallBloc.handleIncomingCall({
            'callId': callId,
            'callerId': callerId,
            'callerName': callerName,
            'callerAvatar': callerAvatar,
            'channelName': channelName,
          });
        }
      } else if (data['type'] == 'call_action') {
        final action = data['action'];
        final callId = data['callId'] as String?;
        if (callId == null) return;

        if (action == 'accept') {
          var channelName = data['channelName'] as String?;
          var callerName = data['callerName'] as String? ?? 'Unknown';
          var callerAvatar = data['callerAvatar'] as String? ?? '';

          // If channel info missing, try to fetch from Firestore then RTDB as fallback
          if (channelName == null || channelName.isEmpty) {
            try {
              final fs = FirebaseFirestore.instance;
              final doc = await fs.collection('calls').doc(callId).get();
              final data = doc.data();
              if (data != null) {
                channelName = (data['channelName'] as String?) ?? channelName;
                callerName = (data['callerName'] as String?) ?? callerName;
                callerAvatar = (data['callerAvatar'] as String?) ?? callerAvatar;
              }
            } catch (_) {}
            if (channelName == null || channelName.isEmpty) {
              try {
                final rtdb = FirebaseDatabase.instance;
                final snap = await rtdb.ref('calls/$callId').get();
                if (snap.exists) {
                  final m = Map<String, dynamic>.from(snap.value as Map);
                  channelName = (m['channelName'] as String?) ?? channelName;
                  callerName = (m['callerName'] as String?) ?? callerName;
                  callerAvatar = (m['callerAvatar'] as String?) ?? callerAvatar;
                }
              } catch (_) {}
            }
          }

          if (channelName != null) {
            videoCallBloc.add(AcceptCall(callId));
            videoCallBloc.add(MonitorCallStatus(callId));
            videoCallBloc.add(InitializeVideoCall(
              channelName: channelName,
              token: AgoraConfig.tempToken,
              uid: '',
            ));
            videoCallBloc.add(JoinVideoCall());

            navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: videoCallBloc,
                  child: CallingScreen(
                    callerName: callerName,
                    callerAvatar: callerAvatar,
                    isMuted: false,
                    isCameraOff: false,
                    isFrontCamera: true,
                    onToggleMute: () => videoCallBloc.add(ToggleMute()),
                    onToggleCamera: () => videoCallBloc.add(ToggleVideo()),
                    onSwitchCamera: () => videoCallBloc.add(SwitchCamera()),
                    onHangUp: () {
                      videoCallBloc.add(LeaveVideoCall());
                      navigatorKey.currentState?.pop();
                    },
                  ),
                ),
              ),
            );
          }
        } else if (action == 'decline') {
          videoCallBloc.add(RejectCall(callId));
        }
      }
    });

    return MultiRepositoryProvider(
      providers: [
        // Lazy initialization of repositories
        RepositoryProvider<AppDatabase>(
          create: (context) => AppDatabase(),
          lazy: false, // Initialize eagerly in background
        ),
        RepositoryProvider<FirebaseAuthRepository>(
          create: (context) => FirebaseAuthRepository(),
          lazy: true,
        ),
      ],
      child: BlocProvider<VideoCallBloc>(
        create: (context) => videoCallBloc,
        child: MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Vietravel',
          theme: AppThemes.lightTheme,
          darkTheme: AppThemes.darkTheme,
          themeMode: ThemeMode.system,
          initialRoute: '/',
          routes: {
            '/': (context) => const AuthWrapper(),
            '/home': (context) => const HomePage(),
            '/login': (context) => BlocProvider(
              create: (context) => LoginBloc(
                RepositoryProvider.of<FirebaseAuthRepository>(context),
                RepositoryProvider.of<AppDatabase>(context),
              )..add(const CheckSavedLoginEvent()),
              child: const LoginPage(),
            ),
            '/register': (context) => BlocProvider(
              create: (context) =>
                  RegisterBloc(RepositoryProvider.of<FirebaseAuthRepository>(context)),
              child: const RegisterPage(),
            ),
            '/agora_host_page': (context) => BlocProvider(
              create: (context) => livestream.AgoraHostBloc(livestream.AgoraRepositoryImpl(livestream.AgoraService())),
              child: const livestream.AgoraHostPage(),
            ),
            '/agora_viewer_page': (context) {
              final args = ModalRoute.of(context)!.settings.arguments as String?;
              return BlocProvider(
                create: (context) => livestream.AgoraViewerBloc(livestream.AgoraRepositoryImpl(livestream.AgoraService())),
                child: livestream.AgoraViewerPage(channelName: args ?? 'livestream'),
              );
            },
          },
        ),
      ),
    );
  }
}

/// Wrapper widget that checks authentication status
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late final LoginBloc _loginBloc;

  @override
  void initState() {
    super.initState();
    _loginBloc = LoginBloc(FirebaseAuthRepository(), AppDatabase())
      ..add(const CheckSavedLoginEvent());
  }

  @override
  void dispose() {
    _loginBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _loginBloc,
      child: BlocBuilder<LoginBloc, LoginState>(
        builder: (context, state) {
          if (state is LoginSuccess) {
            return const HomePage();
          } else if (state is LoginLoading) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          } else {
            return const LoginPage();
          }
        },
      ),
    );
  }
}
// import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp();

//   FirebaseMessaging messaging = FirebaseMessaging.instance;
//   String? token = await messaging.getToken();
//   print("🔥 FCM Token: $token");
// }
