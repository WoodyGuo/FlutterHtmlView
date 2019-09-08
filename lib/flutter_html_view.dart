import 'package:flutter/material.dart';
import 'package:draggable_scrollbar/draggable_scrollbar.dart';
import 'package:flutter_html_view/html_parser.dart';

/// 返回需要包装的组件
typedef BuildTextSpanWidget = Widget Function(TextSpan textSpan);

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
  List<Widget> nodes;
  ScrollController _controller;

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
    debugPrint('HtmlView initState ...');
  }

  @override
  void dispose() {
    super.dispose();
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
    setState(() {
      if (tails != null && nodes != null) {
        nodes.removeRange(nodes.length - tails.length, nodes.length);
      }
      this.tails = tails;
      nodes?.addAll(tails);
    });
  }

  void updateData(String data) {
    if (mounted) {
      setState(() {
        this.data = data;
        nodes = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('building HtmlView...');
    HtmlParser htmlParser = HtmlParser(
      baseUrl: this.baseURL,
      onLaunchFail: this.onLaunchFail,
      fontFamily: this.fontFamily,
      isForceSize: this.isForceSize,
      fontScale: this.fontScale,
      paragraphScale: this.lineSpace,
      buildTextSpanWidget: widget.buildTextSpanWidget,
    );
    if (nodes == null) {
      debugPrint('creating nodes... tails length: ${tails?.length}');
      nodes = [];
      htmlParser.parseHTML(this.data, nodes, null);
      if (tails != null) {
        nodes.addAll(tails);
      }
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
  }
}
