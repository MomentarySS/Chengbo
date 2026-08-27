import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';

import '../../core/utils/log.dart';

/// 断网判定与给用户看的文案。不负责发请求，只解释连通性结果。
abstract final class NetworkStatusLogic {
  static const banner = '当前没有网络';
  static const listMessage = '当前没有网络';
  static const listDetail = '连上 Wi-Fi 或移动数据后再试';
  static const playFailed = '当前没有网络，无法播放';
  static const testFailed = '当前没有网络，无法测试连接';
  static const skipProbeHint = '当前没有网络，已显示本地电台，未检测直播源';

  static bool isOffline(List<ConnectivityResult> results) {
    if (results.isEmpty) return true;
    return results.length == 1 && results.first == ConnectivityResult.none;
  }

  static String loadFailureMessage(String onlineMessage, {required bool offline}) {
    return offline ? listMessage : onlineMessage;
  }

  static String loadFailureDetail(Object error, {required bool offline}) {
    if (offline) return listDetail;
    return humanize(error);
  }

  static String humanize(Object error) {
    if (error is DioException) return fromDio(error);
    return '$error';
  }

  static String fromDio(DioException error) {
    final code = error.response?.statusCode;
    switch (code) {
      case 400:
        return '源站拒绝了请求（HTTP 400）。境外 RSS 请打开系统代理后再刷新';
      case 401:
      case 403:
        return '源站拒绝访问（HTTP $code）';
      case 402:
        return '源站要求付费或登录（HTTP 402），暂时订不了';
      case 404:
        return '找不到这个地址（HTTP 404），请核对后再试';
      case 429:
        return '请求太频繁（HTTP 429），请稍后再试';
      case 451:
        return '源站因法律原因不可用（HTTP 451）';
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '连接超时。境外地址请打开系统代理后再试';
      case DioExceptionType.connectionError:
        return '连不上源站。请检查网络或系统代理';
      case DioExceptionType.badResponse:
        if (code != null && code >= 500) return '源站出错（HTTP $code）';
        if (code != null) return '源站返回 HTTP $code';
        return '源站拒绝了请求';
      default:
        return '读取失败';
    }
  }
}

class NetworkMonitor {
  NetworkMonitor({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  Future<bool> get isOffline async {
    try {
      return NetworkStatusLogic.isOffline(await _connectivity.checkConnectivity());
    } catch (error, stackTrace) {
      AppLog.e('NetworkMonitor', 'checkConnectivity failed', error: error, stackTrace: stackTrace);
      return true;
    }
  }

  Stream<bool> changes() async* {
    yield await isOffline;
    yield* _connectivity.onConnectivityChanged.map(NetworkStatusLogic.isOffline);
  }
}
