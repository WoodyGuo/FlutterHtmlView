import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html_view/flutter_html_text.dart' as text;
import 'package:flutter_html_view/flutter_html_video.dart';
import 'package:flutter_html_view/flutter_html_view.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parse;
import 'package:video_player/video_player.dart';

class HtmlParser {
  String baseUrl;
  Function onLaunchFail;
  final String fontFamily;
  final bool isForceSize;
  double fontScale;
  double paragraphScale;
  final BuildTextSpanWidget buildTextSpanWidget;
  final bool isPageMode;
  final BuildContext buildContext;

  HtmlParser(
      {this.buildContext,
      this.baseUrl,
      this.onLaunchFail,
      this.fontFamily,
      this.isForceSize,
      this.fontScale,
      this.paragraphScale,
      this.buildTextSpanWidget,
      this.isPageMode: false});

  _parseChildren(dom.Element e, List<Widget>widgetList, List<TextSpan> textSpanList) {
//    print(e.localName);
    if (e.localName == "img" && e.attributes.containsKey('src')) {
      var src = e.attributes['src'];

      if (src.startsWith("http") || src.startsWith("https")) {
        if (!isPageMode) {
          widgetList.add(new CachedNetworkImage(
            imageUrl: src,
            fit: BoxFit.cover,
          ));
        }
      } else if (src.startsWith('data:image')) {
        if (!isPageMode) {
          var exp = new RegExp(r'data:.*;base64,');
          var base64Str = src.replaceAll(exp, '');
          var bytes = base64.decode(base64Str);
          widgetList.add(new Image.memory(bytes, fit: BoxFit.cover));
        }
      } else if (baseUrl != null && baseUrl.isNotEmpty && src.startsWith("/")) {
        if (!isPageMode) {
          widgetList.add(new CachedNetworkImage(
            imageUrl: baseUrl + src,
            fit: BoxFit.cover,
          ));
        }
      }
    } else if (e.localName == "video") {
      if (e.attributes.containsKey('src')) {
        if (!isPageMode) {
          var src = e.attributes['src'];
          // var videoElements = e.getElementsByTagName("video");
          widgetList.add(
            new NetworkPlayerLifeCycle(
              src,
              (BuildContext context, VideoPlayerController controller) =>
                  new AspectRatioVideo(controller),
            ),
          );
        }
      } else {
        if (!isPageMode) {
          if (e.children.length > 0) {
            e.children.forEach((dom.Element source) {
              try {
                if (source.attributes['type'] == "video/mp4") {
                  var src = e.children[0].attributes['src'];
                  widgetList.add(
                    new NetworkPlayerLifeCycle(
                      src,
                      (BuildContext context, VideoPlayerController controller) =>
                          new AspectRatioVideo(controller),
                    ),
                  );
                }
              } catch (e) {
                print(e);
              }
            });
          }
        }
      }
    } else if (!e.outerHtml.contains("<img") ||
        !e.outerHtml.contains("<video") ||
        !e.hasContent()) {
      if (!isPageMode) {
        widgetList.add(text.HtmlText(
          data: e.outerHtml,
          onLaunchFail: this.onLaunchFail,
          fontFamily: this.fontFamily,
          isForceSize: this.isForceSize,
          fontScale: this.fontScale,
          paragraphScale: this.paragraphScale,
          buildTextSpanWidget: this.buildTextSpanWidget,
        ));
      } else {
        text.HtmlParser textHtmlParser = text.HtmlParser(
            buildContext, this.fontFamily, this.isForceSize, this.fontScale, this.paragraphScale);
        List nodes = textHtmlParser.parse(e.outerHtml);
        List<TextSpan> textSpanListTemp = textHtmlParser.getToTextSpanWithNodesList(buildContext, nodes, null);
        textSpanList.addAll(textSpanListTemp.toList());
      }
    } else if (e.children.length > 0) e.children.forEach((e) => _parseChildren(e, widgetList, textSpanList));
  }

  void parseHTML(String html, List<Widget> widgetList, List<TextSpan>textSpanList) {
    dom.Document document = parse(html);

    dom.Element docBody = document.body;

    List<dom.Element> styleElements = docBody.getElementsByTagName("style");
    List<dom.Element> scriptElements = docBody.getElementsByTagName("script");
    if (styleElements.length > 0) {
      for (int i = 0; i < styleElements.length; i++) {
        docBody.getElementsByTagName("style").first.remove();
      }
    }
    if (scriptElements.length > 0) {
      for (int i = 0; i < scriptElements.length; i++) {
        docBody.getElementsByTagName("script").first.remove();
      }
    }

    List<dom.Element> docBodyChildren = docBody.children;
    if (docBodyChildren.length > 0) docBodyChildren.forEach((e) => _parseChildren(e, widgetList, textSpanList));
  }
}
