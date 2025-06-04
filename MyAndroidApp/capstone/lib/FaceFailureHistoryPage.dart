import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // 날짜 포맷용

class FaceFailureHistoryPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("얼굴인식 실패 히스토리")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('face_failures') // Firestore의 컬렉션 이름
            .orderBy('timestamp', descending: true) // 최신순 정렬
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text("실패 기록이 없습니다."));
          }

          final faceFailures = snapshot.data!.docs;

          return ListView.builder(
            itemCount: faceFailures.length,
            itemBuilder: (context, index) {
              final data = faceFailures[index].data() as Map<String, dynamic>;
              final imageUrl = data['imageUrl'] as String?;
              final timestamp = data['timestamp'] as Timestamp?;

              // Timestamp를 DateTime으로 변환 후, 포맷
              final formattedTime = timestamp != null
                  ? DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp.toDate())
                  : '시간 없음';

              return Card(
                margin: EdgeInsets.all(8),
                child: ListTile(
                  leading: imageUrl != null
                      ? Image.network(imageUrl, width: 60, height: 60, fit: BoxFit.cover)
                      : Icon(Icons.image_not_supported, size: 60),
                  title: Text("실패 시간: $formattedTime"),
                ),
              );
            },
          );
        },
      ),
    );
  }
}