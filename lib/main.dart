import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'app.dart';
import 'core/app_services.dart';
import 'features/auth/data/firebase_auth_repository.dart';
import 'features/orders/data/firestore_order_repository.dart';
import 'features/catalog/data/firestore_catalog_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // Native Firebase configuration comes from google-services.json / GoogleService-Info.plist.
    await Firebase.initializeApp();
    runApp(
      OrdersApp(
        services: AppServices(
          auth: FirebaseAuthRepository(FirebaseAuth.instance),
          orders: FirestoreOrderRepository(FirebaseFirestore.instance),
          catalog: FirestoreCatalogRepository(FirebaseFirestore.instance),
        ),
      ),
    );
  } catch (error) {
    debugPrint('Firebase initialization failed: $error');
    runApp(const OrdersApp());
  }
}
