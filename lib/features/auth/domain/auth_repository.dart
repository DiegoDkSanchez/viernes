class AppUser {
  const AppUser(this.id, this.name);
  final String id;
  final String name;
}

abstract interface class AuthRepository {
  Stream<AppUser?> watchUser();
  Future<void> signIn();
  Future<void> signOut();
}

class SignInWithGoogle {
  const SignInWithGoogle(this.repository);
  final AuthRepository repository;
  Future<void> call() => repository.signIn();
}

class SignOut {
  const SignOut(this.repository);
  final AuthRepository repository;
  Future<void> call() => repository.signOut();
}
