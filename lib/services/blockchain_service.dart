import '../models/block.dart';

class BlockchainService {
  List<Block> chain = [];

  BlockchainService() {
    chain.add(Block(0, "Genesis Block - System Initialized", "0"));
  }

  void addEvent(String action) {
    chain.add(Block(chain.length, action, chain.last.hash));
  }

  bool isChainValid() {
    for (int i = 1; i < chain.length; i++) {
      if (chain[i].hash != chain[i].calculateHash()) return false;
      if (chain[i].previousHash != chain[i - 1].hash) return false;
    }
    return true;
  }
}