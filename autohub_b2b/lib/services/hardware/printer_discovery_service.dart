import 'dart:async';
import 'dart:io';

import 'package:network_info_plus/network_info_plus.dart';

/// Host that answered on the raw TCP port used by ESC/POS and most XPrinter Wi‑Fi units.
class DiscoveredPrinterHost {
  const DiscoveredPrinterHost({
    required this.ip,
    this.port = 9100,
    this.connectTime,
  });

  final String ip;
  final int port;
  final Duration? connectTime;

  @override
  String toString() => '$ip:$port';
}

/// Outcome of a subnet sweep (for UI messaging).
class PrinterDiscoveryResult {
  const PrinterDiscoveryResult({
    required this.hosts,
    this.deviceIpv4,
    this.subnetPrefix,
    this.warning,
  });

  final List<DiscoveredPrinterHost> hosts;
  final String? deviceIpv4;
  final String? subnetPrefix;
  final String? warning;
}

/// Scans the LAN /24 for open [port] (default 9100) using the device Wi‑Fi IPv4.
///
/// Runs work in parallel batches so the isolate stays responsive; UI should still
/// call this from an async handler (not inside build).
class PrinterDiscoveryService {
  PrinterDiscoveryService({NetworkInfo? networkInfo})
      : _networkInfo = networkInfo ?? NetworkInfo();

  final NetworkInfo _networkInfo;
  bool _cancel = false;

  /// Stop an in-flight [discoverPrinters] as soon as the current batch finishes.
  void cancel() {
    _cancel = true;
  }

  /// Resolves the phone/tablet IPv4 on Wi‑Fi, builds `a.b.c.*`, then probes each host.
  ///
  /// [perHostTimeout] keeps the sweep fast on dead IPs.
  /// [batchSize] limits parallel [Socket.connect] calls (balance RTTs vs memory).
  Future<PrinterDiscoveryResult> discoverPrinters({
    int port = 9100,
    Duration perHostTimeout = const Duration(milliseconds: 450),
    int batchSize = 48,
    void Function(int completed, int total)? onProgress,
  }) async {
    _cancel = false;

    final deviceIp = await _networkInfo.getWifiIP();
    final gatewayIp = await _networkInfo.getWifiGatewayIP();

    final ipv4 = deviceIp ??
        await _firstIpv4FromInterfaces() ??
        (gatewayIp != null ? _parseIpv4(gatewayIp) : null);

    if (ipv4 == null) {
      return const PrinterDiscoveryResult(
        hosts: [],
        warning:
            'Не удалось определить IPv4 Wi‑Fi. Подключитесь к сети или укажите IP вручную.',
      );
    }

    final parts = ipv4.split('.');
    if (parts.length != 4) {
      return PrinterDiscoveryResult(
        hosts: [],
        deviceIpv4: ipv4,
        warning: 'Ожидался IPv4 (a.b.c.d), получено: $ipv4',
      );
    }

    final prefix = '${parts[0]}.${parts[1]}.${parts[2]}';
    final myLastOctet = int.tryParse(parts[3]) ?? -1;

    final octets = <int>[];
    for (var h = 1; h <= 254; h++) {
      if (h == myLastOctet) continue;
      octets.add(h);
    }

    final total = octets.length;
    final found = <DiscoveredPrinterHost>[];
    var completed = 0;

    onProgress?.call(0, total);

    for (var i = 0; i < octets.length; i += batchSize) {
      if (_cancel) break;

      final slice = octets.skip(i).take(batchSize).toList();
      final futures = slice.map((host) async {
        final ip = '$prefix.$host';
        final sw = Stopwatch()..start();
        final ok = await _probePort(ip, port, perHostTimeout);
        sw.stop();
        if (!ok) return null;
        return DiscoveredPrinterHost(
          ip: ip,
          port: port,
          connectTime: sw.elapsed,
        );
      });

      final batch = await Future.wait(futures);
      completed += slice.length;
      onProgress?.call(completed, total);
      for (final r in batch) {
        if (r != null) found.add(r);
      }
    }

    found.sort((a, b) => a.ip.compareTo(b.ip));

    return PrinterDiscoveryResult(
      hosts: found,
      deviceIpv4: ipv4,
      subnetPrefix: '$prefix.0/24',
      warning: deviceIp == null && gatewayIp != null
          ? 'IP устройства недоступен; подсеть взята из шлюза. При неверных результатах проверьте Wi‑Fi.'
          : null,
    );
  }

  Future<bool> _probePort(String ip, int port, Duration timeout) async {
    Socket? socket;
    try {
      socket = await Socket.connect(
        InternetAddress(ip),
        port,
        timeout: timeout,
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      try {
        await socket?.close();
      } catch (_) {}
    }
  }

  String? _parseIpv4(String s) {
    final p = s.trim().split('.');
    if (p.length != 4) return null;
    if (p.every((e) => int.tryParse(e) != null)) return s;
    return null;
  }

  /// Fallback when the plugin returns null (emulator, VPN quirks, permissions).
  Future<String?> _firstIpv4FromInterfaces() async {
    try {
      final list = await NetworkInterface.list(
        includeLinkLocal: false,
        type: InternetAddressType.IPv4,
      );
      for (final ni in list) {
        for (final addr in ni.addresses) {
          if (addr.type != InternetAddressType.IPv4) continue;
          final s = addr.address;
          if (_isNonLoopbackLanIPv4(s)) return s;
        }
      }
    } catch (_) {}
    return null;
  }

  bool _isNonLoopbackLanIPv4(String ip) {
    if (ip.startsWith('127.') || ip == '0.0.0.0') return false;
    final p = ip.split('.');
    if (p.length != 4) return false;
    final a = int.tryParse(p[0]) ?? 0;
    // Typical private ranges for warehouse Wi‑Fi / hotspot
    if (a == 10) return true;
    if (a == 172) {
      final b = int.tryParse(p[1]) ?? 0;
      return b >= 16 && b <= 31;
    }
    if (a == 192 && (int.tryParse(p[1]) ?? 0) == 168) return true;
    return false;
  }
}
