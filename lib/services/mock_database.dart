class MockDatabase {
  static final MockDatabase _instance = MockDatabase._internal();
  factory MockDatabase() => _instance;
  MockDatabase._internal();

  final List<Map<String, dynamic>> users = [];
  // Новое: список сообщений {from, to, text, timestamp}
  final List<Map<String, String>> messages = [];

  void addUser(String username, String hash, List<int> salt) {
    users.add({'username': username, 'passwordHash': hash, 'salt': salt});
  }

  Map<String, dynamic>? findUser(String username) {
    try {
      return users.firstWhere((u) => u['username'] == username);
    } catch (e) {
      return null;
    }
  }

  // Получить список всех пользователей (кроме текущего, чтобы не писать самому себе)
  List<String> getAllUsernames(String exceptMe) {
    return users
        .map((u) => u['username'] as String)
        .where((name) => name != exceptMe)
        .toList();
  }

  // Сохранить сообщение
  void addMessage(String from, String to, String text) {
    messages.add({
      'from': from,
      'to': to,
      'text': text,
      'time': DateTime.now().toString().substring(11, 16)
    });
  }
}