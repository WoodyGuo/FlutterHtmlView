import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:draggable_scrollbar/draggable_scrollbar.dart';
import 'package:flutter_html_view/html_parser.dart';
import 'package:flutter_html_view/delegate/read_screen_page_delegate.dart';

/// 返回需要包装的组件
typedef BuildTextSpanWidget = Widget Function(TextSpan textSpan);

String _tag = 'HtmlView';

class HtmlView extends StatefulWidget {
  final String data;
  final EdgeInsetsGeometry padding;
  final String baseURL;
  final Function onLaunchFail;
  final String fontFamily;
  final bool isForceSize;
  final double fontScale;
  final double lineSpace;
  final bool needScroll;
  final ScrollThumbBuilder scrollThumbBuilder;
  final ScrollController controller;
  final List<Widget> tails;
  final BuildTextSpanWidget buildTextSpanWidget;

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
      this.needScroll: false,
      this.scrollThumbBuilder,
      this.tails,
      this.controller,
      this.buildTextSpanWidget,
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
  ScrollThumbBuilder scrollThumbBuilder;
  List<Widget> tails;
  List nodes;
  ScrollController _controller;
  bool _isPageMode;

  /// 页面的宽度
  double _pageWidth;

  /// 页面的高度
  double _pageHeight;
  List<TextSpan> _textSpanList = [];
  PageController _pageController;

  /// 页数百分比
  double _pageIndexProgress;

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
    this.lineSpace = widget.lineSpace;
    this.needScroll = widget.needScroll;
    this.scrollThumbBuilder = widget.scrollThumbBuilder;
    this.tails = widget.tails;
    this._controller = widget.controller;
    _isPageMode = widget.isPageMode;
    _pageIndexProgress = widget.pageIndexProgress;
    debugPrint('HtmlView initState ...');
  }

  @override
  void dispose() {
    super.dispose();
    _pageController?.dispose();
  }

  /// 改变
  void onChangeDarkThem() {
    setState(() {
      nodes = null;
    });
  }

  void updateFont({double fontScale, double lineSpace}) {
    setState(() {
      nodes = null;
      if (fontScale != null) {
        this.fontScale = fontScale;
      }
      if (lineSpace != null) {
        this.lineSpace = lineSpace;
      }
    });
  }

  void updateTails(List<Widget> tails) {
    if (!_isPageMode) {
      setState(() {
        if (tails != null && nodes != null) {
          nodes.removeRange(nodes.length - tails.length, nodes.length);
        }
        this.tails = tails;
        nodes?.addAll(tails);
      });
    }
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
        if (_isPageMode && pageIndexProgress >= 0) {
          _pageController?.dispose();
          _pageController = null;
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_pageWidth == null || _pageHeight == null) {
          _pageWidth = constraints.biggest.width;
          _pageHeight = constraints.biggest.height;
        }

        debugPrint('building HtmlView... _pageWidth : $_pageWidth, _pageHeight : $_pageHeight');
        HtmlParser htmlParser = HtmlParser(
          buildContext: context,
          baseUrl: this.baseURL,
          onLaunchFail: this.onLaunchFail,
          fontFamily: this.fontFamily,
          isForceSize: this.isForceSize,
          fontScale: this.fontScale,
          paragraphScale: this.lineSpace,
          buildTextSpanWidget: widget.buildTextSpanWidget,
          isPageMode: _isPageMode,
        );

        if (nodes == null) {
          debugPrint('creating nodes... tails length: ${tails?.length}');
          if (_isPageMode) {
            nodes = List<TextSpan>();
            _textSpanList.clear();
          } else {
            nodes = List<Widget>();
          }

          htmlParser.parseHTML(this.data, _isPageMode ? null : nodes, !_isPageMode ? null : nodes);

          if (_isPageMode) {
            int count = nodes.length;
            int time = DateTime.now().millisecondsSinceEpoch;
            debugPrint('$_tag 获得 书本内容数目: $count');
            // 获得了所有的文案TextSpan ，进行计算
            // y的偏移量，用来合成段落
            List<Object> dataList = [0.0, null];
            // 是否创建文本列表
            for (int i = 0; i < count; ++i) {
              var item = nodes[i];
              if (item is TextSpan) {
                dataList = _onMeasure(item, dataList[1], dataList[0]);
              }
            }
            debugPrint('$_tag 完成图书所用时间 ：${DateTime.now().millisecondsSinceEpoch - time} ');
          }

          if (!_isPageMode && tails != null) {
            nodes.addAll(tails);
          }
        }

        if (_isPageMode) {
          // 页数
          int pageCount = _textSpanList.length;
          debugPrint('$_tag, 读书页数 : $pageCount');
          // 返回页数
          if (widget.readScreenPageDelegate != null) {
            widget.readScreenPageDelegate.onChangePageCount(pageCount);
          }
          //实际的页数 里面包含兼容问题偏移值 如果 _pageIndexProgress > 1 说明是兼容数据
          int pageIndex;
          if (_pageIndexProgress > 1) {
            // 这里是兼容数据 _pageIndexProgress 值代表滑动距离 用互动距离 / 文字高度 约等于 当前值
            int tempIndex = (_pageIndexProgress / _pageHeight).round();
            if (tempIndex > pageCount - 1) {
              tempIndex = pageCount - 1;
            }
            pageIndex = _getPageIndexCheckChapter(tempIndex);
          } else {
            pageIndex = _getPageIndexCheckChapter(
                ((pageCount - (_pageIndexProgress >= 1.0 ? 1 : 0)) * _pageIndexProgress).round()
            );
          }

          debugPrint('$_tag, 当前显示页数 : $pageIndex, progress : $_pageIndexProgress');
          if (_pageController == null) {
            _pageController = PageController(initialPage: pageIndex);
          }

          // pageCount 实际个数需要加上上一页和下一页的loading界面
          bool isLastChapter = widget.readScreenPageDelegate.isLastChapter();
          bool isNextChapter = widget.readScreenPageDelegate.isNextChapter();

          debugPrint('$_tag, isLastChapter : $isLastChapter, isNextChapter : $isNextChapter');
          pageCount = pageCount + (isLastChapter ? 1 : 0) + (isNextChapter ? 1 : 0);
          debugPrint('$_tag, 实际读书页数 加上上一页下一页 : $pageCount');

          return Container(
//            color: Colors.red,
            child: PageView.builder(
              controller: _pageController,
              itemBuilder: (context, index) {
                if (index == 0 && isLastChapter || index == pageCount - 1 && isNextChapter) {
                  // 加载视图
                  return _getPlatformLoadingIndicator(context);
                } else {
                  TextSpan textSpan = _textSpanList[index - (isLastChapter ? 1 : 0)];
                  return Container(
                    width: double.infinity,
                    height: double.infinity,
                    child: widget.buildTextSpanWidget != null
                        ? widget.buildTextSpanWidget(textSpan)
                        : RichText(
                            text: textSpan,
                          ),
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
                  widget.readScreenPageDelegate.onSavePageIndex(index - (isLastChapter ? 1 : 0));
                }
              },
              itemCount: pageCount,
            ),
          );
        }

        return needScroll
            ? DraggableScrollbar(
                controller: _controller,
                backgroundColor: Colors.grey,
                heightScrollThumb: 40.0,
                scrollThumbBuilder: scrollThumbBuilder != null
                    ? scrollThumbBuilder
                    : (
                        Color backgroundColor,
                        Animation<double> thumbAnimation,
                        Animation<double> labelAnimation,
                        double height, {
                        Text labelText,
                        BoxConstraints labelConstraints,
                      }) {
                        return FadeTransition(
                          opacity: thumbAnimation,
                          child: Container(
                            height: height,
                            width: 10.0,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10.0),
                              color: backgroundColor,
                            ),
                          ),
                        );
                      },
                child: ListView.builder(
                  controller: _controller,
                  padding: padding,
                  itemBuilder: (context, index) {
                    return nodes[index];
                  },
                  itemCount: nodes.length,
                ))
            : new Container(
                color: Colors.transparent,
                width: double.infinity,
                padding: padding,
                child: new Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: nodes,
                ));
      },
    );
  }

  /// 计算内容
  ///
  /// 返回的数据0 为offsetY 1 为 childrenList 可能为空
  List<Object> _onMeasure(TextSpan textSpan, List<TextSpan> childrenTextSpanList, double offsetY) {
    if (childrenTextSpanList == null) {
      debugPrint('$_tag 换页了 当前第 ${_textSpanList.length} 页');
      childrenTextSpanList = [];
      _textSpanList.add(TextSpan(children: childrenTextSpanList));
    }

    TextPainter textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );

    debugPrint('$_tag 获得字体大小 ${textSpan.style.fontSize}');

    String text = textSpan.text;
    if (_layout(text, textSpan.style, textPainter, offsetY)) {
      // 未超出
      debugPrint('$_tag 当前页数能够放下这个数据 : $text, 返回便宜高度 ${offsetY + textPainter.size.height}');
      // 在这里添加\n 和 换行 补差
      childrenTextSpanList.add(TextSpan(text: '${textSpan.text}\n', style: textSpan.style));
      return [
        offsetY +
            textPainter.size.height +
            (childrenTextSpanList.length == 1 ? textSpan.style.fontSize * lineSpace : 0),
        childrenTextSpanList
      ];
    } else {
      // 溢出了
      List<String> textList = text.split(' ');
      int start = 0;
      int end = textList.length;
      int mid = (end + start) ~/ 2;

      // 最多循环20次
      for (int i = 0; i < 20; i++) {
        debugPrint('$_tag 当前页数放不下这个数据检查 i : $i , start : $start, end: $end, mid : $mid');
        if (_layout(text.substring(0, _getLengthWithMid(textList, mid)), textSpan.style,
            textPainter, offsetY)) {
          if (mid <= start || mid >= end) {
            break;
          }
          // 未越界
          debugPrint('$_tag 当前页数放不下未越界');
          start = mid;
          mid = (start + end) ~/ 2;
        } else {
          // 越界
          debugPrint('$_tag 当前页数放不下越界');
          end = mid;
          mid = (start + end) ~/ 2;
        }
      }
      debugPrint('$_tag 当前页数放不下这个数据 : $text, start : $start, end: $end, mid : $mid');
      debugPrint('$_tag 截取字数: $mid, 文案 ${text.substring(0, _getLengthWithMid(textList, mid))}');
      if (mid != 0) {
        childrenTextSpanList.add(TextSpan(
            text: text.substring(0, _getLengthWithMid(textList, mid)), style: textSpan.style));
      }
      debugPrint('$_tag 剩余内容文案 : ${text.substring(_getLengthWithMid(textList, mid))}');
      return _onMeasure(
          TextSpan(
              text: text.substring(_getLengthWithMid(textList, mid)).trim(), style: textSpan.style),
          null,
          0);
    }
  }

  /// 计算待绘制文本
  /// 未超出边界返回true
  /// 超出边界返回false
  bool _layout(String text, TextStyle textStyle, TextPainter textPainter, double offsetY) {
    text = text ?? '';

    textPainter
      ..text = TextSpan(text: text, style: textStyle)
      ..layout(maxWidth: _pageWidth);
    return !_didExceed(textPainter, offsetY);
  }

  /// 是否超出边界
  bool _didExceed(TextPainter textPainter, double offsetY) {
    debugPrint('$_tag 获得文字高度 : ${textPainter.size.height},'
        ' offsetY: $offsetY, 剩余高度 ${_pageHeight - offsetY}');
    return textPainter.didExceedMaxLines || textPainter.size.height > _pageHeight - offsetY;
  }

  /// 根据mid 获取实际的单词长度内容
  int _getLengthWithMid(List<String> textList, int mid) {
    int length = 0;
    for (int i = 0; i < mid; ++i) {
      int textLength = textList[i].length;
      if (i == 0) {
        length = textLength;
      } else {
        length += textLength + 1;
      }
    }
    return length;
  }
}
