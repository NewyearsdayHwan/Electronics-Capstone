import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:convert';
import 'PushNotification.dart';
import 'FaceFailureHistoryPage.dart';
import 'NotificationHistoryPage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:io'; // Platform용
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';


final navigatorKey = GlobalKey<NavigatorState>();

// 반드시 main 함수 외부에 작성합니다. (= 최상위 수준 함수여야 함)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(); // 추가
  if (message.notification != null) {
    print("Notification Received!");
  }
}

Future<void> requestNotificationPermission() async {
  if (Platform.isAndroid) {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    if (androidInfo.version.sdkInt >= 33) {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        await Permission.notification.request();
      }
    }
  }
}

// 푸시 알림 메시지와 상호작용을 정의합니다.
Future<void> setupInteractedMessage() async {
  // 앱이 종료된 상태에서 열릴 때 getInitialMessage 호출
  RemoteMessage? initialMessage =
  await FirebaseMessaging.instance.getInitialMessage();

  if (initialMessage != null) {
    _handleMessage(initialMessage);
  }

  // 앱이 백그라운드 상태일 때, 푸시 알림을 탭할 때 RemoteMessage 처리
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print("앱 백그라운드 상태에서 알림 탭: ${message.messageId}");
    _handleMessage(message);
  });
}

// FCM에서 전송한 data를 처리합니다. /message 페이지로 이동하면서 해당 데이터를 화면에 보여줍니다.
void _handleMessage(RemoteMessage message) {
  print("Handling message tap. Navigating to main screen. Data: ${message.data}");
  Future.delayed(const Duration(milliseconds: 100), () {
    if (navigatorKey.currentState != null) {
      // 현재 네비게이션 스택에서 첫 번째 화면(MyHomePage)이 나올 때까지 모든 화면을 pop합니다.
      navigatorKey.currentState!.popUntil((route) => route.isFirst);
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await requestNotificationPermission(); // 알림 권한 요청
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // FCM 푸시 알림 관련 초기화
  PushNotification.init();
  // flutter_local_notifications 패키지 관련 초기화
  PushNotification.localNotiInit();

  // 백그라운드 알림 수신 리스너
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 포그라운드 알림 수신 리스너
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    String payloadData = jsonEncode(message.data);
    print('Got a message in foreground');
    if (message.notification != null) {
      // flutter_local_notifications 패키지 사용
      PushNotification.showSimpleNotification(
        title: message.notification!.title!,
        body: message.notification!.body!,
        payload: payloadData,
      );
    }
  });

  // 메시지 상호작용 함수 호출
  setupInteractedMessage();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: '스마트 금고',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(

        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      routes: {
        '/message': (context) => const Message(), // 🔁 푸시 알림 탭 시 열릴 페이지 등록
      },
      home: const MyHomePage(title: '스마트 금고'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});


  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // 예시용: 가장 최근 얼굴인식 실패 이미지와 시간
  String? latestFaceImageUrl; // 네트워크 URL 또는 base64 등 가능
  String? latestFaceFailTime;

  // 예시용: 가장 최근 푸시 알림 내용과 시간
  String? latestPushContent;
  String? latestPushTime;

  @override
  void initState() {
    super.initState();

    // 테스트용 임시 데이터 (추후 Raspberry Pi 연동 시 여기에 연결)
    FirebaseFirestore.instance
        .collection('face_failures')
        .orderBy('timestamp', descending: true) // 🔥 가장 최신 순으로 정렬
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final data = doc.data();
        final timestamp = data['timestamp'] as Timestamp?;
        setState(() {
          latestFaceImageUrl = data['imageUrl'];

          if (timestamp != null) {
            final date = timestamp.toDate();
            latestFaceFailTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(date);
          } else {
            latestFaceFailTime = '시간 없음';
          }
        });
      }else {
        setState(() {
          latestFaceImageUrl = null;
          latestFaceFailTime = null;
        });
      }
    });
    // 2. 푸시 알림 Realtime Database 구독
    FirebaseDatabase.instance
        .ref()
        .child('alerts')
        .orderByChild('timestamp')
        .limitToLast(1)
        .onChildAdded
        .listen((event) {
      final data = event.snapshot.value as Map?;
      if (data != null) {
        setState(() {
          latestPushContent = data['message'] ?? '메시지 없음';
          latestPushTime = data['timestamp']?.toString().replaceAll('T', ' ') ?? '시간 없음';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        centerTitle: true,
      ),
      body: SingleChildScrollView( // 혹시라도 내용이 넘치면 스크롤 가능
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 얼굴인식 실패 이미지 + 시간
              Text("가장 최근 얼굴인식 실패", style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Container(
                height: 200,
                width: double.infinity,
                color: Colors.grey[300],
                child: latestFaceImageUrl != null
                    ? Image.network(latestFaceImageUrl!, fit: BoxFit.cover)
                    : const Center(child: Text('이미지 없음')),
              ),
              const SizedBox(height: 8),
              Text("시간: ${latestFaceFailTime ?? '없음'}"),
              const SizedBox(height: 12),

              // 2. 얼굴인식 실패 히스토리 버튼
              ElevatedButton(
                onPressed: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => FaceFailureHistoryPage()));
                },
                child: const Text("얼굴인식 실패 히스토리"),
              ),
              const SizedBox(height: 24),

              // 3. 가장 최근 푸시 알림 내용 + 시간
              Text("가장 최근 푸시 알림", style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.deepPurple[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  latestPushContent ?? '알림 없음',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 8),
              Text("시간: ${latestPushTime ?? '없음'}"),
              const SizedBox(height: 12),

              // 4. 푸시 알림 히스토리 버튼
              ElevatedButton(
                onPressed: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => NotificationHistoryPage()));
                },
                child: const Text("푸시 알림 히스토리"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class Message extends StatefulWidget {
  const Message({super.key});

  @override
  State<Message> createState() => _MessageState();
}

class _MessageState extends State<Message> {
  @override
  Widget build(BuildContext context) {
    Map payload = {};
    final data = ModalRoute.of(context)!.settings.arguments;
    if (data is RemoteMessage) {
      payload = data.data;
    } else if (data is NotificationResponse) {
      payload = jsonDecode(data.payload!);
    } else {
      payload = {'message': '데이터를 불러올 수 없습니다.'};
    }
    return Scaffold(
      appBar: AppBar(title: Text('Push Alarm Message')),
      body: Center(child: Text(payload.toString())),
    );
  }
}

