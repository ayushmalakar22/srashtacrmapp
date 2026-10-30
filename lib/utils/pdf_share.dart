import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api_service.dart';

/// Downloads a document PDF (`invoice_pdf` / `estimate_pdf`) and opens the
/// phone's share sheet with the real file attached, so it can go straight to
/// WhatsApp, Gmail, Drive etc.
Future<void> shareDocumentPdf(
  BuildContext context, {
  required String endpoint, // 'invoice_pdf' or 'estimate_pdf'
  required String id,
  required String fileName, // without .pdf
  String? text,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  void toast(String m) => messenger.showSnackBar(SnackBar(content: Text(m)));
  toast('Preparing PDF...');
  try {
    final token = await ApiService.getToken();
    final res = await http
        .get(Uri.parse('${ApiService.baseUrl}/$endpoint/$id?token=$token'))
        .timeout(const Duration(seconds: 30));
    final isPdf = res.bodyBytes.length > 4 &&
        String.fromCharCodes(res.bodyBytes.take(4)) == '%PDF';
    if (res.statusCode != 200 || !isPdf) {
      messenger.hideCurrentSnackBar();
      return toast('Could not create the PDF');
    }
    final safe = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final file = File('${(await getTemporaryDirectory()).path}/$safe.pdf');
    await file.writeAsBytes(res.bodyBytes, flush: true);
    messenger.hideCurrentSnackBar();
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: fileName,
      text: text,
    );
  } catch (_) {
    messenger.hideCurrentSnackBar();
    toast('Cannot reach the server. Check Wi-Fi and try again.');
  }
}
