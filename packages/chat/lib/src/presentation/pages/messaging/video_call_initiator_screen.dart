// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:videocall/videocall.dart';
import 'package:auth/auth.dart';
import 'package:firebase_database/firebase_database.dart';


class VideoCallInitiatorScreen extends StatefulWidget {
  final String callId;
  final String currentUserId;
  final String currentUserName;
  final String currentUserAvatar;
  final String receiverId;
  final String receiverName;
  final String receiverAvatar;

  const VideoCallInitiatorScreen({
    super.key,
    required this.callId,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserAvatar,
    required this.receiverId,
    required this.receiverName,
    required this.receiverAvatar,
  });

  @override
  State<VideoCallInitiatorScreen> createState() => _VideoCallInitiatorScreenState();
}

class _VideoCallInitiatorScreenState extends State<VideoCallInitiatorScreen> {
  late VideoCallBloc _videoCallBloc;
  late VideoCallService _videoCallService;
  Timer? _callTimeoutTimer;

  @override
  void initState() {
    super.initState();

  // Initialize services (RTDB path aligned to /calls by data source)
  final database = FirebaseDatabase.instance;
  final dataSource = VideoCallFirebaseDataSource(database);
  final repository = VideoCallRepositoryImpl(dataSource);
  final agoraService = AgoraServiceImpl();
  final authRepository = FirebaseAuthRepository();
  _videoCallService = VideoCallService(repository, agoraService, authRepository);

    // Initialize BLoC
    _videoCallBloc = VideoCallBloc(_videoCallService);

    // Navigate to CallingScreen immediately and start the call process
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: _videoCallBloc,
              child: CallingScreen(
                callerName: widget.receiverName,
                callerAvatar: widget.receiverAvatar,
                isMuted: false,
                isCameraOff: false,
                isFrontCamera: true,
                isRinging: true, // Start in ringing state
                onToggleMute: () => _videoCallBloc.add(ToggleMute()),
                onToggleCamera: () => _videoCallBloc.add(ToggleVideo()),
                onSwitchCamera: () => _videoCallBloc.add(SwitchCamera()),
                onHangUp: () {
                  if (!_videoCallBloc.isClosed) {
                    _videoCallBloc.add(LeaveVideoCall());
                  }
                },
              ),
            ),
          ),
        );
        _initiateCall();
      }
    });
  }

  Future<void> _initiateCall() async {
    try {
      // Check if Agora is properly configured
      if (!AgoraConfig.isConfigured) {
        _showErrorAndPop('Video call is not configured. Please set up Agora credentials first.');
        return;
      }

      // Check if temporary token might be expired
      if (AgoraConfig.isTempTokenExpired) {
        _showErrorAndPop('Video call token has expired. Please generate a new token.');
        return;
      }

      final hasPermissions = await _videoCallService.checkAndRequestPermissions();
      if (!hasPermissions) {
        _showErrorAndPop('Camera and microphone permissions are required.');
        return;
      }

      // Initiate call (create DB record and trigger FCM)
      final callId = await _videoCallService.initiateCall(
        callerId: widget.currentUserId,
        callerName: widget.currentUserName,
        callerAvatar: widget.currentUserAvatar,
        receiverId: widget.receiverId,
        receiverName: widget.receiverName,
        receiverAvatar: widget.receiverAvatar,
      );
      debugPrint('Call initiated with ID: $callId');

      // Set up call timeout (30 seconds)
      _callTimeoutTimer = Timer(const Duration(seconds: 30), () {
        if (mounted && !_videoCallBloc.isClosed) {
          _videoCallBloc.add(LeaveVideoCall());
          _showErrorAndPop('Call timeout - no answer');
        }
      });

      // Initialize video call
      _videoCallBloc.add(InitializeVideoCall(
        channelName: AgoraConfig.testChannelName,
        token: AgoraConfig.tempToken,
        uid: widget.currentUserId,
      ));

      // Join the call
      _videoCallBloc.add(JoinVideoCall());
    } catch (e) {
      debugPrint('Error initiating call: $e');
      _showErrorAndPop('Failed to start call: $e');
    }
  }

  void _showErrorAndPop(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _callTimeoutTimer?.cancel();
    _videoCallBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // This screen will be replaced immediately, so we can just show a loader.
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}