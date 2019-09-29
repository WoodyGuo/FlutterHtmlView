import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html_view/html_parser.dart';
import 'package:flutter_html_view/delegate/read_screen_page_delegate.dart';
import 'book_painter.dart';
import 'triangle_painter.dart';
import 'dart:math' as math;

/// 返回需要包装的组件
typedef BuildTextSpanWidget = Widget Function(TextSpan textSpan);

String _tag = 'HtmlView';

/// 菜单工具点击类型
enum _ToolBarClickType {
  translateType,
  copyType,
}

class HtmlView extends StatefulWidget {
  final String data;
  final EdgeInsetsGeometry padding;
  final String baseURL;
  final Function onLaunchFail;
  final String fontFamily;
  final bool isForceSize;
  final double fontScale;
  final double lineSpace;
  final ValueChanged<String> onSelectedStringCallback;

  /// 是否是翻页模式
  final bool isPageMode;

  /// 阅读翻页的接口
  final ReadScreenPageDelegate readScreenPageDelegate;

  /// 阅读页数百分比 0~1
  final double pageIndexProgress;

  HtmlView(
      {this.data,
      this.padding = const EdgeInsets.all(5.0),
      this.baseURL,
      this.onLaunchFail,
      this.fontFamily,
      this.isForceSize,
      this.fontScale: 1.0,
      this.lineSpace: 1.0,
      this.onSelectedStringCallback,
      this.isPageMode: false,
      this.readScreenPageDelegate,
      this.pageIndexProgress: 0.0,
      Key key})
      : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return HtmlViewState();
  }
}

class HtmlViewState extends State<HtmlView> {
  String data;
  EdgeInsetsGeometry padding;
  String baseURL;
  Function onLaunchFail;
  String fontFamily;
  bool isForceSize;
  double fontScale;
  double lineSpace;
  bool needScroll;
  List nodes;
  bool _isPageMode;

  /// 页面的宽度
  double _pageWidth;

  /// 页面的高度
  double _pageHeight;
  List<TextSpan> _textSpanList = [];
  PageController _pageController;

  /// 页数百分比
  double _pageIndexProgress;

  /// 是否预览改变字体行间距
  bool _isPreviewFont = false;

  /// 用来保存首次进入的值
  double _saveFontScale;
  double _saveLineSpace;

  /// 字体的高度更具key来取，key就是字符
  Map<String, double> _fontHeightMap = {};
  double _textHeight = 0;

  /// 用来保存单词位置信息
  Map<int, List<List<WordData>>> _wordRectListMap = {};

  /// 点击下的点
  Point<double> _touchDown;

  /// 点击弹起的点
  Point<double> _touchUp;

  /// 高亮矩形
  Map<int, List<Rect>> _lightRectMap = {};

  /// 是否是选中模式
  Map<int, bool> _isSelectedModeMap = {};

  @override
  void initState() {
    super.initState();
    this.data = widget.data;
    this.padding = widget.padding;
    this.baseURL = widget.baseURL;
    this.onLaunchFail = widget.onLaunchFail;
    this.fontFamily = widget.fontFamily;
    this.isForceSize = widget.isForceSize;
    this.fontScale = widget.fontScale;
    _saveFontScale = widget.fontScale;
    _saveLineSpace = widget.lineSpace;
    this.lineSpace = widget.lineSpace;
    _isPageMode = widget.isPageMode;
    _pageIndexProgress = widget.pageIndexProgress;
    debugPrint('HtmlView initState ...');
  }

  @override
  void dispose() {
    super.dispose();
    _pageController?.dispose();
    _pageController = null;
  }

  /// 改变
  void onChangeDarkThem() {
    setState(() {
//      nodes = null;
    });
  }

  void updateFont({double fontScale, double lineSpace, bool isPreviewFont}) {
    debugPrint(
        '$_tag, fontScale : $fontScale, lineSpace : $lineSpace, isPreviewFont $isPreviewFont');
    setState(() {
      _isPreviewFont = isPreviewFont;

//      if (!isPreviewFont || !_isPageMode) {
      nodes = null;
      if (_isPageMode) {
        _pageController?.dispose();
      }
      _pageController = null;

      if (fontScale != null) {
        _saveFontScale = fontScale;
      }
      if (lineSpace != null) {
        _saveLineSpace = lineSpace;
      }
//      }
      if (fontScale != null) {
        this.fontScale = fontScale;
      }
      if (lineSpace != null) {
        this.lineSpace = lineSpace;
      }
    });
  }


  /// 调转page方法
  void onChangePageIndex(int index) {
    debugPrint('$_tag 需要跳转到: $index, 实际跳转为 ${_getPageIndexCheckChapter(index)}');
    _pageController.jumpToPage(_getPageIndexCheckChapter(index));
  }

  void updateData(String data, {double pageIndexProgress: -1}) {
    if (mounted) {
      setState(() {
        this.data = data;
        if (_isPageMode) {
          _pageController?.dispose();
        }
        _pageController = null;

        if (pageIndexProgress >= 0) {
          _pageIndexProgress = pageIndexProgress;
        }
        nodes = null;
      });
    }
  }

  /// 用来获取page的实际显示内容,
  ///
  /// 例如 page count 是5页
  /// 如果有上一章节 +1
  int _getPageIndexCheckChapter(int pageIndex) {
    if (widget.readScreenPageDelegate != null) {
      return pageIndex + (widget.readScreenPageDelegate.isLastChapter() ? 1 : 0);
    }
    return pageIndex;
  }

  /// 根据品台显示不同的加载样式
  Widget _getPlatformLoadingIndicator(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 40,
        child: Theme.of(context).platform == TargetPlatform.iOS
            ? CupertinoActivityIndicator()
            : CircularProgressIndicator(),
      ),
    );
  }

  double _getTextWidthWithCharSubString(String text, TextStyle textStyle) {
    int count = text.length;
    double width = 0;
    for (int i = 0; i < count; ++i) {
      String temp = text.substring(i, i + 1);
      if (_fontHeightMap[temp] != null) {
        width += _fontHeightMap[temp];
      } else {
        var painter = TextPainter(
          text: TextSpan(text: temp, style: textStyle),
          textDirection: TextDirection.ltr,
        );
        painter.layout(maxWidth: _pageWidth);
        _fontHeightMap.putIfAbsent(temp, () => painter.width /* + 0.5*/);
//        debugPrint('$_tag, 未找到的字符 $temp, with : ${painter.width}');
        width += painter.width;
      }
    }
    return width;
  }

  /// 获取文字的估计宽度
  double _getTextWidthWithChart(String text, TextStyle textStyle) {
    if (text.isEmpty) {
      return _getTextWidthWithCharSubString(' ', textStyle);
    } else if (text.indexOf('\n') != -1) {
      String temp = text.replaceAll('\n', '');
      return _getTextWidthWithCharSubString(temp, textStyle);
    }
    return _getTextWidthWithCharSubString(text, textStyle);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_pageWidth == null || _pageHeight == null) {
          _pageWidth = constraints.biggest.width;
          _pageHeight = constraints.biggest.height - 20;
        }
        if (nodes == null) {
          debugPrint('creating nodes... ');
          _fontHeightMap.clear();
          nodes = List<TextSpan>();
          _textSpanList.clear();
          _wordRectListMap.clear();
          _lightRectMap.clear();
          _isSelectedModeMap.clear();

          HtmlParser htmlParser = HtmlParser(
            buildContext: context,
            baseUrl: this.baseURL,
            onLaunchFail: this.onLaunchFail,
            fontFamily: this.fontFamily,
            isForceSize: this.isForceSize,
            fontScale: this.fontScale,
            paragraphScale: this.lineSpace,
            buildTextSpanWidget: null,
            isPageMode: _isPageMode,
          );

          htmlParser.parseHTML(this.data, _isPageMode ? null : nodes, !_isPageMode ? null : nodes);

          int count = nodes.length;
          int time = DateTime.now().millisecondsSinceEpoch;
          debugPrint('$_tag 获得 书本内容数目: $count, _pageHeight: $_pageHeight');
//          for (int i = 0; i < count; ++i) {
//            debugPrint('$_tag 获得 书本内容i : $i， 内容 :${(nodes[i] as TextSpan).text}');
//          }

          // 先计算一个文字的宽度和高度
          var textStyle = (nodes[0] as TextSpan).style;
          var textAPainter = TextPainter(
            text: TextSpan(text: 'A', style: textStyle),
            textDirection: TextDirection.ltr,
          );

          textAPainter.layout(maxWidth: _pageWidth);

          var textHeight = textAPainter.height;

          List<String> values = [
            'A',
            'B',
            'C',
            'D',
            'E',
            'F',
            'G',
            'H',
            'I',
            'J',
            'K',
            'L',
            'M',
            'N',
            'O',
            'P',
            'Q',
            'R',
            'S',
            'T',
            'U',
            'V',
            'W',
            'X',
            'Y',
            'Z'
          ];
          for (String value in values) {
            var painter = TextPainter(
              text: TextSpan(text: value, style: textStyle),
              textDirection: TextDirection.ltr,
            );
            painter.layout(maxWidth: _pageWidth);

//            debugPrint('$_tag, $value : ${painter.width}, ${painter.height}');
            _fontHeightMap.putIfAbsent(value, () => painter.width /* + 1*/ /* - 0.5*/);

            painter = TextPainter(
              text: TextSpan(text: value.toLowerCase(), style: textStyle),
              textDirection: TextDirection.ltr,
            );
            painter.layout(maxWidth: _pageWidth);

//            debugPrint('$_tag, ${value.toLowerCase()} : ${painter.width}, ${painter.height}');
            _fontHeightMap.putIfAbsent(
                value.toLowerCase(), () => painter.width /* + 1*/ /* - 0.41*/);
          }

          _textHeight = textHeight;
          // 其实的位置
          // 获得所有文案
          String text = '';
          for (int i = 0; i < count; ++i) {
            // 获得整个段落的文字
            String tempText = (nodes[i] as TextSpan).text;
            if (i == 0) {
              text = tempText;
            } else {
              text = '$text \n  $tempText';
            }
          }
//          debugPrint('$_tag, 获得 完成text ： $text');

          // 遍历整个文案
          List<String> textWordList = text.split(' ');
          var wordCount = textWordList.length;
          String wordText = '';

          // 剩余最大宽度
          double overWidth = _pageWidth;
          // 剩余最大高度
          double overHeight = _pageHeight;
          for (int i = 0; i < wordCount; ++i) {
            // 分割的每一个单词
            String tempText = '${textWordList[i]} ';

            bool isCheckWrapOrPage = true;
            bool isCheckWrapOrPageFromN = false;
            // 计算剩余内容宽度
            double offsetWith = _getTextWidthWithChart(tempText, textStyle);
            double overWithTemp = overWidth - offsetWith;
            // 有地方可以添加
            if (overWithTemp >= 0) {
              overWidth = overWithTemp;
              wordText = '$wordText$tempText';
              // 这里说明是段落换行 去检测换行换页方法
              isCheckWrapOrPage = tempText.indexOf('\n') != -1;
              isCheckWrapOrPageFromN = isCheckWrapOrPage;
            }

            if (isCheckWrapOrPage) {
              // 这里换行
              overHeight -= textHeight;
//              debugPrint('$_tag, $tempText : 换行 overWithTemp : $overWithTemp, overHeight : $overHeight');
              // 检查剩余空间是否允许换行，不行就要换页
              if (overHeight - textHeight >= 0) {
                // 可以换行
//                debugPrint(
//                    '$_tag, $tempText 换行, overWithTemp : $overWithTemp, isCheckWrapOrPageFromN : $isCheckWrapOrPageFromN');
                if (!isCheckWrapOrPageFromN) {
                  wordText = '$wordText$tempText';
                }
                overWidth = _pageWidth - offsetWith;
              } else {
                // 需要换页
//                debugPrint(
//                    '$_tag, $tempText : 换页了, overWithTemp : $overWithTemp, overHeight : $overHeight');

//                debugPrint('$_tag, 保存的数据 $wordText');
                _textSpanList.add(TextSpan(text: wordText, style: textStyle));
                overHeight = _pageHeight;
                if (isCheckWrapOrPageFromN) {
                  wordText = '';
                  overWidth = _pageWidth;
                } else {
                  overWidth = _pageWidth - offsetWith;
                  wordText = '$tempText';
                }
              }
            }

            if (i == wordCount - 1) {
              _textSpanList.add(TextSpan(text: wordText, style: textStyle));
            }
          }

          debugPrint(
              '$_tag 完成图书所用时间 ：${DateTime.now().millisecondsSinceEpoch - time} , 返回页数: ${_textSpanList.length}');
        }
        if (_textSpanList.isEmpty) {
          return Container(
            width: double.infinity,
            height: double.infinity,
          );
        } else {
          debugPrint('building HtmlView... _pageWidth : $_pageWidth, _pageHeight : $_pageHeight');
          // 页数
          int pageCount = _textSpanList.length;
          debugPrint('$_tag, 读书页数 : $pageCount');
          widget.readScreenPageDelegate.onChangePageCount(pageCount);
          //实际的页数 里面包含兼容问题偏移值 如果 _pageIndexProgress > 1 说明是兼容数据
          int pageIndex;
          if (_pageIndexProgress > 1.0) {
            // 这里是兼容数据 _pageIndexProgress 值代表滑动距离 用互动距离 / 文字高度 约等于 当前值
            int tempIndex = (_pageIndexProgress / _pageHeight).round();
            if (tempIndex > pageCount - 1) {
              tempIndex = pageCount - 1;
            }
            pageIndex = _getPageIndexCheckChapter(tempIndex);
          } else {
            pageIndex = _getPageIndexCheckChapter(
                ((pageCount - (_pageIndexProgress >= 1.0 ? 1 : 0)) * _pageIndexProgress).round());
          }

          debugPrint('$_tag, 当前显示页数 : $pageIndex, progress : $_pageIndexProgress');

          bool isLastChapter = widget.readScreenPageDelegate.isLastChapter();
          bool isNextChapter = widget.readScreenPageDelegate.isNextChapter();
          // pageCount 实际个数需要加上上一页和下一页的loading界面

          debugPrint('$_tag, isLastChapter : $isLastChapter, isNextChapter : $isNextChapter');
          pageCount = pageCount + (isLastChapter ? 1 : 0) + (isNextChapter ? 1 : 0);
          debugPrint('$_tag, 实际读书页数 加上上一页下一页 : $pageCount');

          debugPrint('$_tag, _pageController is Null : ${_pageController == null}');
          if (_pageController == null) {
            if (pageIndex == 0 && isLastChapter) {
              pageIndex = 1;
            } else if (pageIndex == pageCount - 1 && isNextChapter) {
              pageIndex -= 1;
            }

            debugPrint('$_tag, pageIndex : $pageIndex');

            _pageController = PageController(initialPage: pageIndex);

            SchedulerBinding.instance.addPostFrameCallback((duration) {
              _pageController.jumpToPage(pageIndex);
            });

          }

          return Container(
            child: PageView.builder(
              controller: _pageController,
              itemBuilder: (context, index) {
                debugPrint('$_tag, 创建index : $index');
                if (index == 0 && isLastChapter || index == pageCount - 1 && isNextChapter) {
                  // 加载视图
                  return _getPlatformLoadingIndicator(context);
                } else {
                  Color color = DefaultTextStyle.of(context).style.color;

                  TextSpan tempTextSpan = _textSpanList[index - (isLastChapter ? 1 : 0)];

                  String textTemp = tempTextSpan.text;

                  TextStyle tempTextSpanStyle = tempTextSpan.style;

                  TextStyle textStyleTemp = TextStyle(
                      height: tempTextSpanStyle.height,
                      fontFamily: tempTextSpanStyle.fontFamily,
                      color: color,
                      fontWeight: tempTextSpanStyle.fontWeight,
                      fontStyle: tempTextSpanStyle.fontStyle,
                      decoration: tempTextSpanStyle.decoration,
                      fontSize: tempTextSpanStyle.fontSize);

                  GlobalKey<_BookViewWidgetState> bookViewWidgetKey = GlobalKey();
                  GlobalKey<_ToolBarWidgetState> toolBarWidgetKey = GlobalKey();
                  return Stack(
                    children: <Widget>[
                      GestureDetector(
                        onTapDown: (details) {
                          _touchDown = Point(details.localPosition.dx, details.localPosition.dy);
                        },
                        onTapCancel: () {
                          _touchDown = null;
                          _touchUp = null;
                        },
                        onTapUp: (details) {
                          _touchUp = Point(details.localPosition.dx, details.localPosition.dy);
                        },
                        onTap: () {
                          WordData findWordData =
                              _getSelectedWordData(index, _touchDown?.x, _touchDown?.y);

                          _setSelectedWordDataToBookWidget(
                              index, [findWordData.wordRect], false, bookViewWidgetKey);

                          toolBarWidgetKey.currentState._setToolBarDisplay(false, null);

                          if (widget.onSelectedStringCallback != null) {
                            widget.onSelectedStringCallback(findWordData.text);
                          }
                          setState(() {});
                        },
                        onLongPressStart: (details) {
                          // 长安开始, 通知下方
                          WordData findWordData = _getSelectedWordData(
                              index, details.localPosition.dx, details.localPosition.dy);
                          if (findWordData.wordRect != null) {
                            _setSelectedWordDataToBookWidget(
                                index, [findWordData.wordRect], false, bookViewWidgetKey);
                          }
                          debugPrint('$_tag, onLongPressStart : ${details.toString()}');
                        },
                        onLongPressMoveUpdate: (details) {
                          _updateLongPress(index, details.localPosition.dx,
                              details.localPosition.dy, bookViewWidgetKey,
                              isSave: false);
                          debugPrint('$_tag, onLongPressMoveUpdate : $details');
                        },
                        onLongPressEnd: (details) {
                          // 长安弹起，找寻单词
                          _updateLongPress(index, details.localPosition.dx,
                              details.localPosition.dy, bookViewWidgetKey,
                              isSave: true);
                          toolBarWidgetKey.currentState
                              ._setToolBarDisplay(true, _lightRectMap[index][0]);

                          setState(() {});
                        },
                        onLongPressUp: () {
                          // 长安结束，通知下方，需要显示翻译和复制等操作
                          debugPrint('$_tag, onLongPressUp');
                        },
                        child: _BookViewWidget(
                          key: bookViewWidgetKey,
                          pageWidth: _pageWidth,
                          pageHeight: _pageHeight,
                          displayText: textTemp,
                          displayTextStyle: textStyleTemp,
                          fontHeightMap: _fontHeightMap,
                          textHeight: _textHeight,
                          systemColor: color,
                          lightRectList: _lightRectMap[index],
                          isSelectMode: _isSelectedModeMap[index] ?? false,
                          wordRectListCallback: (wordRectList) {
                            debugPrint('$_tag, 获得词典回调， index : $index');
                            _wordRectListMap.update(index, (value) => wordRectList,
                                ifAbsent: () => wordRectList);
//                            int rowCount = _wordRectList.length;
//                            debugPrint('$_tag, 总共有 $rowCount行文字');
//                            for (int i = 0; i < rowCount; ++i) 获得左右 {
//                              List<WordData> wordDataList = _wordRectList[i];
//                              int columnCount = wordDataList.length;
//                              debugPrint('$_tag, 第 $i 行文字 有 $columnCount 个单词');
//                              for (int j = 0; j < columnCount; ++j) {
//                                WordData wordData = wordDataList[j];
//                                debugPrint('$_tag, 第 $j 个单词信息 有 ${wordData.toString()}');
//                              }
//                            }
                          },
                        ),
                      ),
                      // 左边拖动条
                      _getScrollBar(index, bookViewWidgetKey, toolBarWidgetKey, isLeft: true),
                      // 右边拖动条
                      _getScrollBar(index, bookViewWidgetKey, toolBarWidgetKey, isLeft: false),
                      // 悬浮菜单
                      _ToolBarWidget(
                          key: toolBarWidgetKey,
                          isDisplay: _isSelectedModeMap[index] ?? false,
                          lightWordStartRect:
                              _lightRectMap[index] == null ? null : _lightRectMap[index][0],
                          toolBarClickTypeCallback: (toolBarClickType) {
                            // 现将数据取出来
                            // 首先获得第一行第一个单词
                            List<Rect> rectList = _lightRectMap[index];
                            int allRowCount = _wordRectListMap[index].length;
                            int rowCount = rectList.length;
                            Rect startRect = rectList[0];
                            int startRow = (startRect.top / _textHeight).floor();
                            // 最后一行最后一个单词
                            Rect endRect = rectList[rowCount - 1];
                            int endRow = (endRect.top / _textHeight).floor();
                            bool isCanAdd = false;

                            String selectWord;

                            for (int i = startRow; i < allRowCount; ++i) {
                              List<WordData> wordDataList = _wordRectListMap[index][i];
                              int wordCount = wordDataList.length;
                              for (int j = 0; j < wordCount; ++j) {
                                if (isCanAdd) {
                                  if (wordDataList[j].wordRect.left > endRect.right &&
                                      wordDataList[j].wordRect.top == endRect.top) {
                                    debugPrint(
                                        '$_tag, 检测出最后一个词: ${wordDataList[j].text}, 最终词： $selectWord');
                                    break;
                                  }
                                  selectWord = '$selectWord${wordDataList[j].text} ';
                                } else if (wordDataList[j]
                                        .wordRect
                                        .contains(Offset(startRect.left, startRect.top)) ||
                                    wordDataList[j].wordRect.left >= startRect.right) {
                                  selectWord = '${wordDataList[j].text} ';
                                  isCanAdd = true;
                                }
                              }
                              if (endRow == i) {
                                break;
                              }
                            }

                            debugPrint('$_tag, 获得了选中的文案: $selectWord');

                            switch (toolBarClickType) {
                              case _ToolBarClickType.copyType:
                                Clipboard.setData(new ClipboardData(text: selectWord.trim()));
                                break;
                              case _ToolBarClickType.translateType:
                                if (widget.onSelectedStringCallback != null) {
                                  widget.onSelectedStringCallback(selectWord.trim());
                                }
                                break;
                              default:
                                break;
                            }
                            _setSelectedWordDataToBookWidget(index, null, false, bookViewWidgetKey);
                            setState(() {});
                          }),
                    ],
                  );
                }
              },
              onPageChanged: (index) {
                if (index == 0 && isLastChapter) {
                  // 加载上一张
                  widget.readScreenPageDelegate.toLastChapter();
                } else if (index == pageCount - 1 && isNextChapter) {
                  // 加载下一张
                  widget.readScreenPageDelegate.toNextChapter();
                } else {
                  int pageIndex = index - (isLastChapter ? 1 : 0);
                  widget.readScreenPageDelegate.onSavePageIndex(pageIndex);
                  _pageIndexProgress = pageIndex / pageCount;
                }
              },
              itemCount: pageCount,
            ),
          );
        }
      },
    );
  }

  /// 设置数据的高亮区域和 是否选中状态
  void _setSelectedWordDataToBookWidget(int index, List<Rect> lightRectList, bool isSelectedMode,
      GlobalKey<_BookViewWidgetState> bookViewWidgetKey,
      {bool isSave: true}) {
    if (isSave) {
      _isSelectedModeMap.update(index, (value) => isSelectedMode, ifAbsent: () => isSelectedMode);
      _lightRectMap.update(index, (value) => lightRectList, ifAbsent: () => lightRectList);
    }
    bookViewWidgetKey.currentState.setLightRect(lightRectList, isSelectedMode);
  }

  /// 返回查找的但单词和数据
  WordData _getSelectedWordData(int index, double x, double y) {
    if (x == null || y == null) {
      return WordData(text: '', wordRect: null);
    }
    WordData findWordData;
    if (_wordRectListMap[index] != null && _wordRectListMap[index].isNotEmpty) {
      List<List<WordData>> wordRectList = _wordRectListMap[index];
      int row = (y / _textHeight).floor();
//      debugPrint('$_tag, 点击了第 $row 行 ');
      if (row <= wordRectList.length - 1) {
        List<WordData> wordDataList = wordRectList[row];
        int columnCount = wordDataList.length;
        for (int i = 0; i < columnCount; ++i) {
          WordData wordData = wordDataList[i];
          if (wordData.wordRect.contains(Offset(x, y))) {
//            debugPrint('$_tag, 找到了单词 : ${wordData.text}');
            findWordData = wordData;
            break;
          }
        }
      }
    }
    if (findWordData == null) {
      findWordData = WordData(text: '', wordRect: null);
    }
    return findWordData;
  }

  /// 更新选中数据
  void _updateLongPress(
      int index, double x, double y, GlobalKey<_BookViewWidgetState> bookViewWidgetKey,
      {bool isSave: false}) {
    if (x <= 0) {
      x = 0;
    } else if (x > _pageWidth) {
      x = _pageWidth;
    }

    if (y <= 0) {
      y = 0;
    } else if (y >= _pageHeight) {
      y = _pageHeight;
    }

    if (_lightRectMap[index] != null) {
      // 这里不寻找，这里只是显示背景区域
      Rect curRect = _lightRectMap[index][0];
      // 这个是当前选中的那个起始单词行数
      int curRow = (curRect.top / _textHeight).floor();

      int moveRow = (y / _textHeight).floor();
      WordData findWord = _getSelectedWordData(index, x, y);
      Rect tempRect;
      // 没有找到对应单词
      if (findWord.wordRect == null) {
        tempRect = Rect.fromLTWH(x, moveRow * _textHeight, 1, _textHeight);
      } else {
        tempRect = findWord.wordRect;
      }

      List<Rect> listRect = [];
      if (curRow == moveRow) {
        // 左右滑动
        if (x < curRect.left) {
          // 说明向左移动
          listRect.add(Rect.fromLTRB(
              math.min(curRect.left, tempRect.left), curRect.top, curRect.left, curRect.bottom));
        } else {
          // 向右边滑动
          listRect.add(Rect.fromLTRB(math.min(curRect.left, tempRect.left), curRect.top,
              math.max(curRect.right, tempRect.right), curRect.bottom));
        }
      } else if (curRow > moveRow) {
        //向上滑动
        int offsetRow = curRow - moveRow;
        // 从上往下计算
        int rowCount = offsetRow + 1;

        for (int i = 0; i < rowCount; ++i) {
          if (i == rowCount - 1) {
            // 最后一行
            listRect.add(Rect.fromLTRB(0, curRect.top, curRect.left, curRect.bottom));
          } else if (i == 0) {
            listRect.add(Rect.fromLTRB(tempRect.left, tempRect.top, _pageWidth, tempRect.bottom));
          } else {
            listRect.add(Rect.fromLTRB(
                0, tempRect.top + i * _textHeight, _pageWidth, tempRect.bottom + i * _textHeight));
          }
        }
      } else {
        // 向下滑动
        int offsetRow = moveRow - curRow;
        // 从上往下计算
        int rowCount = offsetRow + 1;
        for (int i = 0; i < rowCount; ++i) {
          if (i == 0) {
            // 当前行
            listRect.add(Rect.fromLTRB(curRect.left, curRect.top, _pageWidth, curRect.bottom));
          } else if (i == rowCount - 1) {
            //最后行
            listRect.add(Rect.fromLTRB(0, tempRect.top, tempRect.right, tempRect.bottom));
          } else {
            listRect.add(Rect.fromLTRB(
                0, curRect.top + i * _textHeight, _pageWidth, curRect.bottom + i * _textHeight));
          }
        }
      }
      _setSelectedWordDataToBookWidget(index, listRect, isSave, bookViewWidgetKey, isSave: isSave);
    }
  }

  /// 拖动拖动条更新,
  ///
  /// 这里需要注意几点
  /// 1。 左边的拖动条不能大于右边的拖动条
  /// 2 . 右边的拖动条不能小雨左边的拖动条
  /// 其他随意
  void _updateScrollBar(
      int index,
      double x,
      double y,
      GlobalKey<_BookViewWidgetState> bookViewWidgetKey,
      GlobalKey<_ToolBarWidgetState> toolBarWidgetKey,
      bool isLeft) {
    Point minPoint;
    Point maxPoint;

    toolBarWidgetKey.currentState._setToolBarDisplay(false, null);
    if (isLeft) {
      // 左边最小可以到0 ， 0, 最大可以到最后的 前一个
      Rect rect = _lightRectMap[index][_lightRectMap[index].length - 1];
      bool isOnlyOneRect = _lightRectMap[index].length == 1;
      minPoint = Point(0.0, 0.0);
      maxPoint = Point(rect.right - 12, rect.bottom);
      if (x < minPoint.x) {
        x = minPoint.x;
      } else if (x >= maxPoint.x && isOnlyOneRect) {
        x = maxPoint.x;
      }

      if (y < minPoint.y) {
        y = minPoint.y;
      } else if (y >= maxPoint.y) {
        y = maxPoint.y - 1;
      }
    } else {
      Rect rect = _lightRectMap[index][0];
      bool isOnlyOneRect = _lightRectMap[index].length == 1;
      minPoint = Point(rect.left + 12, rect.top);
      maxPoint = Point(_pageWidth, _pageHeight);
      if (x < minPoint.x && isOnlyOneRect) {
        x = minPoint.x;
      } else if (x >= maxPoint.x) {
        x = maxPoint.x;
      }

      if (y < minPoint.y) {
        y = minPoint.y;
      } else if (y >= maxPoint.y) {
        y = maxPoint.y - 1;
      }
    }

    // 这里不寻找，这里只是显示背景区域
    List<Rect> lightRowRectList = _lightRectMap[index];
    // 这个是当前选中的那个起始单词行数
    int rowRectCount = lightRowRectList.length;
    Rect curRect = isLeft ? lightRowRectList[0] : lightRowRectList[rowRectCount - 1];
    int curRow = (curRect.top / _textHeight).floor();
    int moveRow = (y / _textHeight).floor();
    WordData findWord = _getSelectedWordData(index, x, y);
    Rect tempRect;
    // 没有找到对应单词
    if (findWord.wordRect == null) {
      tempRect = Rect.fromLTWH(x, moveRow * _textHeight, 1, _textHeight);
    } else {
      tempRect = findWord.wordRect;
    }

    // 这里开始拖动根据左右来判定
    List<Rect> listRect = [];
    if (curRow == moveRow) {
      // 左右滑动
      if (x < (isLeft ? curRect.left : curRect.right)) {
        // 说明向左移动
        if (isLeft) {
          // 第一个做添加
          listRect.add(Rect.fromLTRB(x, curRect.top, curRect.right, curRect.bottom));
          for (int i = 1; i < rowRectCount; ++i) {
            listRect.add(lightRowRectList[i]);
          }
        } else {
          // 添加前行数据
          for (int i = 0; i < rowRectCount - 1; ++i) {
            listRect.add(lightRowRectList[i]);
          }
          debugPrint(
              '$_tag, 右侧向左滑动, curRect : ${curRect.toString()}, tempRect : ${tempRect.toString()}');
          listRect.add(Rect.fromLTRB(
              math.min(curRect.left, x), curRect.top, math.min(curRect.right, x), curRect.bottom));
        }
      } else {
        // 向右边滑动
        if (isLeft) {
          debugPrint(
              '$_tag, 左侧向右滑动, curRect : ${curRect.toString()}, tempRect : ${tempRect.toString()}');
          listRect.add(Rect.fromLTRB(x, curRect.top, curRect.right, curRect.bottom));
          for (int i = 1; i < rowRectCount; ++i) {
            listRect.add(lightRowRectList[i]);
          }
        } else {
          for (int i = 0; i < rowRectCount - 1; ++i) {
            listRect.add(lightRowRectList[i]);
          }
          listRect.add(Rect.fromLTRB(
              math.min(curRect.left, x), curRect.top, math.max(curRect.right, x), curRect.bottom));
        }
      }
    } else if (curRow > moveRow) {
      //向上滑动
      int offsetRow = curRow - moveRow;
      if (isLeft) {
        listRect.add(Rect.fromLTRB(x, tempRect.top, _pageWidth, tempRect.bottom));
        for (int i = 0; i < offsetRow - 1; ++i) {
          listRect.add(Rect.fromLTRB(
              0, tempRect.top + i * _textHeight, _pageWidth, tempRect.bottom + i * _textHeight));
        }
        // 原来的第 0 行数据
        listRect.add(Rect.fromLTRB(0, curRect.top, curRect.right, curRect.bottom));
        // 保存原始数据
        for (int i = 1; i < rowRectCount; ++i) {
          listRect.add(lightRowRectList[i]);
        }
      } else {
        // 保存原始数据
        for (int i = 0; i < rowRectCount - offsetRow - 1; ++i) {
          listRect.add(lightRowRectList[i]);
        }
        // 保存最后数据
        if (rowRectCount == 2) {
          listRect.add(Rect.fromLTRB(lightRowRectList[0].left, tempRect.top, x, tempRect.bottom));
        } else {
          listRect.add(Rect.fromLTRB(curRect.left, tempRect.top, tempRect.right, tempRect.bottom));
        }
      }
    } else {
      // 向下滑动
      int offsetRow = moveRow - curRow;
      if (isLeft) {
        // 获得那一行的数据
        Rect startRect = lightRowRectList[offsetRow];
        listRect.add(Rect.fromLTRB(x, tempRect.top, startRect.right, tempRect.bottom));
        for (int i = offsetRow + 1; i < rowRectCount; ++i) {
          listRect.add(lightRowRectList[i]);
        }
      } else {
        for (int i = 0; i < rowRectCount - 1; ++i) {
          listRect.add(lightRowRectList[i]);
        }
        //保存最后一个数据
        listRect.add(Rect.fromLTRB(curRect.left, curRect.top, _pageWidth, curRect.bottom));

        for (int i = 0; i < offsetRow - 1; ++i) {
          listRect.add(Rect.fromLTRB(
              0, curRect.top + i * _textHeight, _pageWidth, curRect.bottom + i * _textHeight));
        }
        // 保存新的移动数据
        listRect.add(Rect.fromLTRB(0, tempRect.top, tempRect.right, tempRect.bottom));
      }
    }
    _setSelectedWordDataToBookWidget(index, listRect, true, bookViewWidgetKey, isSave: true);
  }

  /// 开始修正选中状态的背景内容
  void _checkWordRectList(int index, GlobalKey<_BookViewWidgetState> bookViewWidgetKey,
      GlobalKey<_ToolBarWidgetState> toolBarWidgetKey, bool isLeft) {
    List<Rect> rect = _lightRectMap[index];
    if (rect != null && rect.isNotEmpty) {
      // 查第一行的第一个单词
      WordData wordData;
      Rect saveRect;
      if (isLeft) {
        Rect firstRect = rect[0];
        wordData = _getSelectedWordData(index, firstRect.left, firstRect.top);
        if (wordData.wordRect != null) {
          saveRect = Rect.fromLTRB(
              wordData.wordRect.left, wordData.wordRect.top, firstRect.right, firstRect.bottom);
          rect.removeAt(0);
          rect.insert(0, saveRect);
        }
      } else {
        // 查最后一行的最后一个单词
        int lastIndex = rect.length - 1;
        Rect lastRect = rect[lastIndex];
        wordData = _getSelectedWordData(index, lastRect.right, lastRect.top);
        if (wordData.wordRect != null) {
          saveRect = Rect.fromLTRB(math.min(lastRect.left, wordData.wordRect.left),
              wordData.wordRect.top, wordData.wordRect.right, wordData.wordRect.bottom);
          rect.removeAt(lastIndex);
          rect.add(saveRect);
        }
      }
      toolBarWidgetKey.currentState._setToolBarDisplay(true, rect[0]);
    }
  }

  /// 获得拖动的组件
  Widget _getScrollBar(int index, GlobalKey<_BookViewWidgetState> bookViewWidgetKey,
      GlobalKey<_ToolBarWidgetState> toolBarWidgetKey,
      {bool isLeft}) {
    // 是否英藏
    bool isOffstage = _lightRectMap[index] == null ||
        _isSelectedModeMap[index] == null ||
        !_isSelectedModeMap[index];
    double marginLeft;
    double marginTop;
    if (isOffstage) {
      marginTop = 0;
      marginLeft = 0;
    } else {
      if (isLeft) {
        Rect rect = _lightRectMap[index][0];
        marginLeft = rect.left - anchorPointWith / 2;
        marginTop = rect.top;
      } else {
        Rect rect = _lightRectMap[index][_lightRectMap[index].length - 1];
        marginLeft = rect.right - anchorPointWith / 2;
        marginTop = rect.top;
      }
    }

    if (marginLeft < 0) {
      marginLeft = 0;
    }

//    debugPrint('$_tag, 获得左右 ? $isLeft , marginLeft : $marginLeft, marginTop : $marginTop');

    return Offstage(
      offstage: isOffstage,
      child: isOffstage
          ? Container(
              width: 1,
              height: 1,
            )
          : GestureDetector(
              onTapDown: (details) {},
              onTapUp: (details) {},
              onTapCancel: () {},
              onLongPressStart: (details) {},
              onLongPressMoveUpdate: (details) {
                _updateScrollBar(index, details.localPosition.dx, details.localPosition.dy,
                    bookViewWidgetKey, toolBarWidgetKey, isLeft);
              },
              onLongPressEnd: (details) {},
              onLongPressUp: () {
                _checkWordRectList(index, bookViewWidgetKey, toolBarWidgetKey, isLeft);
                setState(() {});
              },
              onHorizontalDragDown: (details) {},
              onHorizontalDragCancel: () {},
              onHorizontalDragStart: (details) {},
              onHorizontalDragUpdate: (details) {
                _updateScrollBar(index, details.localPosition.dx, details.localPosition.dy,
                    bookViewWidgetKey, toolBarWidgetKey, isLeft);
              },
              onHorizontalDragEnd: (details) {
                debugPrint('$_tag >>>>>>>>>>, onHorizontalDragEnd');
                _checkWordRectList(index, bookViewWidgetKey, toolBarWidgetKey, isLeft);
                setState(() {});
              },
              onVerticalDragStart: (details) {
                debugPrint('$_tag >>>>>>>>>>, onVerticalDragStart');
              },
              onVerticalDragEnd: (details) {
                debugPrint('$_tag >>>>>>>>>>, onVerticalDragEnd');
                _checkWordRectList(index, bookViewWidgetKey, toolBarWidgetKey, isLeft);
                setState(() {});
              },
              onVerticalDragUpdate: (details) {
                _updateScrollBar(index, details.localPosition.dx, details.localPosition.dy,
                    bookViewWidgetKey, toolBarWidgetKey, isLeft);
              },
              onVerticalDragCancel: () {
                debugPrint('$_tag >>>>>>>>>>, onVerticalDragCancel');
              },
              child: Container(
                margin: EdgeInsets.only(left: marginLeft, top: marginTop),
                width: anchorPointWith,
                height: _textHeight,
                color: Colors.transparent,
              ),
            ),
    );
  }
}

/// 阅读的界面 组件
class _BookViewWidget extends StatefulWidget {
  _BookViewWidget(
      {@required this.pageWidth,
      @required this.pageHeight,
      @required this.displayText,
      @required this.displayTextStyle,
      @required this.fontHeightMap,
      @required this.textHeight,
      @required this.systemColor,
      @required this.wordRectListCallback,
      @required this.lightRectList,
      @required this.isSelectMode,
      key: Key})
      : super(key: key);

  /// 绘制 的宽高
  final double pageWidth;
  final double pageHeight;

  /// 显示的书的内容
  final String displayText;

  /// 现实的字体样式
  final TextStyle displayTextStyle;

  /// 每个字体的大小map
  final Map<String, double> fontHeightMap;

  /// 每个字符的高度
  final double textHeight;

  /// 系统的颜色
  final Color systemColor;

  /// 返回单词位置信息等内容回调
  final ValueChanged<List<List<WordData>>> wordRectListCallback;

  /// 高亮矩形
  final List<Rect> lightRectList;

  /// 是否是选中模式
  final bool isSelectMode;

  @override
  State<StatefulWidget> createState() {
    return _BookViewWidgetState();
  }
}

/// 阅读的界面state
class _BookViewWidgetState extends State<_BookViewWidget> {
  List<Rect> _lightRectList;
  bool _isSelectMode = false;

  @override
  void initState() {
    _lightRectList = widget.lightRectList;
    _isSelectMode = widget.isSelectMode;
    super.initState();
  }

  @override
  void didUpdateWidget(_BookViewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.displayText != widget.displayText ||
        oldWidget.displayTextStyle != widget.displayTextStyle ||
        oldWidget.fontHeightMap != widget.fontHeightMap ||
        oldWidget.textHeight != widget.textHeight ||
        oldWidget.systemColor != widget.systemColor ||
        oldWidget.isSelectMode != widget.isSelectMode ||
        oldWidget.lightRectList != widget.lightRectList) {
      setState(() {});
    }
  }

  void setLightRect(List<Rect> lightRectList, bool isSelectMode) {
    setState(() {
      _lightRectList = lightRectList;
      _isSelectMode = isSelectMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(widget.pageWidth, widget.pageHeight),
      painter: BookPainter(
          text: widget.displayText,
          textStyle: widget.displayTextStyle,
          painterWithMap: widget.fontHeightMap,
          textHeight: widget.textHeight,
          wordRectListCallback: widget.wordRectListCallback,
          systemColor: widget.systemColor,
          lightRectList: _lightRectList,
          isSelectedMode: _isSelectMode),
    );
  }
}

/// 翻译工具组件
class _ToolBarWidget extends StatefulWidget {
  _ToolBarWidget(
      {@required this.isDisplay,
      @required this.lightWordStartRect,
      @required this.toolBarClickTypeCallback,
      key: Key})
      : super(key: key);

  /// 点击回调
  final ValueChanged<_ToolBarClickType> toolBarClickTypeCallback;

  /// 是否可以显示
  final bool isDisplay;

  /// 第一行位置，用来确定菜单位置
  final Rect lightWordStartRect;

  @override
  State<StatefulWidget> createState() {
    return _ToolBarWidgetState();
  }
}

/// 菜单工具state
class _ToolBarWidgetState extends State<_ToolBarWidget> {
  /// 是否可以显示
  bool _isDisplay = false;

  /// 第一行位置，用来确定菜单位置
  Rect _lightWordStartRect;

  @override
  void initState() {
    _isDisplay = widget.isDisplay;
    _lightWordStartRect = widget.lightWordStartRect;
    super.initState();
  }

  @override
  void didUpdateWidget(_ToolBarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDisplay != widget.isDisplay) {
      setState(() {
        _isDisplay = widget.isDisplay;
        _lightWordStartRect = widget.lightWordStartRect;
      });
    }
  }

  /// 设置菜单内容
  void _setToolBarDisplay(bool isDisplay, Rect lightWordStartRect) {
    if (_isDisplay != isDisplay) {
      setState(() {
        _isDisplay = isDisplay;
        _lightWordStartRect = lightWordStartRect;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('$_tag, 菜单是否显示 : $_isDisplay');
    if (!_isDisplay) {
      return Container(
        width: 1,
        height: 1,
      );
    } else {
      // 按钮的宽度
      double buttonWidth = 59;
      // 按钮的高度
      double buttonHeight = 40;
      // 三角箭头的宽度
      double triangleWidth = 17;
      // 三角箭头的高度
      double triangleHeight = 6;
      // 悬浮间距
      double offsetMarginTop = 10;
      // 分割线宽度
      double splitLineWidth = 1;
      // 分割线高度
      double splitLineHeight = 20;

      // 显示的左边距 和 上边距
      double marginTop = 0;
      double marginLeft = 0;

      double toolBarCount = 2;
      double toolBarWidth = buttonWidth * toolBarCount + splitLineWidth * (toolBarCount - 1);
      double toolBarHeight = buttonHeight + triangleHeight + offsetMarginTop;
      if (_lightWordStartRect != null) {
        Offset centerTop = _lightWordStartRect.topCenter;
        marginLeft = math.max(0, centerTop.dx - toolBarWidth / 2);
        marginTop = centerTop.dy - toolBarHeight;
      }

      return Container(
        margin: EdgeInsets.only(left: marginLeft, top: marginTop),
        width: toolBarWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: toolBarWidth,
                height: buttonHeight,
                color: Color(0xFF3A3A3C),
                child: Row(
                  children: <Widget>[
                    // 翻译按钮
                    Expanded(
                      child: _getButtonWidget('翻译', _ToolBarClickType.translateType),
                    ),
                    // 分割线
                    _getSplitLineWidget(splitLineWidth, splitLineHeight),
                    // 复制按钮
                    Expanded(
                      child: _getButtonWidget('复制', _ToolBarClickType.copyType),
                    ),
                  ],
                ),
              ),
            ),
            CustomPaint(
              size: Size(triangleWidth, triangleHeight),
              painter: TrianglePainter(),
            )
          ],
        ),
      );
    }
  }

  /// 返回分割线组件
  Widget _getSplitLineWidget(double lineWidth, double lineHeight) {
    return Container(
      width: lineWidth,
      height: double.infinity,
      alignment: Alignment.center,
      child: Container(
        width: lineWidth,
        height: lineHeight,
        color: Color(0x26FEFFFE),
      ),
    );
  }

  /// 返回菜单按钮组件
  Widget _getButtonWidget(String text, _ToolBarClickType callbackType) {
    return InkWell(
      onTap: () {
        if (widget.toolBarClickTypeCallback != null) {
          widget.toolBarClickTypeCallback(callbackType);
        }
        setState(() {
          _isDisplay = false;
        });
      },
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: Color(0xFFFFFFFF),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
