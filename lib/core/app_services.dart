import '../features/auth/domain/auth_repository.dart';
import '../features/catalog/domain/catalog.dart';
import '../features/orders/domain/orders.dart';

class AppServices {
  AppServices({
    required this.auth,
    required this.orders,
    required this.catalog,
  });
  final AuthRepository auth;
  final OrderRepository orders;
  final CatalogRepository catalog;
  SignInWithGoogle get signIn => SignInWithGoogle(auth);
  SignOut get signOut => SignOut(auth);
  WatchOrders get watchOrders => WatchOrders(orders);
  UpdateOrder get updateOrder => UpdateOrder(orders);
  DeleteOrder get deleteOrder => DeleteOrder(orders);
  CreateOrder get createOrder => CreateOrder(orders);
  MarkOrderDelivered get deliver => MarkOrderDelivered(orders);
  ReopenOrder get reopen => ReopenOrder(orders);
  WatchMenu get watchMenu => WatchMenu(catalog);
  SaveMenuItem get saveMenu => SaveMenuItem(catalog);
}
