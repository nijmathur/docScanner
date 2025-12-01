import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/encryption_service.dart';
import '../../../core/services/image_processing_service.dart';
import '../../../core/services/ocr_service.dart';
import '../../../core/services/audit_service.dart';
import '../../../core/services/session_service.dart';
import '../../../core/data/repositories_impl/document_repository_impl.dart';
import 'package:path_provider/path_provider.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  bool _isProcessing = false;

  Future<void> _scanDocument() async {
    try {
      // Launch flutter_doc_scanner to get scanned images
      dynamic scannedDocuments;
      try {
        scannedDocuments = await FlutterDocScanner().getScannedDocumentAsImages(page: 1);
      } on PlatformException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to scan document: ${e.message}')),
          );
        }
        return;
      }

      if (scannedDocuments == null || !mounted) {
        return;
      }

      setState(() {
        _isProcessing = true;
      });

      // Handle the scanned document - it could be a String path or List of paths
      String? imagePath;
      if (scannedDocuments is String) {
        imagePath = scannedDocuments;
      } else if (scannedDocuments is List && scannedDocuments.isNotEmpty) {
        imagePath = scannedDocuments.first.toString();
      }

      if (imagePath != null && imagePath.isNotEmpty) {
        await _processAndSaveDocument(imagePath);

        if (mounted) {
          Navigator.pop(context, true); // Return true to indicate success
        }
      } else {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No document scanned')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error scanning document: $e')),
        );
      }
    }
  }

  Future<void> _processAndSaveDocument(String imagePath) async {
    try {
      final databaseService = context.read<DatabaseService>();
      final encryptionService = context.read<EncryptionService>();
      final auditService = context.read<AuditService>();
      final sessionService = context.read<SessionService>();

      // Get the DEK from the current session
      final dataEncryptionKey = sessionService.dataEncryptionKey;
      if (dataEncryptionKey == null) {
        throw Exception('No active session. Please re-authenticate.');
      }

      final appDir = await getApplicationDocumentsDirectory();
      final documentsStoragePath = '${appDir.path}/documents';

      final repository = DocumentRepositoryImpl(
        databaseService: databaseService,
        encryptionService: encryptionService,
        imageProcessingService: ImageProcessingService(),
        ocrService: OCRService(),
        auditService: auditService,
        documentsStoragePath: documentsStoragePath,
        dataEncryptionKey: dataEncryptionKey,
      );

      await repository.createDocument(
        imagePath: imagePath,
        title: 'Document ${DateTime.now().toString().substring(0, 16)}',
        documentType: 'General',
        tags: [],
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Document'),
      ),
      body: _isProcessing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Processing document...'),
                ],
              ),
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.document_scanner,
                    size: 120,
                    color: Theme.of(context).primaryColor.withOpacity(0.5),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Tap the button to scan',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Position the document in the frame',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  ElevatedButton.icon(
                    onPressed: _scanDocument,
                    icon: const Icon(Icons.camera_alt, size: 28),
                    label: const Text('Start Scan'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 48,
                        vertical: 16,
                      ),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
