import 'package:flutter/material.dart';

/// ページネーション付きリストビュー
/// 大量データを表示する際にページ分割して描画負荷を軽減する
class PaginatedListView<T> extends StatefulWidget {
  /// 全データリスト
  final List<T> items;

  /// 1ページあたりの表示件数（デフォルト: 20）
  final int pageSize;

  /// 各アイテムのウィジェットビルダー
  final Widget Function(BuildContext context, T item, int index) itemBuilder;

  /// データが空の場合に表示するウィジェット
  final Widget? emptyWidget;

  /// ヘッダーウィジェット（リストの先頭に表示）
  final Widget? header;

  const PaginatedListView({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.pageSize = 20,
    this.emptyWidget,
    this.header,
  });

  @override
  State<PaginatedListView<T>> createState() => _PaginatedListViewState<T>();
}

class _PaginatedListViewState<T> extends State<PaginatedListView<T>> {
  int _displayCount = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _displayCount = widget.pageSize;
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant PaginatedListView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // アイテムが変わったらリセット
    if (oldWidget.items != widget.items) {
      _displayCount = widget.pageSize;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// スクロール末尾に近づいたら次のページを読み込む
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _loadMore() {
    if (_displayCount < widget.items.length) {
      setState(() {
        _displayCount =
            (_displayCount + widget.pageSize).clamp(0, widget.items.length);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return widget.emptyWidget ?? const Center(child: Text('データがありません'));
    }

    final visibleItems = widget.items.take(_displayCount).toList();
    final hasMore = _displayCount < widget.items.length;

    return ListView.builder(
      controller: _scrollController,
      itemCount: visibleItems.length +
          (widget.header != null ? 1 : 0) +
          (hasMore ? 1 : 0),
      itemBuilder: (ctx, index) {
        // ヘッダー
        if (widget.header != null && index == 0) {
          return widget.header!;
        }

        final adjustedIndex = widget.header != null ? index - 1 : index;

        // 読み込みインジケーター
        if (adjustedIndex >= visibleItems.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        return widget.itemBuilder(
          ctx,
          visibleItems[adjustedIndex],
          adjustedIndex,
        );
      },
    );
  }
}

/// ページネーション情報を表示するヘッダー
class PaginationHeader extends StatelessWidget {
  final int totalCount;
  final int displayCount;

  const PaginationHeader({
    super.key,
    required this.totalCount,
    required this.displayCount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            '全$totalCount件',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (displayCount < totalCount) ...[
            const SizedBox(width: 8),
            Text(
              '（$displayCount件表示中）',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
