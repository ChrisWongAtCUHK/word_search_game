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

  // 核心邏輯：將觸碰點轉為格子索引
  void _calculateIndex(Offset localPosition, BoxConstraints constraints) {
    double cellWidth = constraints.maxWidth / gridSize;
    double cellHeight = constraints.maxHeight / gridSize;

    int col = (localPosition.dx / cellWidth).floor();
    int row = (localPosition.dy / cellHeight).floor();

    if (col >= 0 && col < gridSize && row >= 0 && row < gridSize) {
      int index = row * gridSize + col;
      setState(() {
        selectedIndexes.add(index); // 這裡可以加入直線判斷邏輯
      });
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
              onPanEnd: (_) =>
                  setState(() => selectedIndexes.clear()), // 手指放開清空選取
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
