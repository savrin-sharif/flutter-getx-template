import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// A self-contained attachment picker widget with built-in camera/gallery
/// selection, preview rendering, removal, and change notifications.

class AttachmentPickerField extends StatefulWidget {
  const AttachmentPickerField({
    super.key,
    this.label = 'Attachment (Optional)',
    this.helperText,
    this.initialAttachments = const <XFile>[],
    this.attachments,
    this.onChanged,
    this.onError,
    this.allowCamera = true,
    this.allowGallery = true,
    this.allowMultipleFromGallery = true,
    this.maxAttachments,
    this.tileSize = 80,
    this.icon = Icons.attach_file,
  }) : assert(
         attachments == null || initialAttachments.length == 0,
         'Use either attachments or initialAttachments, not both.',
       );

  final String label;
  final String? helperText;
  final List<XFile> initialAttachments;
  final List<XFile>? attachments;
  final AttachmentPickerChanged? onChanged;
  final ValueChanged<Object>? onError;
  final bool allowCamera;
  final bool allowGallery;
  final bool allowMultipleFromGallery;
  final int? maxAttachments;
  final double tileSize;
  final IconData icon;

  @override
  State<AttachmentPickerField> createState() => _AttachmentPickerFieldState();
}

typedef AttachmentPickerChanged = FutureOr<void> Function(List<XFile> files);

class _AttachmentPickerFieldState extends State<AttachmentPickerField> {
  final ImagePicker _picker = ImagePicker();
  late List<XFile> _attachments;
  bool _isPicking = false;
  int? _removingIndex;

  bool get _isControlled => widget.attachments != null;

  @override
  void initState() {
    super.initState();
    _attachments = List<XFile>.from(
      widget.attachments ?? widget.initialAttachments,
    );
  }

  @override
  void didUpdateWidget(covariant AttachmentPickerField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_isControlled) {
      _attachments = List<XFile>.from(widget.attachments!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outlineColor = theme.colorScheme.outlineVariant;
    final primaryColor = theme.colorScheme.primary;
    final canPick = widget.allowCamera || widget.allowGallery;
    final isBusy = _isPicking || _removingIndex != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (widget.helperText != null) ...[
          const SizedBox(height: 4),
          Text(
            widget.helperText!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: canPick && !isBusy ? () => _handleAddTap(context) : null,
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: widget.tileSize,
                width: widget.tileSize,
                child: Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(width: 1, color: outlineColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  color: primaryColor.withValues(alpha: 0.06),
                  child: Center(
                    child: _isPicking
                        ? _AttachmentProgressIndicator(
                            color: primaryColor,
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHighest,
                          )
                        : Icon(
                            widget.icon,
                            size: 30,
                            color: canPick
                                ? primaryColor
                                : theme.colorScheme.onSurface.withValues(
                                    alpha: 0.4,
                                  ),
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _attachments.isEmpty
                  ? SizedBox(
                      height: widget.tileSize,
                      child: Align(
                        alignment: .centerLeft,
                        child: Text(
                          'No attachments selected yet',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _attachments.asMap().entries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: _AttachmentPreviewTile(
                              file: entry.value,
                              size: widget.tileSize,
                              outlineColor: outlineColor,
                              isRemoving: _removingIndex == entry.key,
                              onRemove: () => _removeAttachment(entry.key),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _handleAddTap(BuildContext context) async {
    if (widget.maxAttachments != null &&
        _attachments.length >= widget.maxAttachments!) {
      _showMessage('You can attach up to ${widget.maxAttachments} file(s).');
      return;
    }

    setState(() {
      _isPicking = true;
    });

    try {
      final source = await _showSourceSheet(context);
      if (source == null) return;

      final pickedFiles = await _pickFiles(source);
      if (pickedFiles.isEmpty) return;

      final remainingSlots = widget.maxAttachments == null
          ? null
          : widget.maxAttachments! - _attachments.length;

      final nextFiles = remainingSlots == null
          ? pickedFiles
          : pickedFiles.take(remainingSlots).toList();

      if (nextFiles.isEmpty) {
        _showMessage('You can attach up to ${widget.maxAttachments} file(s).');
        return;
      }

      await _setAttachments([..._attachments, ...nextFiles]);

      if (remainingSlots != null && pickedFiles.length > nextFiles.length) {
        _showMessage(
          'Only ${nextFiles.length} file(s) were added due to the limit.',
        );
      }
    } catch (error) {
      widget.onError?.call(error);
      if (widget.onError == null) {
        _showMessage('Unable to access media right now. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPicking = false;
        });
      }
    }
  }

  Future<ImageSource?> _showSourceSheet(BuildContext context) async {
    if (widget.allowCamera && !widget.allowGallery) {
      return ImageSource.camera;
    }

    if (!widget.allowCamera && widget.allowGallery) {
      return ImageSource.gallery;
    }

    return showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.allowCamera)
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Camera'),
                  subtitle: const Text('Capture a new image'),
                  onTap: () => Navigator.of(context).pop(ImageSource.camera),
                ),
              if (widget.allowGallery)
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Gallery'),
                  subtitle: const Text('Choose from your photo library'),
                  onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<List<XFile>> _pickFiles(ImageSource source) async {
    if (source == ImageSource.gallery && widget.allowMultipleFromGallery) {
      return _picker.pickMultiImage();
    }

    final file = await _picker.pickImage(source: source);
    if (file == null) return const <XFile>[];
    return [file];
  }

  Future<void> _removeAttachment(int index) async {
    if (index < 0 || index >= _attachments.length) return;

    setState(() {
      _removingIndex = index;
    });

    try {
      final updated = List<XFile>.from(_attachments)..removeAt(index);
      await _setAttachments(updated);
    } finally {
      if (mounted) {
        setState(() {
          _removingIndex = null;
        });
      }
    }
  }

  Future<void> _setAttachments(List<XFile> files) async {
    if (!_isControlled) {
      setState(() {
        _attachments = files;
      });
    } else {
      _attachments = files;
    }

    await widget.onChanged?.call(List<XFile>.unmodifiable(files));
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AttachmentPreviewTile extends StatelessWidget {
  const _AttachmentPreviewTile({
    required this.file,
    required this.size,
    required this.outlineColor,
    required this.isRemoving,
    required this.onRemove,
  });

  final XFile file;
  final double size;
  final Color outlineColor;
  final bool isRemoving;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        DecoratedBox(
          decoration: ShapeDecoration(
            color: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(width: 1, color: outlineColor),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: FutureBuilder<Uint8List>(
              future: file.readAsBytes(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Stack(
                    children: [
                      Image.memory(
                        snapshot.data!,
                        height: size,
                        width: size,
                        fit: BoxFit.cover,
                      ),
                      if (isRemoving)
                        Positioned.fill(
                          child: ColoredBox(
                            color: Colors.black.withValues(alpha: 0.35),
                            child: const Center(
                              child: _AttachmentProgressIndicator(
                                color: Colors.white,
                                backgroundColor: Colors.white24,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                }

                return SizedBox(
                  height: size,
                  width: size,
                  child: Center(
                    child: _AttachmentProgressIndicator(
                      color: theme.colorScheme.primary,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: InkWell(
            onTap: isRemoving ? null : onRemove,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(2),
              child: const Icon(Icons.close, size: 18, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _AttachmentProgressIndicator extends StatelessWidget {
  const _AttachmentProgressIndicator({
    required this.color,
    required this.backgroundColor,
  });

  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      width: 24,
      child: CircularProgressIndicator(
        strokeWidth: 2.8,
        valueColor: AlwaysStoppedAnimation(color),
        backgroundColor: backgroundColor,
      ),
    );
  }
}
