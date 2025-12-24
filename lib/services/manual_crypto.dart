import 'dart:convert';
import 'package:crypto/crypto.dart'; // Используется только как базовый SHA-256 хеш для узлов


class ManualMerkleTree {
  List<String> leaves;
  List<List<String>> tree = [];

  ManualMerkleTree(this.leaves) {
    if (leaves.isNotEmpty) {
      _buildTree();
    }
  }

  void _buildTree() {
    // 1. Хешируем входные данные (листья)
    List<String> currentLayer = leaves.map((e) => _hash(e)).toList();
    tree.add(currentLayer);

    // 2. Строим дерево вверх до корня
    while (currentLayer.length > 1) {
      if (currentLayer.length % 2 != 0) {
        currentLayer.add(currentLayer.last); // Дублируем, если нечетное
      }
      List<String> nextLayer = [];
      for (int i = 0; i < currentLayer.length; i += 2) {
        nextLayer.add(_hash(currentLayer[i] + currentLayer[i + 1]));
      }
      tree.add(nextLayer);
      currentLayer = nextLayer;
    }
  }

  // Генерация доказательства (Merkle Proof)
  List<Map<String, String>> generateProof(int index) {
    List<Map<String, String>> proof = [];
    int currentIndex = index;

    for (int i = 0; i < tree.length - 1; i++) {
      int siblingIndex = (currentIndex % 2 == 0) ? currentIndex + 1 : currentIndex - 1;
      if (siblingIndex < tree[i].length) {
        proof.add({
          (currentIndex % 2 == 0 ? 'right' : 'left'): tree[i][siblingIndex]
        });
      }
      currentIndex ~/= 2;
    }
    return proof;
  }

  // Проверка доказательства (без использования дерева)
  static bool verifyProof(String leaf, String root, List<Map<String, String>> proof) {
    String currentHash = _hash(leaf);
    for (var p in proof) {
      if (p.containsKey('right')) {
        currentHash = _hash(currentHash + p['right']!);
      } else {
        currentHash = _hash(p['left']! + currentHash);
      }
    }
    return currentHash == root;
  }

  static String _hash(String input) => sha256.convert(utf8.encode(input)).toString();
  String get root => tree.isNotEmpty ? tree.last.first : "";
}


class AESKeyExpansion {
  // Константы Rcon (Round Constants)
  static const List<int> rcon = [
    0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36
  ];

  // S-Box (упрощенный пример таблицы замен для демонстрации)
  static int subByte(int byte) {
    // В реальности здесь полная таблица 256 байт
    // Для демонстрации используем простую математическую замену (XOR + Rotation)
    return (byte ^ 0x63) % 256;
  }

  static List<int> rotateWord(List<int> word) {
    return [word[1], word[2], word[3], word[0]];
  }

  // Основной алгоритм расширения ключа
  static List<int> expandKey(List<int> masterKey) {
    List<int> expanded = List.from(masterKey);

    // Для AES-256 нам нужно 14 раундов (всего 60 слов по 4 байта)
    while (expanded.length < 240) {
      List<int> temp = expanded.sublist(expanded.length - 4);

      if (expanded.length % 32 == 0) {
        temp = rotateWord(temp);
        temp = temp.map((b) => subByte(b)).toList();
        temp[0] ^= rcon[(expanded.length ~/ 32) - 1];
      } else if (expanded.length % 32 == 16) {
        temp = temp.map((b) => subByte(b)).toList();
      }

      for (int i = 0; i < 4; i++) {
        expanded.add(expanded[expanded.length - 32] ^ temp[i]);
      }
    }
    return expanded;
  }
}


class FastModularMath {
  // Быстрое возведение в степень по модулю: (base^exp) % mod
  static BigInt powerMod(BigInt base, BigInt exp, BigInt mod) {
    BigInt res = BigInt.one;
    base = base % mod;

    String binaryExp = exp.toRadixString(2); // Двоичное представление степени

    for (int i = 0; i < binaryExp.length; i++) {
      res = (res * res) % mod; // Square (Возведение в квадрат)
      if (binaryExp[i] == '1') {
        res = (res * base) % mod; // Multiply (Умножение)
      }
    }
    return res;
  }
}