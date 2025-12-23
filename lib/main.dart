import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file_plus/open_file_plus.dart';

// Ваши сервисы
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
  String? _selectedRecipient;
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

  Widget _buildLockedScreen() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.lock_outline, size: 64, color: Colors.grey),
        Text("Требуется авторизация", style: TextStyle(color: Colors.grey)),
      ],
    ),
  );

  // --- Вкладка AUTH ---
  Widget _buildAuthTab() {
    if (_isLoggedIn) {
      return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.verified_user, size: 80, color: Colors.green),
              Text("Привет, $_currentUsername!", style: TextStyle(fontSize: 18)),
            ],
          ));
    }
    return Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          TextField(controller: _userController, decoration: InputDecoration(labelText: "Логин")),
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

  // --- Вкладка ЧАТ ---
  Widget _buildMessagingTab() {
    List<String> otherUsers = _db.getAllUsernames(_currentUsername ?? "");

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: DropdownButtonFormField<String>(
            decoration: InputDecoration(labelText: "Выберите получателя", border: OutlineInputBorder()),
            value: _selectedRecipient,
            items: otherUsers.map((user) => DropdownMenuItem(value: user, child: Text(user))).toList(),
            onChanged: (val) => setState(() => _selectedRecipient = val),
          ),
        ),
        Expanded(
          child: _selectedRecipient == null
              ? Center(child: Text("Выберите пользователя из списка"))
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
        if (_selectedRecipient != null)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(child: TextField(controller: _msgController, decoration: InputDecoration(hintText: "Зашифрованное сообщение..."))),
                IconButton(
                  icon: Icon(Icons.send, color: Colors.indigo),
                  onPressed: _handleSendMessage,
                ),
              ],
            ),
          )
      ],
    );
  }

  // --- Вкладка ФАЙЛЫ ---
  Widget _buildFileTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.security, size: 80, color: Colors.indigo),
            const SizedBox(height: 20),
            const Text("Криптографический сейф файлов", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),

            // Кнопка Шифрования
            ElevatedButton.icon(
              icon: const Icon(Icons.lock),
              label: const Text("ЗАШИФРОВАТЬ И СОХРАНИТЬ"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 55),
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                FilePickerResult? result = await FilePicker.platform.pickFiles();
                if (result != null && result.files.single.path != null) {
                  File selectedFile = File(result.files.single.path!);
                  String? path = await _engine.encryptFile(selectedFile, _passController.text);
                  if (path != null) {
                    setState(() {
                      _lastEncryptedPath = path;
                      _blockchain.addEvent("ENCRYPT: ${selectedFile.path.split('/').last}");
                    });
                    await Share.shareXFiles([XFile(path)], text: 'Зашифрованный файл');
                  }
                }
              },
            ),

            const SizedBox(height: 15),

            // Кнопка Расшифровки
            ElevatedButton.icon(
              icon: const Icon(Icons.lock_open, color: Colors.green),
              label: const Text("РАСШИФРОВАТЬ И ОТКРЫТЬ"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 55),
                side: BorderSide(color: Colors.green, width: 2),
              ),
              onPressed: () async {
                // 1. Выбираем зашифрованный файл .enc
                FilePickerResult? result = await FilePicker.platform.pickFiles();
                if (result != null && result.files.single.path != null) {
                  File encryptedFile = File(result.files.single.path!);

                  // 2. Расшифровываем
                  Uint8List? decryptedData = await _engine.decryptFile(encryptedFile, _passController.text);

                  if (decryptedData != null) {
                    // 3. Сохраняем во временную папку для просмотра
                    final tempDir = await getTemporaryDirectory();
                    // Очищаем имя от префиксов и расширения .enc
                    String originalName = encryptedFile.path.split('/').last
                        .replaceAll('vault_', '')
                        .replaceAll('.enc', '');

                    final tempFile = File('${tempDir.path}/$originalName');
                    await tempFile.writeAsBytes(decryptedData);

                    // 4. Открываем файл
                    await OpenFile.open(tempFile.path);

                    setState(() => _blockchain.addEvent("DECRYPT: $originalName"));
                    _showSnackBar("Файл расшифрован!");
                  } else {
                    _showSnackBar("Ошибка! Неверный пароль или файл поврежден.");
                  }
                }
              },
            ),

            if (_lastEncryptedPath != null) ...[
              const SizedBox(height: 20),
              Text("Путь к .enc: ${_lastEncryptedPath!.split('/').last}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ]
          ],
        ),
      ),
    );
  }

  // --- Вкладка LEDGER ---
  Widget _buildBlockchainTab() {
    final blocks = _blockchain.chain.reversed.toList();
    return ListView.builder(
      itemCount: blocks.length,
      itemBuilder: (context, i) {
        final block = blocks[i];
        return Card(
          child: ListTile(
            leading: Icon(Icons.vpn_key, color: Colors.amber),
            title: Text(block.action),
            subtitle: Text("Хеш: ${_formatHash(block.hash)}"),
            trailing: Icon(Icons.verified_user, color: Colors.green, size: 16),
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
          _blockchain.addEvent("ВХОД: $_currentUsername");
        });
        return;
      }
    }
    _showSnackBar("Неверный пароль!");
  }

  void _handleRegister() async {
    if (_userController.text.isEmpty || _passController.text.isEmpty) return;
    final salt = List<int>.generate(16, (i) => i + 7);
    final hash = await _auth.hashPassword(_passController.text, salt);
    _db.addUser(_userController.text, hash.join(), salt);
    setState(() => _blockchain.addEvent("РЕГИСТРАЦИЯ: ${_userController.text}"));
    _showSnackBar("Пользователь создан!");
    _userController.clear();
    _passController.clear();
  }

  void _handleLogout() {
    setState(() {
      _isLoggedIn = false;
      _currentUsername = null;
      _selectedRecipient = null;
      _blockchain.addEvent("ВЫХОД");
    });
  }

  void _handleSendMessage() {
    if (_msgController.text.isEmpty || _selectedRecipient == null) return;
    setState(() {
      _db.addMessage(_currentUsername!, _selectedRecipient!, _msgController.text);
      _blockchain.addEvent("MSG: -> $_selectedRecipient");
      _msgController.clear();
    });
  }

  Widget _chatBubble(String sender, String text, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? Colors.indigo : Colors.grey[200],
          borderRadius: BorderRadius.circular(15),
        ),
        child: Text(text, style: TextStyle(color: isMe ? Colors.white : Colors.black)),
      ),
    );
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}