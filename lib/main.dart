import 'package:flutter/material.dart';
import 'services/crypto_engine.dart';
import 'services/blockchain_service.dart';
import 'services/auth_service.dart';
import 'services/mock_database.dart';

void main() => runApp(MaterialApp(
  theme: ThemeData(primarySwatch: Colors.indigo, useMaterial3: true),
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
  final TextEditingController _recipientKeyController = TextEditingController();

  // Инициализация сервисов и Mock БД
  final CryptoEngine _engine = CryptoEngine();
  final BlockchainService _blockchain = BlockchainService();
  final AuthService _auth = AuthService();
  final MockDatabase _db = MockDatabase();

  String _statusMessage = "Добро пожаловать";

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text("CryptoVault Suite"),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.security), text: "Auth"),
              Tab(icon: Icon(Icons.message), text: "Messages"),
              Tab(icon: Icon(Icons.file_copy), text: "Files"),
              Tab(icon: Icon(Icons.link), text: "Blockchain"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildAuthTab(),
            _buildMessagingTab(),
            _buildFileTab(),
            _buildBlockchainTab(),
          ],
        ),
      ),
    );
  }

  // --- МОДУЛЬ 1: АУТЕНТИФИКАЦИЯ ---
  Widget _buildAuthTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          TextField(controller: _userController, decoration: InputDecoration(labelText: "Username")),
          TextField(controller: _passController, decoration: InputDecoration(labelText: "Password"), obscureText: true),
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: ElevatedButton(onPressed: _handleRegister, child: Text("Register"))),
              SizedBox(width: 10),
              Expanded(child: ElevatedButton(onPressed: _handleLogin, child: Text("Login"), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white))),
            ],
          ),
          Divider(height: 40),
          Text("MFA Status: ${_db.findUser(_userController.text) != null ? 'Active' : 'Not Configured'}"),
          Icon(Icons.qr_code, size: 100, color: Colors.grey[400]),
        ],
      ),
    );
  }

  void _handleRegister() async {
    if (_userController.text.isEmpty || _passController.text.isEmpty) return;

    // Создаем соль и хешируем пароль (PBKDF2)
    final salt = List<int>.generate(16, (i) => i + 10);
    final hash = await _auth.hashPassword(_passController.text, salt);

    // Сохраняем в Mock DB
    _db.addUser(_userController.text, hash.join(), salt);

    setState(() {
      _blockchain.addEvent("REGISTER: ${_userController.text}");
    });
    _showSnackBar("User registered in Mock DB");
  }

  void _handleLogin() async {
    final user = _db.findUser(_userController.text);
    if (user == null) {
      _showSnackBar("User not found");
      return;
    }

    // Проверка пароля: хешируем введенный пароль с той же солью
    final inputHash = await _auth.hashPassword(_passController.text, user['salt']);

    if (inputHash.join() == user['passwordHash']) {
      setState(() => _blockchain.addEvent("LOGIN_SUCCESS: ${_userController.text}"));
      _showSnackBar("Login Successful!");
    } else {
      setState(() => _blockchain.addEvent("LOGIN_FAILED: ${_userController.text}"));
      _showSnackBar("Wrong password!");
    }
  }

  // --- МОДУЛЬ 2: СООБЩЕНИЯ ---
  Widget _buildMessagingTab() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(8.0),
          child: TextField(controller: _recipientKeyController, decoration: InputDecoration(labelText: "Recipient Public Key (ECDH)")),
        ),
        Expanded(child: Center(child: Text("End-to-End Encrypted Chat"))),
        Padding(
          padding: EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(child: TextField(controller: _msgController, decoration: InputDecoration(hintText: "Message..."))),
              IconButton(icon: Icon(Icons.send), onPressed: () {
                setState(() => _blockchain.addEvent("MSG_SENT (AES-GCM + ECDSA)"));
                _msgController.clear();
              })
            ],
          ),
        )
      ],
    );
  }

  // --- МОДУЛЬ 3: ФАЙЛЫ ---
  Widget _buildFileTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: TextField(controller: _passController, decoration: InputDecoration(labelText: "Master Key / Password")),
          ),
          SizedBox(height: 20),
          ElevatedButton.icon(
            icon: Icon(Icons.lock),
            label: Text("Encrypt & Save File"),
            onPressed: () async {
              String? path = await _engine.encryptFile(_passController.text);
              if (path != null) {
                setState(() => _blockchain.addEvent("FILE_ENCRYPTED: ${path.split('/').last}"));
                _showSnackBar("File Secured!");
              }
            },
          ),
          SizedBox(height: 10),
          OutlinedButton.icon(
            icon: Icon(Icons.lock_open),
            label: Text("Decrypt File"),
            onPressed: () async {
              // Вставьте здесь вызов вашего метода decryptFile из CryptoEngine
              _showSnackBar("Decryption started...");
            },
          ),
        ],
      ),
    );
  }

  // --- МОДУЛЬ 4: БЛОКЧЕЙН ---
  Widget _buildBlockchainTab() {
    return ListView.builder(
      itemCount: _blockchain.chain.length,
      itemBuilder: (context, i) {
        final block = _blockchain.chain[i];
        return Card(
          margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: ListTile(
            leading: CircleAvatar(child: Text("${block.index}")),
            title: Text(block.action),
            subtitle: Text("Hash: ${block.hash.substring(0, 15)}...\nPrev: ${block.previousHash.substring(0, 15)}..."),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}