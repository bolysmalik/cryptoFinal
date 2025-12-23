import 'dart:io';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:file_picker/file_picker.dart';

class CryptoEngine {
  final algorithm = AesGcm.with256bits();

  Future<SecretKey> _deriveKey(String password) async {
    final pbkdf2 = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 100000, bits: 256);
    return await pbkdf2.deriveKey(
        secretKey: SecretKey(password.codeUnits),
        nonce: [1, 2, 3, 4, 5, 6, 7, 8] // В продакшене соль должна быть уникальной
    );
  }

  Future<String?> encryptFile(String password) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result == null) return null;

    File file = File(result.files.single.path!);
    final key = await _deriveKey(password);
    final box = await algorithm.encrypt(await file.readAsBytes(), secretKey: key);

    final encryptedFile = File("${file.path}.enc");
    await encryptedFile.writeAsBytes(box.concatenation());
    return encryptedFile.path;
  }
}