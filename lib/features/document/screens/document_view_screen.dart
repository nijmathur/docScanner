import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/domain/entities/document.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/audit_service.dart';

class DocumentViewScreen extends StatefulWidget {
  final String documentId;

  const DocumentViewScreen({
    super.key,
    required this.documentId,
  });

  @override
  State<DocumentViewScreen> createState() => _DocumentViewScreenState();
}

class _DocumentViewScreenState extends State<DocumentViewScreen> {
  Document? _document;
  bool _isLoading = true;
  bool _showOCR = false;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    try {
      final dbService = context.read<DatabaseService>();
      final auditService = context.read<AuditService>();

      final document = await dbService.getDocument(widget.documentId);

      if (document != null) {
        await auditService.logDocumentViewed(documentId: widget.documentId);
      }

      setState(() {
        _document = document;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading document: $e')),
        );
      }
    }
  }

  Future<void> _deleteDocument() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: const Text('Are you sure you want to delete this document?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final dbService = context.read<DatabaseService>();
        await dbService.deleteDocument(widget.documentId);

        if (mounted) {
          Navigator.pop(context, true); // Return true to indicate deleted
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting document: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Document')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_document == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Document')),
        body: const Center(child: Text('Document not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_document!.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // TODO: Implement edit functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Edit feature coming soon')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // TODO: Implement share functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share feature coming soon')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteDocument,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Document image placeholder
            Container(
              width: double.infinity,
              height: 300,
              color: Colors.grey.shade200,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.insert_drive_file,
                      size: 80,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Encrypted Document',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Document metadata
                  _buildMetadataCard(),
                  const SizedBox(height: 16),
                  // OCR text section
                  _buildOCRSection(),
                  const SizedBox(height: 16),
                  // Tags section
                  _buildTagsSection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Document Information',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Type', _document!.documentType),
            _buildInfoRow(
              'Captured',
              _formatDate(_document!.captureDate),
            ),
            _buildInfoRow(
              'Created',
              _formatDate(_document!.createdAt),
            ),
            if (_document!.updatedAt != null)
              _buildInfoRow(
                'Updated',
                _formatDate(_document!.updatedAt!),
              ),
            _buildInfoRow(
              'Size',
              '${(_document!.fileSizeBytes / 1024).toStringAsFixed(1)} KB',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOCRSection() {
    return Card(
      child: Column(
        children: [
          ListTile(
            title: const Text('OCR Text'),
            trailing: IconButton(
              icon: Icon(
                _showOCR ? Icons.expand_less : Icons.expand_more,
              ),
              onPressed: () {
                setState(() {
                  _showOCR = !_showOCR;
                });
              },
            ),
          ),
          if (_showOCR)
            Padding(
              padding: const EdgeInsets.all(16),
              child: _document!.ocrText.isNotEmpty
                  ? SelectableText(
                      _document!.ocrText,
                      style: Theme.of(context).textTheme.bodyMedium,
                    )
                  : Text(
                      'No OCR text available',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildTagsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tags',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _document!.tags.isEmpty
                ? Text(
                    'No tags',
                    style: TextStyle(color: Colors.grey.shade600),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _document!.tags
                        .map((tag) => Chip(
                              label: Text(tag),
                              onDeleted: () {
                                // TODO: Implement tag removal
                              },
                            ))
                        .toList(),
                  ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
