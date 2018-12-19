import 'package:flutter/material.dart';
import 'package:flutter_html_view/html_parser.dart';

class HtmlView extends StatefulWidget {
  final String data;
  final EdgeInsetsGeometry padding;
  final String baseURL;
  final Function onLaunchFail;
  final String fontFamily;
  final bool isForceSize;
  final double fontScale;
  final double paragraphScale;

  HtmlView({this.data, this.padding = const EdgeInsets.all(5.0),
    this.baseURL, this.onLaunchFail,
    this.fontFamily, this.isForceSize,
    this.fontScale:1.0,this.paragraphScale:1.0,
    Key key}):super(key:key);

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
  double paragraphScale;
  List<Widget> nodes;

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
    this.paragraphScale = widget.paragraphScale;
  }

  @override
  void dispose() {
    super.dispose();
  }

  void updateFont({double fontScale, double paragraphScale}){
    setState(() {
      nodes = null;
      if(fontScale != null){
        this.fontScale = fontScale;
      }
      if(paragraphScale != null){
        this.paragraphScale = paragraphScale;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('building HtmlView...');
    HtmlParser htmlParser = new HtmlParser(baseUrl: this.baseURL,
        onLaunchFail: this.onLaunchFail, fontFamily: this.fontFamily,
        isForceSize: this.isForceSize,
        fontScale: this.fontScale,
        paragraphScale:this.paragraphScale);
    if(nodes == null){
      debugPrint('creating nodes...');
      nodes= htmlParser.parseHTML(this.data);
    }

    return new Container(
        color: Colors.transparent,
        width: double.infinity,
        padding: padding,
        child: new Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: nodes,
        ));
  }

}