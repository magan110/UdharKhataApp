import 'package:udhaarkhata/core/auth/account.dart';
import 'package:udhaarkhata/core/auth/auth_repository.dart';

final class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository(this.restore);
  final Future<Account?> Function() restore;

  @override
  Future<Account?> restoreSession() => restore();
}
