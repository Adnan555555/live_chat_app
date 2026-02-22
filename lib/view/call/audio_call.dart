// lib/screens/chat/voice_call_screen.dart
import 'package:flutter/material.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import '../../model/user_model.dart';
import '../../service/call_sevices.dart';

class VoiceCallScreen extends StatelessWidget {
  final UserModel otherUser;

  const VoiceCallScreen({super.key, required this.otherUser});

  @override
  Widget build(BuildContext context) {
    final callId = CallService.getCallId(
      CallService.currentUserId,
      otherUser.uid,
      isVideo: false,
    );

    return ZegoUIKitPrebuiltCall(
      appID: CallService.appID,
      appSign: CallService.appSign,
      callID: callId,
      userID: CallService.currentUserId,
      userName: CallService.currentUserName,
      config: ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall(),
      events: ZegoUIKitPrebuiltCallEvents(
        onCallEnd: (ZegoCallEndEvent event, VoidCallback defaultAction) {
          // ✅ Navigate back when call ends for any reason
          defaultAction.call();
        },
      ),
    );
  }
}