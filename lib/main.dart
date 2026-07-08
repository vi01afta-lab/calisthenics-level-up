// Repositorio para abstracción de datos
class UserRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  Stream<DocumentSnapshot> getUserData(String uid) {
    return _db.collection('users').doc(uid).snapshots();
  }
}

// DashboardScreen refactorizado
class DashboardScreen extends StatefulWidget { ... }

class _DashboardScreenState extends State<DashboardScreen> {
  // El uso de StreamBuilder gestiona automáticamente la suscripción y limpieza
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: repository.getUserData(uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return LoadingWidget();
        return buildUI(snapshot.data);
      }
    );
  }
}