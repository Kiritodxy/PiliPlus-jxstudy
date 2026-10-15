import 'package:dio/dio.dart';

/// 定制版：GitHub 下载加速镜像的「取清单 → 探活 → 实测速度 → 择优」选择器。
///
/// 背景：镜像站点存活周期很短（实测中 gh-proxy.net 曾为首选，后返回 401 永久失效）。
/// 因此不写死单一列表，而是：
///   1) 优先实时抓取镜像清单页（手机实测直连 ~2.5s，无需翻墙）；
///   2) 抓不到时回退到内置的实测可用列表；
///   3) 并发探活，再对存活者下载小样本**按 MB/s 实测速度**；
///   4) 返回按速度降序的候选列表，下载时依次重试。
abstract final class MirrorPicker {
  /// 镜像清单页（节点为服务端渲染的纯文本，正则即可提取）
  static const String _listPage =
      'https://www.moretools.app/zh-CN/github-proxy';

  /// 内置实测可用列表（构建时逐一探测通过；页面抓取失败时兜底）
  static const List<String> builtIn = [
    'https://github.880824.xyz/',
    'https://ghproxy.net/',
    'https://git.820828.xyz/',
    'https://ghproxy.cxkpro.top/',
    'https://github.boringhex.top/',
    'https://ghproxy.imciel.com/',
    'https://ghproxy.xzhouqd.com/',
    'https://github.ihnic.com/',
    'https://github.788787.xyz/',
    'https://github.mlmle.cn/',
    'https://git.951959483.xyz/',
    'https://github.lsdfxdk.nyc.mn/',
    'https://github.1ms.xx.kg/',
    'https://gh.monlor.com/',
    'https://github.zzrbk.xyz/',
    'https://gh.idayer.com/',
    'https://gp.871201.xyz/',
    'https://github-proxy.memory-echoes.cn/',
    'https://github.dpik.top/',
    'https://hub.ddayh.com/',
    'https://gh.198962.xyz/',
    'https://gh.996986.xyz/',
    'https://gh.ddlc.top/',
    'https://gh.1k.ink/',
    'https://getgit.love8yun.eu.org/',
    'https://gh.halonice.com/',
    'https://gh.nxnow.top/',
    'https://github.cnxiaobai.com/',
    'https://gitproxy.mrhjx.cn/',
    'https://ggg.clwap.dpdns.org/',
    'https://free.cn.eu.org/',
    'https://gh.padao.fun/',
    'https://gh.chjina.com/',
    'https://ghproxy.sakuramoe.dev/',
    'https://gh.noki.icu/',
    'https://fastgit.cc/',
    'https://github.xxlab.tech/',
    'https://ghfast.top/',
    'https://gh.39.al/',
    'https://ghproxy.053000.xyz/',
    'https://proxy.baguoyuyan.com/',
    'https://jiashu.1win.eu.org/',
    'https://kenyu.ggff.net/',
    'https://ghm.078465.xyz/',
    'https://git.tangbai.cc/',
    'https://git.669966.xyz/',
    'https://github.chenc.dev/',
    'https://gh.shiina-rimo.cafe/',
    'https://g.blfrp.cn/',
    'https://30006000.xyz/',
    'https://ghp.keleyaa.com/',
    'https://ghproxy.mirror.skybyte.me/',
    'https://gh.dpik.top/',
    'https://gh.llkk.cc/',
    'https://github.crdz.eu.org/',
    'https://ghfile.geekertao.top/',
    'https://git.yylx.win/',
  ];

  /// 清单页里出现过的其余节点（内置列表全挂时再试）
  static const List<String> _pageNodes = [
    'https://gh-proxy.net/',
    'https://hub.gitmirror.com/',
    'https://www.5555.cab/',
    'https://ghproxy.xiaopa.cc/',
    'https://ghproxy.cfd/',
    'https://ghproxy.cc/',
    'https://ghproxy.monkeyray.net/',
    'https://cf.ghproxy.cc/',
    'https://gh.xxooo.cf/',
    'https://ghproxy.1888866.xyz/',
    'https://y.whereisdoge.work/',
    'https://gh.jdck.fun/',
    'https://xiaomo-station.top/',
    'https://gh.con.sh/',
    'https://gh.b52m.cn/',
    'https://github.geekery.cn/',
    'https://github.limoruirui.com/',
    'https://github.tbedu.top/',
    'https://ghproxy.vansour.top/',
    'https://tvv.tw/',
    'https://gh.catmak.name/',
    'https://github.ruojian.space/',
    'https://github-proxy.lixxing.top/',
    'https://gh.wsmdn.dpdns.org/',
    'https://gh-proxy.com/',
    'https://gp.zkitefly.eu.org/',
    'https://gh.bugdey.us.kg/',
    'https://code-hub-hk.freexy.top/',
    'https://github.bullb.net/',
    'https://gitproxy.197545.xyz/',
    'https://gitproxy.127731.xyz/',
    'https://gitproxy1.127731.xyz/',
    'https://ghproxy.mf-dust.dpdns.org/',
    'https://j.1lin.dpdns.org/',
    'https://gh.jasonzeng.dev/',
    'https://ghps.cc/',
    'https://github.tianrld.top/',
    'https://github-proxy.com/',
    'https://proxy.yaoyaoling.net/',
    'https://git.zeas.cc/',
    'https://ghpxy.hwinzniej.top/',
    'https://gh.echofree.xyz/',
    'https://github.ednovas.xyz/',
    'https://gh.chalin.tk/',
    'https://j.1win.ggff.net/',
    'https://gh.aaa.team/',
    'https://git.40609891.xyz/',
    'https://github.oterea.top/',
    'https://ghproxy.cn/',
    'https://down.npee.cn/',
    'https://github.kkproxy.dpdns.org/',
    'https://ghproxy.fangkuai.fun/',
    'https://github.cn86.dev/',
    'https://github.zjzzy.cloudns.org/',
    'https://ghb.nilive.top/',
    'https://gitproxy.click/',
    'https://proxy.atoposs.com/',
  ];

  /// 探活上限（只测前 N 个，避免把上百个节点全测一遍，浪费等待时间）
  static const int _probeLimit = 16;

  /// 实测速度的候选数上限
  static const int _speedLimit = 8;

  /// 测速样本大小（移动网络下取 512KB，兼顾准确度与流量）
  static const int _sampleBytes = 512 * 1024;

  static const Duration _probeTimeout = Duration(seconds: 6);
  static const Duration _speedTimeout = Duration(seconds: 15);
  static const Duration _listTimeout = Duration(seconds: 8);

  static List<String>? _cache;
  static DateTime? _cacheAt;

  /// 探针：APK 是 zip 包，头部魔数为 `PK\x03\x04`
  static bool _isZipHead(List<int>? d) =>
      d != null &&
      d.length >= 4 &&
      d[0] == 0x50 &&
      d[1] == 0x4B &&
      d[2] == 0x03 &&
      d[3] == 0x04;

  /// 取候选镜像列表（按实测速度降序）。[targetUrl] 为 GitHub 原始下载地址。
  static Future<List<String>> candidates(String targetUrl) async {
    // 缓存 10 分钟，避免同一版本反复点下载时重复测速
    final now = DateTime.now();
    if (_cache != null &&
        _cacheAt != null &&
        now.difference(_cacheAt!) < const Duration(minutes: 10)) {
      return _cache!;
    }

    final nodes = await _resolveNodes();
    if (nodes.isEmpty) return const [];

    // 阶段 1：并发探活（先测前 _probeLimit 个，全挂再测其余）
    var alive = await _probeAll(nodes.take(_probeLimit).toList(), targetUrl);
    if (alive.isEmpty && nodes.length > _probeLimit) {
      alive = await _probeAll(nodes.skip(_probeLimit).toList(), targetUrl);
    }
    if (alive.isEmpty) return const [];

    // 阶段 2：对存活者实测下载速度，按速度降序
    final speedList = alive.take(_speedLimit).toList();
    final scored = <String, double>{};
    await Future.wait(
      speedList.map((node) async {
        final mbps = await _measure(node, targetUrl);
        if (mbps != null) scored[node] = mbps;
      }),
    );
    final ordered = List<String>.from(speedList)
      ..sort((a, b) => (scored[b] ?? -1).compareTo(scored[a] ?? -1));
    // 探活通过但未参与测速的，排在最后
    ordered.addAll(alive.skip(_speedLimit));

    _cache = ordered;
    _cacheAt = now;
    return ordered;
  }

  /// 拼出某个镜像对应的完整下载地址
  static String link(String node, String githubUrl) => '$node$githubUrl';

  static Future<List<String>> _probeAll(
    List<String> nodes,
    String targetUrl,
  ) async {
    final alive = <String>[];
    await Future.wait(
      nodes.map((node) async {
        if (await _probe(node, targetUrl)) alive.add(node);
      }),
    );
    return alive;
  }

  /// 取清单：优先联网抓取，失败用内置列表
  static Future<List<String>> _resolveNodes() async {
    final online = await _fetchList();
    if (online.isNotEmpty) return online;
    return [...builtIn, ..._pageNodes];
  }

  /// 抓取清单页并提取节点（节点是 `<span class="... font-mono ...">https://xxx/</span>`）
  static Future<List<String>> _fetchList() async {
    try {
      final res = await Dio(
        BaseOptions(
          connectTimeout: _listTimeout,
          receiveTimeout: _listTimeout,
        ),
      ).get<String>(
        _listPage,
        options: Options(
          responseType: ResponseType.plain,
          headers: {'user-agent': 'Mozilla/5.0 (Linux; Android 13) Mobile'},
        ),
      );
      final html = res.data ?? '';
      if (html.isEmpty) return const [];
      final out = <String>[];
      final re = RegExp(r'font-mono[^>]*>(https?://[^<\s"]+)</span>');
      final valid = RegExp(r'^https://[a-zA-Z0-9.-]+(:\d+)?(/.*)?$');
      for (final m in re.allMatches(html)) {
        final raw = m.group(1)!;
        // 过滤畸形/非 ASCII 域名（抓取时偶发混入）
        if (!valid.hasMatch(raw)) continue;
        final node = raw.endsWith('/') ? raw : '$raw/';
        if (!out.contains(node)) out.add(node);
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  /// 探活：取 `bytes=0-3`，验证返回的是真实内容
  static Future<bool> _probe(String node, String target) async {
    try {
      final res = await Dio().get<List<int>>(
        link(node, target),
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Range': 'bytes=0-3'},
          followRedirects: true,
          receiveTimeout: _probeTimeout,
          sendTimeout: _probeTimeout,
        ),
      );
      return _isZipHead(res.data);
    } catch (_) {
      return false;
    }
  }

  /// 实测下载速度（MB/s）：取前 _sampleBytes 字节并计时；失败返回 null
  static Future<double?> _measure(String node, String target) async {
    try {
      final sw = Stopwatch()..start();
      final res = await Dio().get<List<int>>(
        link(node, target),
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Range': 'bytes=0-${_sampleBytes - 1}'},
          receiveTimeout: _speedTimeout,
          sendTimeout: _speedTimeout,
        ),
      );
      sw.stop();
      final data = res.data;
      if (!_isZipHead(data)) return null;
      final secs = sw.elapsedMilliseconds / 1000.0;
      if (secs <= 0) return null;
      return data!.length / 1024 / 1024 / secs;
    } catch (_) {
      return null;
    }
  }
}