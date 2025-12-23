import 'package:cryptography/cryptography.dart';

class AuthService {
  static const iterations = 100000;

  Future<List<int>> hashPassword(String password, List<int> salt) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );
    final secretKey = SecretKey(password.codeUnits);
    final newKey = await pbkdf2.deriveKey(secretKey: secretKey, nonce: salt);
    return await newKey.extractBytes();
  }
}