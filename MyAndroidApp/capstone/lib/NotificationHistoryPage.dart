import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class NotificationHistoryPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final alertsRef = FirebaseDatabase.instance.ref().child('alerts');

    return Scaffold(
      appBar: AppBar(title: Text("알림 히스토리")),
      body: StreamBuilder(
        stream: alertsRef.orderByChild('timestamp').onValue,
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
            final data = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
            final sortedEntries = data.entries.toList()
              ..sort((a, b) => b.value['timestamp'].compareTo(a.value['timestamp'])); // 최신순

            return ListView(
              children: sortedEntries.map((entry) {
                final alert = Map<String, dynamic>.from(entry.value);
                return ListTile(
                  title: Text(alert['message'] ?? '메시지 없음'),
                  subtitle: Text(alert['timestamp']?.toString().replaceAll('T', ' ') ?? '시간 없음'),
                );
              }).toList(),
            );
          } else if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else {
            return Center(child: Text("알림 없음"));
          }
        },
      ),
    );
  }
}