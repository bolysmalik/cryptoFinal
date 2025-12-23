import 'dart:convert';
import 'package:crypto/crypto.dart';

class Block {
  final int index;
  final String timestamp;
  final String action;
  final String previousHash;
  late String hash;

  Block(this.index, this.action, this.previousHash)
      : timestamp = DateTime.now().toIso8601String() {
    hash = calculateHash();
  }

  String calculateHash() {
    var bytes = utf8.encode("$index$timestamp$action$previousHash");
    return sha256.convert(bytes).toString();
  }
}