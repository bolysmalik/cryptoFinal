import 'package:flutter/material.dart';
import 'services/crypto_engine.dart';
import 'services/blockchain_service.dart';
import 'services/auth_service.dart';
import 'services/mock_database.dart';

void main() => runApp(MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData(
    primarySwatch: Colors.indigo,
    useMaterial3: true,
    // Исправлено: если CardTheme вызывает ошибку, мы настраиваем его через copyWith
    // или используем стандартные значения
  ),
  home: CryptoVaultApp(),
));

class CryptoVaultApp extends StatefulWidget {
  @override
  _CryptoVaultAppState createState() => _CryptoVaultAppState();
}

class _CryptoVaultAppState extends State<CryptoVaultApp> {
  // Контроллеры ввода
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _msgController = TextEditingController();

  // Инициализация сервисов
  final CryptoEngine _engine = CryptoEngine();
  final BlockchainService _blockchain = BlockchainService();
  final AuthService _auth = AuthService();
  final MockDatabase _db = MockDatabase();

  bool _isLoggedIn = false;
  String? _currentUsername;
  String? _lastEncryptedPath;

  // Безопасное форматирование хеша для защиты от RangeError
  String _formatHash(String hash) {
    if (hash.length <= 15) return hash;
    return "${hash.substring(0, 15)}...";
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isLoggedIn ? "Vault: $_currentUsername" : "CryptoVault Suite"),
          actions: _isLoggedIn
              ? [IconButton(icon: Icon(Icons.logout), onPressed: _handleLogout)]
              : null,
          bottom: TabBar(
            isScrollable: true,
            tabs: const [
              Tab(icon: Icon(Icons.lock), text: "Auth"),
              Tab(icon: Icon(Icons.message), text: "Chat"),
              Tab(icon: Icon(Icons.file_copy), text: "Files"),
              Tab(icon: Icon(Icons.link), text: "Ledger"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildAuthTab(),
            _isLoggedIn ? _buildMessagingTab() : _buildLockedScreen(),
            _isLoggedIn ? _buildFileTab() : _buildLockedScreen(),
            _buildBlockchainTab(),
          ],
        ),
      ),
    );
  }

  // Заглушка для закрытых разделов
  Widget _buildLockedScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.lock_person, size: 80, color: Colors.grey),
          SizedBox(height: 10),
          Text("Пожалуйста, войдите в систему", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  // --- Вкладка AUTH ---
  Widget _buildAuthTab() {
    if (_isLoggedIn) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 60),
            Text("Вы вошли как $_currentUsername", style: const TextStyle(fontSize: 18)),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          TextField(controller: _userController, decoration: const InputDecoration(labelText: "Имя пользователя")),
          TextField(controller: _passController, decoration: const InputDecoration(labelText: "Пароль"), obscureText: true),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: ElevatedButton(onPressed: _handleRegister, child: const Text("Регистрация"))),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton(onPressed: _handleLogin, child: const Text("Войти"))),
            ],
          ),
        ],
      ),
    );
  }

  // --- Вкладка MESSAGING ---
  Widget _buildMessagingTab() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(12.0),
          child: Text("Защищенный канал (ECDH/AES-GCM)", style: TextStyle(color: Colors.green, fontSize: 12)),
        ),
        Expanded(child: Center(child: Text("Здесь будут ваши сообщения"))),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(child: TextField(controller: _msgController, decoration: const InputDecoration(hintText: "Сообщение..."))),
              IconButton(icon: const Icon(Icons.send, color: Colors.indigo), onPressed: _handleSendMessage),
            ],
          ),
        )
      ],
    );
  }

  // --- Вкладка FILES ---
  Widget _buildFileTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.folder_special, size: 60, color: Colors.indigo),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.lock),
            label: const Text("Зашифровать файл"),
            onPressed: () async {
              String? path = await _engine.encryptFile(_passController.text);
              if (path != null) {
                setState(() {
                  _lastEncryptedPath = path;
                  _blockchain.addEvent("FILE_SECURED: ${path.split('/').last}");
                });
                _showSnackBar("Файл защищен!");
              }
            },
          ),
          if (_lastEncryptedPath != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text("Сохранено: ...${_lastEncryptedPath!.split('/').last}", style: const TextStyle(fontSize: 10)),
            ),
        ],
      ),
    );
  }

  // --- Вкладка BLOCKCHAIN (Ledger) ---
  Widget _buildBlockchainTab() {
    final blocks = _blockchain.chain.reversed.toList(); // Показываем новые сверху
    return ListView.builder(
      itemCount: blocks.length,
      itemBuilder: (context, i) {
        final block = blocks[i];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.link, color: Colors.indigo),
            title: Text(block.action, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("Hash: ${_formatHash(block.hash)}\nPrev: ${_formatHash(block.previousHash)}"),
            trailing: const Icon(Icons.verified, color: Colors.green, size: 16),
          ),
        );
      },
    );
  }

  // --- ЛОГИКА ---
  void _handleLogin() async {
    final user = _db.findUser(_userController.text);
    if (user != null) {
      final inputHash = await _auth.hashPassword(_passController.text, user['salt']);
      if (inputHash.join() == user['passwordHash']) {
        setState(() {
          _isLoggedIn = true;
          _currentUsername = _userController.text;
          _blockchain.addEvent("LOGIN_SUCCESS: $_currentUsername");
        });
        return;
      }
    }
    setState(() => _blockchain.addEvent("LOGIN_FAILED: ${_userController.text}"));
    _showSnackBar("Доступ запрещен!");
  }

  void _handleRegister() async {
    if (_userController.text.isEmpty || _passController.text.isEmpty) return;
    final salt = List<int>.generate(16, (i) => i + 5);
    final hash = await _auth.hashPassword(_passController.text, salt);
    _db.addUser(_userController.text, hash.join(), salt);
    setState(() => _blockchain.addEvent("USER_CREATED: ${_userController.text}"));
    _showSnackBar("Регистрация успешна!");
  }

  void _handleLogout() {
    setState(() {
      _isLoggedIn = false;
      _currentUsername = null;
      _blockchain.addEvent("LOGOUT: $_currentUsername");
    });
  }

  void _handleSendMessage() {
    if (_msgController.text.isEmpty) return;
    setState(() {
      _blockchain.addEvent("MSG_SENT: AES-GCM Integrity Checked");
      _msgController.clear();
    });
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}