import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:crypto/crypto.dart';
import 'dart:convert';

class CryptoEngine {
  Future<String?> encryptFile(File sourceFile, String password) async {
    try {
      // 1. Готовим ключ из пароля (хешируем пароль до 32 байт)
      final keyBytes = sha256.convert(utf8.encode(password)).bytes;
      final key = enc.Key(Uint8List.fromList(keyBytes));

      // 2. Генерируем случайный IV (Initialization Vector)
      // Это нужно, чтобы два одинаковых файла выглядели по-разному после шифрования
      final iv = enc.IV.fromSecureRandom(16);

      // 3. Настраиваем AES (используем режим CBC или GCM)
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

      // 4. Читаем файл и шифруем
      final fileBytes = await sourceFile.readAsBytes();
      final encrypted = encrypter.encryptBytes(fileBytes, iv: iv);

      // 5. Склеиваем IV + Шифрованные данные
      // Нам нужно сохранить IV вместе с файлом, чтобы потом расшифровать его
      final combinedData = Uint8List.fromList(iv.bytes + encrypted.bytes);

      // 6. Сохраняем результат
      final directory = await getApplicationDocumentsDirectory();
      String originalName = sourceFile.path.split('/').last;
      final String fileName = "vault_$originalName.enc";
      final File encryptedFile = File('${directory.path}/$fileName');

      await encryptedFile.writeAsBytes(combinedData);
      return encryptedFile.path;
    } catch (e) {
      print("Ошибка реального шифрования: $e");
      return null;
    }
  }

  // Бонус: Метод для расшифровки
  Future<Uint8List?> decryptFile(File encryptedFile, String password) async {
    try {
      final keyBytes = sha256.convert(utf8.encode(password)).bytes;
      final key = enc.Key(Uint8List.fromList(keyBytes));

      final allBytes = await encryptedFile.readAsBytes();

      // Вырезаем IV (первые 16 байт) и само сообщение (все остальное)
      final iv = enc.IV(allBytes.sublist(0, 16));
      final cipherText = allBytes.sublist(16);

      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final decrypted = encrypter.decryptBytes(enc.Encrypted(cipherText), iv: iv);

      return Uint8List.fromList(decrypted);
    } catch (e) {
      print("Ошибка расшифровки: $e");
      return null;
    }
  }
}