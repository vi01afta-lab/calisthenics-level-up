Future<void> syncPendingSessions(List<Map<String, dynamic>> pending) async {
  final firestore = FirebaseFirestore.instance;
  const int chunkSize = 100; // Reducido para seguridad en Free Tier
  
  for (var i = 0; i < pending.length; i += chunkSize) {
    var chunk = pending.sublist(i, min(i + chunkSize, pending.length));
    WriteBatch batch = firestore.batch();
    
    for (var session in chunk) {
      DocumentReference ref = firestore.collection('history_${DateTime.now().year}').doc();
      batch.set(ref, session);
    }
    await batch.commit();
    await Future.delayed(const Duration(milliseconds: 500)); // Throttling
  }
}