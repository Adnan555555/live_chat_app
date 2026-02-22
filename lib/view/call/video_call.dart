// lib/screens/chat/video_call_screen.dart
import 'package:flutter/material.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import '../../model/user_model.dart';
import '../../service/call_sevices.dart';

class VideoCallScreen extends StatelessWidget {
  final UserModel otherUser;

  const VideoCallScreen({super.key, required this.otherUser});

  @override
  Widget build(BuildContext context) {
    final callId = CallService.getCallId(
      CallService.currentUserId,
      otherUser.uid,
      isVideo: true,
    );

    return ZegoUIKitPrebuiltCall(
      appID: CallService.appID,
      appSign: CallService.appSign,
      callID: callId,
      userID: CallService.currentUserId,
      userName: CallService.currentUserName,
      config: ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall(),
      events: ZegoUIKitPrebuiltCallEvents(
        onCallEnd: (ZegoCallEndEvent event, VoidCallback defaultAction) {
          // ✅ Navigate back when call ends for any reason
          defaultAction.call();
        },
      ),
    );
  }
}