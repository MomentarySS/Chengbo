import '../models/radio_station.dart';

/// 电台列表/详情中显示的来源说明。
String? stationSourceLabel(RadioStation station) {
  if (station.source == StationSource.custom || station.tags.contains('自定义')) {
    return '来源：手动添加';
  }
  if (station.source == StationSource.api) {
    return '来源：网络发现';
  }
  return null;
}
