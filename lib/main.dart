import 'dart:async';

import 'package:flutter/material.dart';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class WordSearchLogic {
  final int gridSize;
  final List<String> pokemonPool = [
    "PIKACHU",
    "IVYSAUR",
    "VENUSAUR",
    "CHARMANDER",
    "CHARMELEON",
    "CHARIZARD",
    "SQUIRTLE",
    "WARTORTLE",
    "BLASTOISE",
    "CATERPIE",
    "EEVEE",
    "MEW",
    "BULBASAUR",
    "DITTO",
  ];
  List<String> pokemonNames = [];
  late List<String> grid;

  List<String> actualPlacedWords = []; // 儲存成功放入網格的單字
  // 新增：紀錄每個單字的首字母位置
  Map<String, int> wordFirstCharIndex = {};

  WordSearchLogic(this.gridSize) {
    grid = List.filled(gridSize * gridSize, "");
  }

  // 方向向量：[行增量, 列增量]
  final List<List<int>> directions = [
    [0, 1], // right
    [0, -1], // left
    [1, 0], // down
    [-1, 0], // up
    [1, 1], // right-down
    [-1, -1], // left-up
    [-1, 1], // right-up
    [1, -1], // left-down
  ];

  void fisherYatesShuffle<T>(List<T> list) {
    final random = Random();
    for (int i = list.length - 1; i > 0; i--) {
      // 隨機選取一個 0 到 i 之間的索引
      int j = random.nextInt(i + 1);
      // 交換位置
      T temp = list[i];
      list[i] = list[j];
      list[j] = temp;
    }
  }

  void generate() {
    final r = Random();
    final min = 3;
    final max = 6;
    int countOfPokemons = r.nextInt(max - min + 1) + min;
    pokemonNames.clear();
    // 1. 複製一份池子以免破壞原始資料，並打亂它
    List<String> shuffledPool = List.from(pokemonPool)..shuffle(r);

    // 2. 直接取出前 countOfPokemons 個，保證不重複
    pokemonNames = shuffledPool.take(countOfPokemons).toList();

    // 重新初始化 grid，否則舊的字母會一直留在那裡
    grid = List.filled(gridSize * gridSize, "");
    actualPlacedWords.clear(); // 重置
    wordFirstCharIndex.clear();
    final rand = Random();

    // 1. 先打亂單字庫
    fisherYatesShuffle(pokemonNames);

    // 2. 打亂方向順序
    fisherYatesShuffle(directions);

    for (String word in pokemonNames) {
      bool placed = false;
      int attempts = 0;

      while (!placed && attempts < 1000) {
        int dirIndex = rand.nextInt(directions.length);
        int row = rand.nextInt(gridSize);
        int col = rand.nextInt(gridSize);

        if (canPlace(word, row, col, directions[dirIndex])) {
          placeWord(word, row, col, directions[dirIndex]);
          placed = true;
          if (!actualPlacedWords.contains(word)) {
            // 確保不重複加入
            actualPlacedWords.add(word);
          }
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
      int index = r * gridSize + c;
      grid[index] = word[i];
      // 紀錄該單字的首字母位置
      if (i == 0) {
        wordFirstCharIndex[word] = index;
      }
    }
  }
}

void main() {
  // 設定狀態列顏色
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.red, // 變成 Pokemon 紅
    ),
  );
  runApp(MaterialApp(home: WordSearchGame()));
}

class WordSearchGame extends StatefulWidget {
  const WordSearchGame({super.key});

  @override
  State<WordSearchGame> createState() => _WordSearchGameState();
}

class _WordSearchGameState extends State<WordSearchGame> {
  late WordSearchLogic logic;
  late List<String> letters;
  final int gridSize = 10;
  final GlobalKey _gridKey = GlobalKey();
  final AudioPlayer _audioPlayer = AudioPlayer(); // 建立播放器實例
  Set<int> foundIndexes = {}; // 儲存已經被永久鎖定的格子
  Set<int> hintIndexes = {}; // 儲存提示格子

  // 紀錄目前選中的格子索引
  Set<int> selectedIndexes = {};
  int? startIndex; // 儲存滑動開始的格子
  Set<String> foundWords = {};

  // 定義背景顏色組合
  List<Color> colorList = [
    Colors.blue.shade900,
    Colors.purple.shade900,
    Colors.indigo.shade900,
    Colors.blue.shade700,
  ];
  int colorIndex = 0;
  Color bottomColor = Colors.blue.shade900;
  Color topColor = Colors.indigo.shade900;
  Alignment begin = Alignment.bottomLeft;
  Alignment end = Alignment.topRight;

  List<double> _scales = []; // 來儲存每格的縮放倍率（預設 1.0）

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
      startIndex ??= currentIndex;
      _applyStraightLine(startIndex!, currentIndex);
    }
  }

  void _resetGame() {
    setState(() {
      logic.generate(); // 重新生成網格字母
      letters = List.from(logic.grid); // 更新 UI 用的字母清單
      foundIndexes.clear(); // 清空綠色格子
      hintIndexes.clear(); // 清空提示格子
      selectedIndexes.clear(); // 清空當前選取
      foundWords.clear(); // 清空已找到單字紀錄
      startIndex = null;
    });
  }

  void _checkWin() {
    // 將實際放入的單字轉為 Set，確保比對基準唯一
    final expectedSet = logic.actualPlacedWords.toSet();

    // 檢查是否所有「成功放入網格」的單字都找齊了
    if (foundWords.length == expectedSet.length && expectedSet.isNotEmpty) {
      showDialog(
        context: context,
        barrierDismissible: false, // 玩家必須點擊按鈕
        builder: (context) => AlertDialog(
          title: Text("太棒了！"),
          content: Text("你找到了所有的 Pokemon！"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _resetGame(); // 重新開始
              },
              child: Text("再玩一次"),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _playSound(String pokemonName) async {
    // 使用 AssetSource 播放專案內的音效
    await _audioPlayer.play(AssetSource('audio/$pokemonName.mp3'));
  }

  // 在 _WordSearchGameState 內新增這個方法
  void _giveHint() {
    // 找出還沒被找到的單字
    List<String> remainingWords = logic.actualPlacedWords
        .where((word) => !foundWords.contains(word))
        .toList();

    if (remainingWords.isNotEmpty) {
      // 隨機挑一個未找到的單字
      String hintWord = (remainingWords..shuffle()).first;
      int? hintIndex = logic.wordFirstCharIndex[hintWord];

      if (hintIndex != null) {
        setState(() {
          // 將該首字母位置加入已找到的索引
          if (!hintIndexes.contains(hintIndex)) {
            hintIndexes.add(hintIndex);
          }
        });

        // 可以加個 SnackBar 提示玩家正在找哪個字
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("提示：找找看 '$hintWord' 的開頭！"),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Pokemon Word Search")),
      body: AnimatedContainer(
        duration: const Duration(seconds: 4), // 動畫變化的平滑時間
        onEnd: () {
          // 動畫結束後可以觸發特定邏輯（選用）
        },
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: begin,
            end: end,
            colors: [bottomColor, topColor],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 頂部資訊區 (例如顯示分數或提示)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "找到所有隱藏的 Pokemon!",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(width: 8), // 文字與按鈕之間的間距
              // 燈泡按鈕
              GestureDetector(
                onTap: _giveHint,
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2), // 淡淡的背景色
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lightbulb_outline,
                    color: Colors.amber[700],
                    size: 24,
                  ),
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
                          // 檢查 logic.pokemonNames (也確保名單是全大寫)
                          String? match;
                          // 先把目前選中的索引存成一個固定的 List
                          final List<int> indexesToAnimate = selectedIndexes
                              .toList();

                          for (var name in logic.pokemonNames) {
                            String target = name.toUpperCase();
                            if (selectedWord == target ||
                                reversedWord == target) {
                              match = name;
                              break;
                            }
                          }

                          // 2. 比對 Pokemon 名單 (檢查正向或反向)
                          if (match != null && !foundWords.contains(match)) {
                            // 答對了！將目前選中的加入永久集合
                            setState(() {
                              foundIndexes.addAll(selectedIndexes);
                              foundWords.add(match!);

                              // 移除該單字的提示框（如果有用的話）
                              int? firstCharIdx =
                                  logic.wordFirstCharIndex[match];
                              if (firstCharIdx != null) {
                                hintIndexes.remove(firstCharIdx);
                              }

                              // 瞬間放大
                              for (int i in indexesToAnimate) {
                                _scales[i] = 1.3;
                              }
                            });

                            _playSound(match.toLowerCase()); // <--- 在這裡播放叫聲！

                            // 檢查是否全數找完
                            Future.delayed(Duration(milliseconds: 300), () {
                              _checkWin();
                              if (mounted) {
                                setState(() {
                                  // 縮回原狀
                                  for (int i in indexesToAnimate) {
                                    _scales[i] = 1.0;
                                  }
                                });
                              }
                            });
                          }

                          // 3. 重置暫時選取的狀態
                          setState(() {
                            startIndex = null;
                            selectedIndexes.clear();
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.all(8), // 給網格一點邊距
                          decoration: BoxDecoration(
                            // 設定漸層背景
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.blue.shade900, // 深藍色
                                Colors.blue.shade300, // 亮青色，增加視覺延伸感
                              ],
                              stops: [0.2, 0.9], // 讓深色佔比少一點，淺色多一點
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: GridView.builder(
                            key: _gridKey, // 關鍵：把 Key 綁在這裡
                            shrinkWrap: true,
                            physics:
                                NeverScrollableScrollPhysics(), // 禁用滾動，確保手勢被選取邏輯接收
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: gridSize,
                                  childAspectRatio:
                                      1.0, // 1.0 是正方形，如果設為 1.2 會變扁，能顯示更多行
                                ),
                            itemCount: gridSize * gridSize,
                            itemBuilder: (context, index) {
                              bool isSelected = selectedIndexes.contains(index);
                              bool isFound = foundIndexes.contains(
                                index,
                              ); // 檢查是否已找到
                              bool isHint = hintIndexes.contains(
                                index,
                              ); // 檢查是提示

                              return AnimatedScale(
                                scale:
                                    _scales[index], // 這裡的 index 來自 itemBuilder
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeInOutBack, // 加入彈性效果更有遊戲感
                                child: Container(
                                  margin: EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    // 優先序：正在選取 (橙色) > 已經找到 (綠色) > 預設 (藍色)
                                    color: isSelected
                                        ? Colors.orange
                                        : (isFound
                                              ? Colors.green.withValues(
                                                  alpha: 0.7,
                                                ) // 稍微降低綠色飽和
                                              : Colors.white.withValues(
                                                  alpha: 0.05,
                                                )), // 降到 0.05，近乎透明
                                    border: isHint
                                        ? Border.all(
                                            color: Colors.yellowAccent,
                                            width: 3.5, // 增加寬度讓提示更明顯
                                          )
                                        : Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.1,
                                            ), // 平時給予極淡的邊框線，維持格子整齊
                                            width: 1,
                                          ),
                                    borderRadius: BorderRadius.circular(4),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: Colors.yellow.withValues(
                                                alpha: 0.5,
                                              ),
                                              blurRadius: 10,
                                              spreadRadius: 2,
                                            ),
                                          ]
                                        : [],
                                  ),
                                  child: Center(
                                    child: Text(
                                      letters[index],
                                      style: TextStyle(
                                        // 如果是被提示的格子，可以讓字體稍微大一點點
                                        fontSize: isHint ? 22 : 20,
                                        fontWeight: FontWeight.bold,
                                        // 已找到的字可以變色或加刪除線
                                        color: isFound
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
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
                  children: logic.actualPlacedWords.map((name) {
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
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    logic = WordSearchLogic(gridSize); // 10x10 網格
    logic.generate();
    // 將生成的 grid 賦值給你的 letters 變數
    letters = List.from(logic.grid);

    // 設定計時器，每 3 秒更換一次顏色與對齊方向
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {
          colorIndex = colorIndex + 1;
          bottomColor = colorList[colorIndex % colorList.length];
          topColor = colorList[(colorIndex + 1) % colorList.length];
          // 改變方向讓漸層更有「流動感」
          begin = colorIndex % 2 == 0
              ? Alignment.bottomLeft
              : Alignment.topLeft;
          end = colorIndex % 2 == 0
              ? Alignment.topRight
              : Alignment.bottomRight;
        });
      }
    });

    _scales = List<double>.filled(gridSize * gridSize, 1.0);
  }

  @override
  void dispose() {
    _audioPlayer.dispose(); // 記得銷毀播放器釋放記憶體
    super.dispose();
  }
}
