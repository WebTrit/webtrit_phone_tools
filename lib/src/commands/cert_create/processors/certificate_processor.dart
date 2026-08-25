import 'dart:convert';
import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

class CertificateProcessor {
  const CertificateProcessor({required this.logger});

  final Logger logger;

  String readCertificateSigningRequest(String certificateSigningRequestPath) =>
      File(certificateSigningRequestPath).readAsStringSync();

  void writeCertificate({
    required String certificatePath,
    required String certificateContent,
  }) {
    logger.info('Writing certificate to: ${path.basename(certificatePath)}');
    File(certificatePath).writeAsBytesSync(base64.decode(certificateContent), flush: true);
  }
}
