import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

class GarmentStudioPage extends StatefulWidget {
  const GarmentStudioPage({super.key});
  @override
  State<GarmentStudioPage> createState() => _GarmentStudioPageState();
}

class _GarmentStudioPageState extends State<GarmentStudioPage> {
  late final WebViewController _controller;

  Future<void> _loadStudio() async {
    if (kIsWeb) {
      final html = await rootBundle.loadString('assets/garment_studio/index.html');
      await _controller.loadHtmlString(html);
      return;
    }
    await _controller.loadFlutterAsset('assets/garment_studio/index.html');
  }
  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF08070B));
    unawaited(_loadStudio());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CLO / Gerber Studio — 3D'), actions: [
        IconButton(
            onPressed: () => _controller
                .runJavaScript('window.resetGarment && window.resetGarment();'),
            icon: const Icon(Icons.refresh)),
      ]),
      body: WebViewWidget(controller: _controller),
    );
  }
}
