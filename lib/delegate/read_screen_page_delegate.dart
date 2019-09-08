
/// 读书翻页所对应的接口类
abstract class ReadScreenPageDelegate {
  /// 是否有下一张章节
  bool isNextChapter();
  /// 是否有上一张章节
  bool isLastChapter();
  /// 页数变化
  void onChangePageCount(int pageCount);
  /// 保存当前页数内容
  void onSavePageIndex(int pageIndex);
  /// 跳转上一章节的最后一页
  void toLastChapter();
  /// 跳转下一章节的第一页
  void toNextChapter();
  /// 加载
  void onChangeLoadingState(bool isLoading);
}