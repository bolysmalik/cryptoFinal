import 'package:flutter/material.dart';
import 'services/crypto_engine.dart';
import 'services/blockchain_service.dart';

void main() => runApp(MaterialApp(home: CryptoVaultApp()));

class CryptoVaultApp extends StatefulWidget {
  @override
  _CryptoVaultAppState createState() => _CryptoVaultAppState();
}

class _CryptoVaultAppState extends State<CryptoVaultApp> {
  final CryptoEngine _engine = CryptoEngine();
  final BlockchainService _blockchain = BlockchainService();
  final TextEditingController _passController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text("CryptoVault Suite"),
          bottom: TabBar(tabs: [Tab(text: "Files"), Tab(text: "Blockchain")]),
        ),
        body: TabBarView(children: [
          _buildFileTab(),
          _buildBlockchainTab(),
        ]),
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
}