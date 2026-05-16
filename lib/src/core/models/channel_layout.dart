import 'dart:convert';

sealed class LayoutItem {
  const LayoutItem();
}

class CategoryItem extends LayoutItem {
  final String name;
  const CategoryItem(this.name);
}

class ChannelItem extends LayoutItem {
  final String channelId;
  const ChannelItem(this.channelId);
}

class SeparatorItem extends LayoutItem {
  const SeparatorItem();
}

List<LayoutItem> parseLayoutJson(String json) {
  final List<dynamic> items;
  try {
    items = jsonDecode(json) as List<dynamic>;
  } catch (_) {
    return [];
  }
  final layout = <LayoutItem>[];
  for (final item in items) {
    if (item is! Map<String, dynamic>) continue;
    switch (item['type']) {
      case 'category':
        final name = item['name'];
        if (name is String) layout.add(CategoryItem(name));
      case 'channel':
        final id = item['channel_id'];
        if (id is String) layout.add(ChannelItem(id));
      case 'separator':
        layout.add(const SeparatorItem());
    }
  }
  return layout;
}

String layoutToJson(List<LayoutItem> items) {
  return jsonEncode(items.map((item) {
    return switch (item) {
      CategoryItem(:final name) => {'type': 'category', 'name': name},
      ChannelItem(:final channelId) => {
          'type': 'channel',
          'channel_id': channelId,
        },
      SeparatorItem() => {'type': 'separator'},
    };
  }).toList());
}
