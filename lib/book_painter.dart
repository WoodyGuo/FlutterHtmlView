import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

const String _tag = 'BookPainter';
double anchorPointWith = 12;

/// 划线的painter组件
class BookPainter extends CustomPainter {
  BookPainter({
    @required this.text,
    @required this.textStyle,
    @required this.painterWithMap,
    @required this.textHeight,
    @required this.systemColor,
    @required this.wordRectListCallback,
    @required this.lightRectList,
    @required this.isSelectedMode,
  });

  /// 字的样式
  final TextStyle textStyle;

  /// 每个字符的宽度
  final Map<String, double> painterWithMap;

  /// 绘制的文字
  final String text;

  /// 文字高度
  final double textHeight;

  /// 系统颜色
  final Color systemColor;
  final ValueChanged<List<List<WordData>>> wordRectListCallback;

  /// 显示高亮的颜色区域
  final List<Rect> lightRectList;

  /// 是否是选择模式
  final bool isSelectedMode;

  /// 用来保存单词的位置信息
  ///
  /// [
  ///  第一行的单词 [(l, t, r, b), (l, t, r, b), ...],
  ///  第二行的单词 [(l, t, r, b), (l, t, r, b), ...],
  ///  .....
  /// ]
  List<List<WordData>> wordRectList = [];

  /// 获得单词宽度
  double _getWordWidth(String word) {
    int wordCount = word.length;
    double width = 0;
    for (int j = 0; j < wordCount; ++j) {
      String subString = word.substring(j, j + 1);
      width += painterWithMap[subString];
    }
    return width;
  }

  @override
  void paint(Canvas canvas, Size size) {
    Paint anchorPaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2;
    // 选中高亮的颜色
    Paint paint = Paint()..color = Color(0x341F8EFA);
    if (lightRectList != null && lightRectList.isNotEmpty) {
      int count = lightRectList.length;
      for (int i = 0; i < count; ++i) {
        Rect rect = lightRectList[i];

        if (rect != null) {
          Rect tempRect = rect;
          if (i == 0) {
            tempRect = Rect.fromLTRB(rect.left, rect.top + anchorPointWith / 2, rect.right, rect.bottom);
          } else if (i == count - 1) {
            tempRect = Rect.fromLTRB(rect.left, rect.top, rect.right, rect.bottom - anchorPointWith / 2);
          }
          canvas.drawRect(tempRect, paint);

          if (isSelectedMode) {
            if (i == 0) {
              canvas.drawOval(
                  Rect.fromLTWH(rect.left - anchorPointWith / 2, rect.top,
                      anchorPointWith, anchorPointWith),
                  anchorPaint);
              canvas.drawLine(
                  Offset(rect.left, rect.top + anchorPointWith), Offset(rect.left, rect.bottom), anchorPaint);
            }
            if (i == count - 1) {
              canvas.drawLine(
                  Offset(rect.right, rect.top), Offset(rect.right, rect.bottom - anchorPointWith), anchorPaint);
              canvas.drawOval(
                  Rect.fromLTWH(rect.right - anchorPointWith / 2, rect.bottom - anchorPointWith, anchorPointWith,
                      anchorPointWith),
                  anchorPaint);
            }
          }
        }
      }
    }

    wordRectList.clear();
    List<String> wordText = text.split(' ');
    // 单词的数量
    int count = wordText.length;
    double x = 0;
    double y = 0;

    // 用来保存一行单词的信息
    List<WordData> wordRectListTemp = [];

    for (int i = 0; i < count; ++i) {
      bool isEndWrap = false;
      String tempText = '${wordText[i]} ';
//      debugPrint('$_tag, 获得单词 $tempText');
      if (tempText.indexOf('\n') != -1) {
//        debugPrint('$_tag, 需要换行');
        if (tempText.indexOf('\n') == 0) {
          // 开头换行
//          debugPrint('$_tag, 开头需要换行, 计算后 y : ${y + textHeight}');
          y += textHeight;
          x = 0;
          wordRectList.add(wordRectListTemp);
          wordRectListTemp = [];
          if (tempText.length == 2) {
//            debugPrint('$_tag, 直接换行');
            continue;
          }
        } else {
          // 结尾换行
//          debugPrint('$_tag, 结尾需要换行');
          isEndWrap = true;
        }
        tempText = tempText.replaceAll('\n', '');
      }

      double wordWidth = _getWordWidth(tempText);
      if (x + wordWidth > size.width) {
//        debugPrint('$_tag, 超出宽度了, x : $x, wordWidth: $wordWidth, sizeWidth: ${size.width}, y : ${y + textHeight}');
        x = 0;
        y += textHeight;
        wordRectList.add(wordRectListTemp);
        wordRectListTemp = [];
      }
      int wordCount = tempText.length;
      for (int j = 0; j < wordCount; ++j) {
        String subString = tempText.substring(j, j + 1);
        double offsetX = painterWithMap[subString];
//        debugPrint('$_tag, subString: $subString, offsetX: $offsetX, x : $x, y : $y');
        TextPainter(
            text: TextSpan(text: subString, style: textStyle), textDirection: TextDirection.ltr)
          ..layout()
          ..paint(canvas, Offset(x, y));
        x += offsetX;
      }
      Rect rect = Rect.fromLTWH(x - wordWidth, y, wordWidth - _getWordWidth(' '), textHeight);
      wordRectListTemp.add(WordData(text: tempText.trim(), wordRect: rect));

      if (isEndWrap) {
        x = 0;
        y += textHeight;
        wordRectList.add(wordRectListTemp);
        wordRectListTemp = [];
//        debugPrint('$_tag, 结尾将数据高度补足, x : $x, wordWidth: $wordWidth, sizeWidth: ${size.width}, y : $y');
      }
    }
    if (wordRectListTemp.isNotEmpty) {
      wordRectList.add(wordRectListTemp);
    }
    if (wordRectListCallback != null) {
      wordRectListCallback(wordRectList);
    }
  }

  @override
  bool shouldRepaint(BookPainter oldDelegate) {
    return systemColor != oldDelegate.systemColor ||
        lightRectList != oldDelegate.lightRectList ||
        isSelectedMode != oldDelegate.isSelectedMode;
  }
}

class WordData {
  WordData({@required this.text, @required this.wordRect});

  final String text;
  final Rect wordRect;

  @override
  String toString() {
    return '单词: $text, 位置信息: l : ${wordRect.left}, t : ${wordRect.top}, w : ${wordRect.width}, h : ${wordRect.height}';
  }
}
