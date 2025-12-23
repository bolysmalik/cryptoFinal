import '../models/block.dart';

class MockDatabase {
  // Singleton паттерн: один экземпляр на всё приложение
  static final MockDatabase _instance = MockDatabase._internal();
  factory MockDatabase() => _instance;
  MockDatabase._internal();

  // Хранилище данных
  final List<Map<String, dynamic>> users = []; // {username, passwordHash, salt}
  final List<Block> blockchain = [];
  final List<Map<String, String>> messages = []; // {from, to, content}

  // Методы для работы с пользователями
  void addUser(String username, String hash, List<int> salt) {
    users.add({
      'username': username,
      'passwordHash': hash,
      'salt': salt,
    });
  }

  Map<String, dynamic>? findUser(String username) {
    try {
      return users.firstWhere((u) => u['username'] == username);
    } catch (e) {
      return null;
    }
  }
}