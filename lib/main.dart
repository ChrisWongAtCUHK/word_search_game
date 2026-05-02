import 'package:flutter/material.dart';

void main() => runApp(MaterialApp(home: WordSearchGame()));

class WordSearchGame extends StatefulWidget {
  @override
  _WordSearchGameState createState() => _WordSearchGameState();
}

class _WordSearchGameState extends State<WordSearchGame> {
  final int gridSize = 8;
  final List<String> letters = List.generate(
    64,
    (index) => "ABCDEFGHIJKLMNOPQRSTUVWXYZ"[index % 26],
  );

  // 紀錄目前選中的格子索引
  Set<int> selectedIndexes = {};
  int? startIndex; // 儲存滑動開始的格子

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

  // 核心邏輯：將觸碰點轉為格子索引
  void _calculateIndex(Offset localPosition, BoxConstraints constraints) {
    double cellWidth = constraints.maxWidth / gridSize;
    double cellHeight = constraints.maxHeight / gridSize;

    int col = (localPosition.dx / cellWidth).floor();
    int row = (localPosition.dy / cellHeight).floor();

    if (col >= 0 && col < gridSize && row >= 0 && row < gridSize) {
      int currentIndex = row * gridSize + col;

      if (startIndex == null) {
        startIndex = currentIndex;
      }

      _applyStraightLine(startIndex!, currentIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Flutter Word Search")),
      body: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              // 手指按下、移動時觸發
              onPanUpdate: (details) =>
                  _calculateIndex(details.localPosition, constraints),
              onPanEnd: (_) {
                // 這裡可以檢查 selectedIndexes 的單字是否正確
                print("選取的索引: $selectedIndexes");
                setState(() {
                  startIndex = null; // 重置
                  selectedIndexes.clear();
                });
              },
              child: GridView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(), // 禁用滾動，確保手勢被選取邏輯接收
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: gridSize,
                ),
                itemCount: gridSize * gridSize,
                itemBuilder: (context, index) {
                  bool isSelected = selectedIndexes.contains(index);
                  return Container(
                    margin: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.orange : Colors.blue[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        letters[index],
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
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
    );
  }
}
