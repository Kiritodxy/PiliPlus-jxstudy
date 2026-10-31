import 'dart:convert' show jsonDecode;
import 'dart:io' show Platform;

import 'package:PiliPlus/http/browser_ua.dart';
import 'package:PiliPlus/main.dart';
import 'package:PiliPlus/plugin/linux_webview.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class GeetestWebviewDialog extends StatefulWidget {
  const GeetestWebviewDialog(this.gt, this.challenge, {super.key});

  final String gt;
  final String challenge;

  @override
  State<GeetestWebviewDialog> createState() => _GeetestWebviewDialogState();

  static Future<Map<String, dynamic>?> geetest(String gt, String challenge) {
    return showDialog<Map<String, dynamic>>(
      context: Get.context!,
      builder: (context) => GeetestWebviewDialog(gt, challenge),
    );
  }
}

class _GeetestWebviewDialogState extends State<GeetestWebviewDialog> {
  static const _geetestJsUri =
      'https://static.geetest.com/static/js/fullpage.0.0.0.js';
  static const _geetestConfigUri = 'https://api.geetest.com/gettype.php';

  static String _buildHtml(String gt, String challenge) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final js =
        'var C,S,T,t;'
        'T=()=>{if(C&&S&&!t){t=Geetest(C).onSuccess(()=>R("success",t.getValidate())).onError(o=>R("error",o)).onClose(o=>R("close",o));t.onReady(()=>t.verify())}};'
        'geetest_$ts=(d)=>{'
        'if(!d||d.status!="success"){'
        'F("验证码加载失败（"+((d&&(d.error_code||d.error))||"?")+"）\\n请点右上角关闭后重试");'
        'R("error",JSON.stringify(d));return};'
        'C=Object.assign({gt:"$gt",challenge:"$challenge",offline:false,new_captcha:true,product:"bind",width:"100%",https:true,protocol:"https://"},d.data);T()'
        '};'
        'G=()=>{S=1;T()};'
        'F=(m)=>{var e=document.getElementById("E");if(e){e.textContent=m;e.style.display="flex"}};'
        'E=()=>{F("验证码资源加载失败\\n请检查网络后重试");R("error","geetest script load failed")};'
        'setTimeout(()=>{if(!t){F("验证码加载超时\\n请点右上角关闭后重试");R("error","geetest timeout")}},10000);';

    return '<!DOCTYPE html><html><head><meta name="viewport" content="width=device-width"></head>'
        '<style>#E{position:fixed;inset:0;display:none;align-items:center;justify-content:center;'
        'color:#c0392b;font-size:15px;line-height:1.7;text-align:center;white-space:pre-line;padding:24px}</style>'
        '<body><div id="E"></div>'
        '<script>'
        '${Platform.isLinux ? "R=(n,o)=>window.webkit.messageHandlers.msgToNative.postMessage(n+':'+JSON.stringify(o))" : "R=(n,o)=>window.flutter_inappwebview?.callHandler(n,o)"};$js'
        '</script>'
        '<script src="$_geetestJsUri" onload="G()" onerror="E()"></script>'
        '<script src="$_geetestConfigUri?gt=$gt&callback=geetest_$ts" onerror="E()"></script>'
        '</body></html>';
  }

  @override
  Widget build(BuildContext context) {
    final html = _buildHtml(widget.gt, widget.challenge);

    if (Platform.isLinux) {
      return AlertDialog(
        title: const Text('验证码'),
        content: SizedBox(
          width: 300,
          height: 400,
          child: LinuxWebview(
            initialHtml: html,
            userAgent: BrowserUa.mob,
            incognito: true,
            onWebMessageReceived: (msg) {
              final msgStr = msg.toString();
              if (msgStr.startsWith("success:")) {
                final dataStr = msgStr.substring("success:".length);
                try {
                  final data = jsonDecode(dataStr);
                  Get.back(result: data);
                } catch (e) {
                  debugPrint('geetest decode error: $e');
                }
              } else if (msgStr.startsWith("error:")) {
                debugPrint('geetest error: $msgStr');
              } else if (msgStr.startsWith('close:')) {
                Get.back();
              }
            },
          ),
        ),
      );
    }

    return Stack(
      children: [
        InAppWebView(
          webViewEnvironment: webViewEnvironment,
          initialSettings: InAppWebViewSettings(
            clearCache: true,
            javaScriptEnabled: true,
            forceDark: ForceDark.AUTO,
            useHybridComposition: true,
            algorithmicDarkeningAllowed: true,
            useShouldOverrideUrlLoading: true,
            userAgent: BrowserUa.mob,
            mixedContentMode: .MIXED_CONTENT_ALWAYS_ALLOW,

            // 定制版：极验在 incognito + initialData 组合下会出现渲染空白，
            // 这里去掉 incognito（无登录态，不影响隐私），并开启存储/缓存
            allowFileAccess: false,
            allowsLinkPreview: false,
            allowContentAccess: false,
            useOnDownloadStart: false,
            geolocationEnabled: false,
            thirdPartyCookiesEnabled: false,
            enterpriseAuthenticationAppLinkPolicyEnabled: false,
            saveFormData: false,
            safeBrowsingEnabled: false,
            isFraudulentWebsiteWarningEnabled: false,
            domStorageEnabled: true,
            databaseEnabled: true,
            cacheEnabled: true,
            cacheMode: .LOAD_DEFAULT,

            horizontalScrollBarEnabled: false,
            verticalScrollBarEnabled: false,
            overScrollMode: .NEVER,

            pageZoom: Platform.isIOS ? 3 : 1,
          ),
          initialData: InAppWebViewInitialData(data: html),
          // 定制版：把 WebView 内部错误打印出来，便于定位白屏
          onReceivedError: (ctr, req, err) {
            debugPrint('geetest onReceivedError: ${err.type} ${err.description}');
            SmartDialog.showToast('验证码加载失败：${err.description}');
          },
          onConsoleMessage: (ctr, msg) {
            debugPrint('geetest console: ${msg.message}');
          },
          onWebViewCreated: (ctr) {
            ctr
              ..addJavaScriptHandler(
                handlerName: 'success',
                callback: (args) {
                  if (args.isNotEmpty) {
                    if (args[0] case Map<String, dynamic> data) {
                      Get.back(result: data);
                      return;
                    }
                  }
                  debugPrint('geetest invalid result: $args');
                },
              )
              ..addJavaScriptHandler(
                handlerName: 'error',
                callback: (args) {
                  debugPrint('geetest error: $args');
                },
              )
              ..addJavaScriptHandler(
                handlerName: 'close',
                callback: (args) => Get.back(),
              );
          },
        ),
        Positioned(
          left: 8,
          top: 8,
          child: IconButton(
            icon: const Icon(Icons.close),
            onPressed: Get.back,
            tooltip: '关闭',
          ),
        ),
      ],
    );
  }
}
