import 'package:flutter/material.dart';
import 'dart:math';

class WordSearchLogic {
  final int gridSize;
  final List<String> pokemonNames = [
    "PIKACHU",
    "EEVEE",
    "MEW",
    "CHARIZARD",
    "BULBASAUR",
    "DITTO",
  ];
  late List<String> grid;

  WordSearchLogic(this.gridSize) {
    grid = List.filled(gridSize * gridSize, "");
  }

  // 方向向量：[行增量, 列增量]
  final List<List<int>> directions = [
    [0, 1], // 水平
    [1, 0], // 垂直
    [1, 1], // 右下對角
    [-1, 1], // 右上對角
  ];

  void generate() {
    final rand = Random();

    for (String word in pokemonNames) {
      bool placed = false;
      int attempts = 0;

      while (!placed && attempts < 100) {
        int dirIndex = rand.nextInt(directions.length);
        int row = rand.nextInt(gridSize);
        int col = rand.nextInt(gridSize);

        if (canPlace(word, row, col, directions[dirIndex])) {
          placeWord(word, row, col, directions[dirIndex]);
          placed = true;
        }
        attempts++;
      }
    }

    // 最後用隨機字母填滿空格
    for (int i = 0; i < grid.length; i++) {
      if (grid[i] == "") {
        grid[i] = String.fromCharCode(rand.nextInt(26) + 65);
      }
    }
  }

  bool canPlace(String word, int row, int col, List<int> dir) {
    for (int i = 0; i < word.length; i++) {
      int r = row + (i * dir[0]);
      int c = col + (i * dir[1]);

      if (r < 0 || r >= gridSize || c < 0 || c >= gridSize) return false;

      String currentLetter = grid[r * gridSize + c];
      if (currentLetter != "" && currentLetter != word[i]) return false;
    }
    return true;
  }

  void placeWord(String word, int row, int col, List<int> dir) {
    for (int i = 0; i < word.length; i++) {
      int r = row + (i * dir[0]);
      int c = col + (i * dir[1]);
      grid[r * gridSize + c] = word[i];
    }
  }
}

void main() => runApp(MaterialApp(home: WordSearchGame()));

class WordSearchGame extends StatefulWidget {
  @override
  _WordSearchGameState createState() => _WordSearchGameState();
}

class _WordSearchGameState extends State<WordSearchGame> {
  late WordSearchLogic logic;
  final int gridSize = 10;
  final GlobalKey _gridKey = GlobalKey();
  List<String> letters = List.generate(
    100,
    (index) => "ABCDEFGHIJKLMNOPQRSTUVWXYZ"[index % 26],
  );
  Set<int> foundIndexes = {}; // 儲存已經被永久鎖定的格子

  // 紀錄目前選中的格子索引
  Set<int> selectedIndexes = {};
  int? startIndex; // 儲存滑動開始的格子
  List<String> foundWords = [];

  void _applyStraightLine(int start, int end) {
    int startRow = start ~/ gridSize;
    int startCol = start % gridSize;
    int endRow = end ~/ gridSize;
    int endCol = end % gridSize;

    int dy = endRow - startRow;
    int dx = endCol - startCol;

    // 判斷方向
    int stepR = dy == 0 ? 0 : dy.sign; // 行移動方向 (-1, 0, 1)
    int stepC = dx == 0 ? 0 : dx.sign; // 列移動方向 (-1, 0, 1)

    // 檢查是否符合直線規則 (水平、垂直、或 45度斜線)
    if (dy == 0 || dx == 0 || dy.abs() == dx.abs()) {
      Set<int> newSelection = {};
      int currentRow = startRow;
      int currentCol = startCol;

      // 建立從起點到終點的線
      while (true) {
        newSelection.add(currentRow * gridSize + currentCol);
        if (currentRow == endRow && currentCol == endCol) break;
        currentRow += stepR;
        currentCol += stepC;
      }

      setState(() {
        selectedIndexes = newSelection;
      });
    }
  }

  void _calculateIndex(Offset globalPosition) {
    // 獲取網格在螢幕上的實際位置
    final RenderBox box =
        _gridKey.currentContext?.findRenderObject() as RenderBox;
    final Offset localOffset = box.globalToLocal(
      globalPosition,
    ); // 關鍵：轉換為網格內部的相對座標

    double cellWidth = box.size.width / gridSize;
    double cellHeight = box.size.height / gridSize;

    int col = (localOffset.dx / cellWidth).floor();
    int row = (localOffset.dy / cellHeight).floor();

    // 檢查座標是否在網格範圍內
    if (col >= 0 && col < gridSize && row >= 0 && row < gridSize) {
      int currentIndex = row * gridSize + col;
      if (startIndex == null) startIndex = currentIndex;
      _applyStraightLine(startIndex!, currentIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Pokemon Word Search")),
      body: Column(
        children: [
          // 頂部資訊區 (例如顯示分數或提示)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              "找到所有隱藏的 Pokemon!",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          // 2. 網格區：使用 Expanded 確保網格佔用適當空間
          Expanded(
            child: Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    // 手指按下、移動時觸發
                    onPanUpdate: (details) =>
                        _calculateIndex(details.globalPosition),
                    onPanEnd: (_) {
                      // 1. 將選中的索引轉回字母組合成單字
                      // 先把 selectedIndexes 轉成 List 並排序（避免選取的順序影響比對，但要注意如果是反向選取需要特別處理）
                      // 這裡簡單處理：按索引順序組合
                      List<int> sortedIndices = selectedIndexes.toList()
                        ..sort();
                      String selectedWord = sortedIndices
                          .map((i) => letters[i])
                          .join();
                      String reversedWord = selectedWord
                          .split('')
                          .reversed
                          .join();

                      // 2. 比對 Pokemon 名單 (檢查正向或反向)
                      if (logic.pokemonNames.contains(selectedWord) ||
                          logic.pokemonNames.contains(reversedWord)) {
                        // 答對了！將目前選中的加入永久集合
                        setState(() {
                          foundIndexes.addAll(selectedIndexes);
                        });
                        print("找到 Pokemon: $selectedWord !");
                        foundWords.add(selectedWord);
                      }

                      // 3. 重置暫時選取的狀態
                      setState(() {
                        startIndex = null;
                        selectedIndexes.clear();
                      });
                    },

                    child: GridView.builder(
                      key: _gridKey, // 關鍵：把 Key 綁在這裡
                      shrinkWrap: true,
                      physics:
                          NeverScrollableScrollPhysics(), // 禁用滾動，確保手勢被選取邏輯接收
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: gridSize,
                        childAspectRatio: 1.0, // 1.0 是正方形，如果設為 1.2 會變扁，能顯示更多行
                      ),
                      itemCount: gridSize * gridSize,
                      itemBuilder: (context, index) {
                        bool isSelected = selectedIndexes.contains(index);
                        bool isFound = foundIndexes.contains(index); // 檢查是否已找到

                        return Container(
                          margin: EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            // 優先序：正在選取 (橙色) > 已經找到 (綠色) > 預設 (藍色)
                            color: isSelected
                                ? Colors.orange
                                : (isFound ? Colors.green : Colors.blue[100]),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Center(
                            child: Text(
                              letters[index],
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                // 已找到的字可以變色或加刪除線
                                color: isFound ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Wrap(
              spacing: 10,
              children: logic.pokemonNames.map((name) {
                bool isFound = foundWords.contains(name); // 假設你紀錄了找到的單字名
                return Text(
                  name,
                  style: TextStyle(
                    fontSize: 16,
                    decoration: isFound ? TextDecoration.lineThrough : null,
                    color: isFound ? Colors.grey : Colors.black,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    logic = WordSearchLogic(10); // 10x10 網格
    logic.generate();
    // 將生成的 grid 賦值給你的 letters 變數
    letters = logic.grid;
  }
}
