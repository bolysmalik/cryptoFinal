import 'package:flutter/material.dart';
import 'services/crypto_engine.dart';
import 'services/blockchain_service.dart';
import 'services/auth_service.dart';
import 'services/mock_database.dart';

void main() => runApp(MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData(primarySwatch: Colors.indigo, useMaterial3: true),
  home: CryptoVaultApp(),
));

class CryptoVaultApp extends StatefulWidget {
  @override
  _CryptoVaultAppState createState() => _CryptoVaultAppState();
}

class _CryptoVaultAppState extends State<CryptoVaultApp> {
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  final _msgController = TextEditingController();

  final _engine = CryptoEngine();
  final _blockchain = BlockchainService();
  final _auth = AuthService();
  final _db = MockDatabase();

  bool _isLoggedIn = false;
  String? _currentUsername;
  String? _selectedRecipient; // Выбранный получатель
  String? _lastEncryptedPath;

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
          actions: _isLoggedIn ? [IconButton(icon: Icon(Icons.logout), onPressed: _handleLogout)] : null,
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

  Widget _buildLockedScreen() => Center(child: Text("Пожалуйста, войдите в систему"));

  // --- AUTH TAB ---
  Widget _buildAuthTab() {
    if (_isLoggedIn) {
      return Center(child: Text("Вы вошли как $_currentUsername", style: TextStyle(fontSize: 18)));
    }
    return Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          TextField(controller: _userController, decoration: InputDecoration(labelText: "Имя пользователя")),
          TextField(controller: _passController, decoration: InputDecoration(labelText: "Пароль"), obscureText: true),
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: ElevatedButton(onPressed: _handleRegister, child: Text("Регистрация"))),
              SizedBox(width: 10),
              Expanded(child: ElevatedButton(onPressed: _handleLogin, child: Text("Войти"))),
            ],
          ),
        ],
      ),
    );
  }

  // --- MESSAGING TAB (ОБНОВЛЕНО) ---
  Widget _buildMessagingTab() {
    // Получаем список всех пользователей для Dropdown
    List<String> otherUsers = _db.getAllUsernames(_currentUsername ?? "");

    return Column(
      children: [
        // Выбор получателя
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: DropdownButtonFormField<String>(
            decoration: InputDecoration(labelText: "Кому отправить", border: OutlineInputBorder()),
            value: _selectedRecipient,
            items: otherUsers.map((user) => DropdownMenuItem(value: user, child: Text(user))).toList(),
            onChanged: (val) => setState(() => _selectedRecipient = val),
          ),
        ),

        // Список сообщений (фильтруем только диалог с _selectedRecipient)
        Expanded(
          child: _selectedRecipient == null
              ? Center(child: Text("Выберите пользователя для начала чата"))
              : ListView(
            padding: EdgeInsets.all(12),
            children: _db.messages.where((m) {
              return (m['from'] == _currentUsername && m['to'] == _selectedRecipient) ||
                  (m['from'] == _selectedRecipient && m['to'] == _currentUsername);
            }).map((m) {
              bool isMe = m['from'] == _currentUsername;
              return _chatBubble(m['from']!, m['text']!, isMe);
            }).toList(),
          ),
        ),

        // Поле ввода
        if (_selectedRecipient != null)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(child: TextField(controller: _msgController, decoration: InputDecoration(hintText: "Зашифрованное сообщение..."))),
                IconButton(icon: Icon(Icons.send, color: Colors.indigo), onPressed: _handleSendMessage),
              ],
            ),
          )
      ],
    );
  }

  Widget _chatBubble(String sender, String text, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4),
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isMe ? Colors.indigo : Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(sender, style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : Colors.black54)),
            Text(text, style: TextStyle(color: isMe ? Colors.white : Colors.black)),
          ],
        ),
      ),
    );
  }

  // --- FILES TAB ---
  Widget _buildFileTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton.icon(
            icon: Icon(Icons.lock),
            label: Text("Зашифровать файл"),
            onPressed: () async {
              String? path = await _engine.encryptFile(_passController.text);
              if (path != null) {
                setState(() {
                  _lastEncryptedPath = path;
                  _blockchain.addEvent("FILE_SECURED by $_currentUsername");
                });
                _showSnackBar("Файл защищен!");
              }
            },
          ),
        ],
      ),
    );
  }

  // --- LEDGER TAB ---
  Widget _buildBlockchainTab() {
    final blocks = _blockchain.chain.reversed.toList();
    return ListView.builder(
      itemCount: blocks.length,
      itemBuilder: (context, i) {
        final block = blocks[i];
        return Card(
          child: ListTile(
            leading: Icon(Icons.link, color: Colors.indigo),
            title: Text(block.action),
            subtitle: Text("Hash: ${_formatHash(block.hash)}\nPrev: ${_formatHash(block.previousHash)}"),
            trailing: Icon(Icons.verified, color: Colors.green, size: 16),
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
    _showSnackBar("Ошибка входа!");
  }

  void _handleRegister() async {
    if (_userController.text.isEmpty || _passController.text.isEmpty) return;
    final salt = List<int>.generate(16, (i) => i + 5);
    final hash = await _auth.hashPassword(_passController.text, salt);
    _db.addUser(_userController.text, hash.join(), salt);
    setState(() => _blockchain.addEvent("USER_CREATED: ${_userController.text}"));
    _showSnackBar("Регистрация успешна!");
    _userController.clear();
    _passController.clear();
  }

  void _handleLogout() {
    setState(() {
      _isLoggedIn = false;
      _currentUsername = null;
      _selectedRecipient = null;
      _blockchain.addEvent("LOGOUT");
    });
  }

  void _handleSendMessage() {
    if (_msgController.text.isEmpty || _selectedRecipient == null) return;
    setState(() {
      // Сохраняем сообщение в Mock БД
      _db.addMessage(_currentUsername!, _selectedRecipient!, _msgController.text);
      // Логируем событие в блокчейн
      _blockchain.addEvent("MSG: $_currentUsername -> $_selectedRecipient");
      _msgController.clear();
    });
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}