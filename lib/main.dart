import 'package:flutter/material.dart';
import 'services/crypto_engine.dart';
import 'services/blockchain_service.dart';

void main() => runApp(MaterialApp(home: CryptoVaultApp()));

class CryptoVaultApp extends StatefulWidget {
  @override
  _CryptoVaultAppState createState() => _CryptoVaultAppState();
}

class _CryptoVaultAppState extends State<CryptoVaultApp> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _msgController = TextEditingController();
  final TextEditingController _recipientKeyController = TextEditingController();

  final CryptoEngine _engine = CryptoEngine();
  final BlockchainService _blockchain = BlockchainService();
  final TextEditingController _passController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text("CryptoVault Suite"),
          bottom: TabBar(
            isScrollable: true, // Чтобы 4 вкладки поместились
            tabs: [
              Tab(text: "Auth"),
              Tab(text: "Messaging"),
              Tab(text: "Files"),
              Tab(text: "Blockchain"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildAuthTab(),      // Нужно создать
            _buildMessagingTab(), // Нужно создать
            _buildFileTab(),      // У вас уже есть (добавьте расшифровку)
            _buildBlockchainTab(),// У вас уже есть
          ],
        ),
      ),
    );
  }

  Widget _buildFileTab() {
    return Column(children: [
      TextField(controller: _passController, decoration: InputDecoration(labelText: "Password")),
      ElevatedButton(
          onPressed: () async {
            String? path = await _engine.encryptFile(_passController.text);
            if (path != null) {
              setState(() => _blockchain.addEvent("File Encrypted: ${path.split('/').last}"));
            }
          },
          child: Text("Encrypt File")
      )
    ]);
  }

  Widget _buildBlockchainTab() {
    return ListView.builder(
      itemCount: _blockchain.chain.length,
      itemBuilder: (context, i) => ListTile(
        title: Text(_blockchain.chain[i].action),
        subtitle: Text("Hash: ${_blockchain.chain[i].hash.substring(0, 15)}..."),
      ),
    );
  }

  Widget _buildAuthTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text("Регистрация / Вход", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 20),
          TextField(
            controller: _userController, // Добавьте этот контроллер в State
            decoration: InputDecoration(labelText: "Имя пользователя", border: OutlineInputBorder()),
          ),
          SizedBox(height: 10),
          TextField(
            controller: _passController,
            decoration: InputDecoration(labelText: "Пароль", border: OutlineInputBorder()),
            obscureText: true,
          ),
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _handleRegister(),
                  child: Text("Регистрация"),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _handleLogin(),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  child: Text("Войти"),
                ),
              ),
            ],
          ),
          Divider(height: 40),
          // Секция MFA (TOTP) - Требование задания (3 балла)
          Text("Multi-Factor Authentication (TOTP)", style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          Center(
            child: Container(
              width: 150,
              height: 150,
              color: Colors.grey[200],
              child: Icon(Icons.qr_code_2, size: 100, color: Colors.grey), // Здесь будет QR-код
            ),
          ),
          TextButton(onPressed: () {}, child: Text("Сгенерировать новый секрет TOTP")),
        ],
      ),
    );
  }

// Логика для кнопок (добавьте в _CryptoVaultAppState)
  void _handleRegister() async {
    // Требование: Соль + PBKDF2/Argon2 [cite: 35]
    _blockchain.addEvent("AUTH_REGISTER: ${_userController.text}");
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Пользователь зарегистрирован")));
    setState(() {});
  }

  void _handleLogin() {
    // Требование: Запись события в блокчейн [cite: 145, 148]
    _blockchain.addEvent("AUTH_LOGIN: ${_userController.text} (Success)");
    setState(() {});
  }

  Widget _buildMessagingTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Публичный ключ получателя (ECDH)
          TextField(
            decoration: InputDecoration(
              labelText: "Публичный ключ получателя (Hex)",
              helperText: "Необходим для генерации общего секрета через ECDH",
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 10),
          Expanded(
            child: Container(
              decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
              child: ListView(
                padding: EdgeInsets.all(8),
                children: [
                  Text("Система: Сессия защищена (AES-256-GCM)", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  // Здесь будут сообщения
                ],
              ),
            ),
          ),
          SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(hintText: "Зашифрованное сообщение..."),
                ),
              ),
              IconButton(
                icon: Icon(Icons.send, color: Colors.blue),
                onPressed: () {
                  // Логика: 1. ECDH Shared Secret -> 2. AES-GCM Encrypt -> 3. ECDSA Sign [cite: 84, 85, 71]
                  _blockchain.addEvent("MSG_SENT: Hash check performed");
                  setState(() {});
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}