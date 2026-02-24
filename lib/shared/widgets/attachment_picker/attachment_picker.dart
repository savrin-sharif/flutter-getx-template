/// A reusable attachment picker component with:
/// - Strongly-typed file type presets (image/pdf/any)
/// - Optional single/multi file selection
/// - Optional required/max-count validation
/// - Fast JPEG compression on a background isolate
/// - GetX-based controller for reactive state
/// - Full integration with Flutter's Form / FormField API
///
/// Typical usage:
///
///   final logoAttachmentController = AttachmentPickerController(
///     allowedType: AttachmentFileType.imageJpeg,
///     allowMultiple: false,
///     isRequired: true,
///     requiredMessage: 'Company logo is required',
///     maxBytes: 2 * 1024 * 1024,
///   );
///
///   Form(
///     key: formKey,
///     child: Column(
///       children: [
///         // ...other fields
///         AttachmentPicker(
///           controller: logoAttachmentController,
///           title: 'Attach Logo',
///           subtitle: 'JPG logo, max 2 MB',
///           autoValidateMode: AutovalidateMode.onUserInteraction,
///         ),
///       ],
///     ),
///   );
///
///   // On submit:
///   if (formKey.currentState!.validate()) {
///     // logoAttachmentController.attachments contains the selected File(s)
///   }
///
library;

import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img_lib;

/// Allowed file-type presets to keep calling code clean and explicit.
///
/// - [any]       : Any file, no filter.
/// - [imageJpeg] : Only .jpg / .jpeg (uses FileType.custom + extensions).
/// - [image]     : Any image (jpeg/png/webp/heic...), uses FileType.image.
/// - [pdf]       : Only .pdf (FileType.custom + "pdf").
enum AttachmentFileType {
  any,
  imageJpeg,
  image,
  pdf,
}

/// Helper extension that translates [AttachmentFileType] to:
/// - The correct [FileType] for `file_picker`.
/// - Allowed extensions when using FileType.custom.
/// - Whether we should run JPEG compression on picked files.
extension AttachmentFileTypeX on AttachmentFileType {
  FileType get filePickerType {
    switch (this) {
      case AttachmentFileType.imageJpeg:
      // Needs FileType.custom, because we filter extensions manually.
        return FileType.custom;

      case AttachmentFileType.image:
      // Generic image picker - no explicit extension list.
        return FileType.image;

      case AttachmentFileType.pdf:
      // Only PDFs, again via FileType.custom.
        return FileType.custom;

      case AttachmentFileType.any:
        return FileType.any;
    }
  }

  List<String>? get allowedExtensions {
    switch (this) {
      case AttachmentFileType.imageJpeg:
        return ['jpg', 'jpeg'];

      case AttachmentFileType.pdf:
        return ['pdf'];

      case AttachmentFileType.image:
      // FileType.image already restricts to image content types.
        return null;

      case AttachmentFileType.any:
      // No restriction.
        return null;
    }
  }

  /// Whether JPEG compression logic is relevant for this type.
  bool get shouldCompressImages {
    switch (this) {
      case AttachmentFileType.imageJpeg:
      case AttachmentFileType.image:
        return true;
      case AttachmentFileType.pdf:
      case AttachmentFileType.any:
        return false;
    }
  }
}

/// Utility: quick extension check for "is image".
bool _isImagePath(String path) {
  final ext = path.split('.').last.toLowerCase();
  return ['jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'].contains(ext);
}

/// Utility: quick extension check for "is pdf".
bool _isPdfPath(String path) {
  final ext = path.split('.').last.toLowerCase();
  return ext == 'pdf';
}

/// --------- FAST JPEG COMPRESSOR (Isolate) ----------------------------------

Future<File> fastJpegCompressInBackground(
    File input, {
      int maxBytes = 2 * 1024 * 1024, // 2 MB
    }) async {
  final outPath = await compute<Map<String, dynamic>, String?>(
    _fastJpegCompressIsolate,
    {
      'path': input.path,
      'maxBytes': maxBytes,
    },
  );
  if (outPath == null) throw Exception('Compression failed');
  return File(outPath);
}

Future<String?> _fastJpegCompressIsolate(
    Map<String, dynamic> args,
    ) async {
  final String path = args['path'] as String;
  final int maxBytes = args['maxBytes'] as int;

  final file = File(path);
  if (!await file.exists()) return null;

  // 0) Short-circuit if already small enough.
  final originalSize = await file.length();
  if (originalSize <= maxBytes) return file.path;

  // 1) Decode once.
  final bytes = await file.readAsBytes();
  img_lib.Image? img = img_lib.decodeImage(bytes);
  if (img == null) return null;

  // 2) One-shot scale estimate (no iterative resizing loops).
  double scale = sqrt(maxBytes / originalSize) * 0.98; // small safety margin
  scale = scale.clamp(0.2, 1.0);

  if (scale < 1.0) {
    final newW = max(1, (img.width * scale).round());
    final newH = max(1, (img.height * scale).round());
    img = img_lib.copyResize(
      img,
      width: newW,
      height: newH,
      interpolation: img_lib.Interpolation.linear, // fast + decent quality
    );
  }

  // 3) Encode JPEG once (fast), with a minor possible second pass.
  int q = 85;
  List<int> out = img_lib.encodeJpg(img, quality: q);

  if (out.length > maxBytes) {
    q = 78;
    out = img_lib.encodeJpg(img, quality: q);
  }

  if (out.length > maxBytes) {
    // Small extra downscale instead of nuking quality.
    final double s2 = sqrt(maxBytes / out.length) * 0.98;
    final img2 = img_lib.copyResize(
      img,
      width: max(1, (img.width * s2).round()),
      height: max(1, (img.height * s2).round()),
      interpolation: img_lib.Interpolation.linear,
    );
    q = 78;
    out = img_lib.encodeJpg(img2, quality: q);
  }

  final dir = file.parent.path;
  final ts = DateTime.now().millisecondsSinceEpoch;
  final outPath = '$dir/avatar_$ts.jpg';
  await File(outPath).writeAsBytes(out, flush: true);
  return outPath;
}

/// Controller to be used alongside the [AttachmentPicker] widget.
class AttachmentPickerController extends GetxController {
  /// Current list of selected attachments.
  final RxList<File> attachments = <File>[].obs;

  /// Whether we're in the middle of picking/compressing files.
  final RxBool isProcessing = false.obs;

  /// Runtime error text (e.g. picker/compression failures).
  /// Also used by [validate] to publish validation errors.
  final RxString errorText = ''.obs;

  /// Configuration / constraints.
  final AttachmentFileType allowedType;
  final bool allowMultiple;
  final bool isRequired;
  final int maxBytes; // For image compression.
  final int? maxFileCount;

  /// User-provided validation messages.
  final String? requiredMessage;
  final String? maxFileCountMessage;

  /// Optional custom validator for ultimate flexibility.
  final String? Function(List<File> files)? validator;

  AttachmentPickerController({
    this.allowedType = AttachmentFileType.any,
    this.allowMultiple = true,
    this.isRequired = false,
    this.maxBytes = 2 * 1024 * 1024,
    this.maxFileCount,
    this.validator,
    this.requiredMessage,
    this.maxFileCountMessage,
  });

  Future<void> pickFiles() async {
    try {
      errorText.value = '';
      isProcessing.value = true;

      final result = await FilePicker.platform.pickFiles(
        allowMultiple: allowMultiple,
        type: allowedType.filePickerType,
        allowedExtensions: allowedType.allowedExtensions,
        withData: false,
      );

      if (result == null) return; // user cancelled

      final picked = <File>[];

      for (final f in result.files) {
        if (f.path == null) continue;

        File file = File(f.path!);

        // Compress images if configured and file looks like an image.
        if (allowedType.shouldCompressImages && _isImagePath(file.path)) {
          final originalBytes = await file.length();
          if (originalBytes > maxBytes) {
            file = await fastJpegCompressInBackground(
              file,
              maxBytes: maxBytes,
            );
          }
        }

        picked.add(file);
      }

      if (picked.isEmpty) return;

      if (allowMultiple) {
        attachments.addAll(picked);

        // Enforce max count, if any.
        if (maxFileCount != null && attachments.length > maxFileCount!) {
          attachments.removeRange(maxFileCount!, attachments.length);
        }
      } else {
        attachments
          ..clear()
          ..add(picked.first);
      }
    } catch (e) {
      errorText.value = 'Failed to pick files: $e';
      debugPrint('AttachmentPickerController error: $e');
    } finally {
      isProcessing.value = false;
    }
  }

  void removeAttachment(int index) {
    if (index < 0 || index >= attachments.length) return;
    attachments.removeAt(index);
  }

  String? validate() {
    String? msg;

    if (validator != null) {
      msg = validator!(attachments.toList());
    }

    if (msg == null && isRequired && attachments.isEmpty) {
      msg = requiredMessage ?? 'Please attach at least one file.';
    }

    if (msg == null &&
        maxFileCount != null &&
        attachments.length > maxFileCount!) {
      msg = maxFileCountMessage ??
          'You can attach up to $maxFileCount file(s).';
    }

    errorText.value = msg ?? '';
    return msg;
  }

  void reset() {
    attachments.clear();
    errorText.value = '';
    isProcessing.value = false;
  }
}

/// A fully Form-integrated widget for picking attachments.
class AttachmentPicker extends StatefulWidget {
  final AttachmentPickerController controller;

  /// UI configuration
  final String title;
  final TextStyle? titleTextStyle;
  final IconData icon;
  final double iconSize;
  final double tileSize;
  final double spacing;
  final Color? tileBackgroundColor;
  final Color? tileBorderColor;
  final Color? iconColor;
  final Color? previewBorderColor;
  final Color? previewBackgroundColor;
  final Color? removeButtonBackgroundColor;
  final Color? removeIconColor;

  final String? subtitle;
  final TextStyle? subtitleTextStyle;

  final AutovalidateMode autoValidateMode;
  final String? Function(List<File> files)? validator;

  const AttachmentPicker({
    super.key,
    required this.controller,
    this.title = 'Attach files',
    this.titleTextStyle,
    this.icon = Icons.attach_file,
    this.iconSize = 34,
    this.tileSize = 80,
    this.spacing = 8,
    this.tileBackgroundColor,
    this.tileBorderColor,
    this.iconColor,
    this.previewBorderColor,
    this.previewBackgroundColor,
    this.removeButtonBackgroundColor,
    this.removeIconColor,
    this.subtitle,
    this.subtitleTextStyle,
    this.autoValidateMode = AutovalidateMode.disabled,
    this.validator,
  });

  @override
  State<AttachmentPicker> createState() => _AttachmentPickerState();
}

class _AttachmentPickerState extends State<AttachmentPicker> {
  @override
  Widget build(BuildContext context) {
    return FormField<List<File>>(
      autovalidateMode: widget.autoValidateMode,
      initialValue: widget.controller.attachments.toList(),
      validator: (value) {
        if (widget.validator != null) {
          final msg =
          widget.validator!(widget.controller.attachments.toList());
          if (msg != null) return msg;
        }
        return widget.controller.validate();
      },
      builder: (field) {
        final theme = Theme.of(context);

        final Color effectiveTileBg =
            widget.tileBackgroundColor ?? Colors.white;
        final Color effectiveTileBorder =
            widget.tileBorderColor ?? Colors.blueGrey.shade100;
        final Color effectiveIconColor =
            widget.iconColor ?? theme.iconTheme.color ?? Colors.black87;
        final Color effectivePreviewBorder =
            widget.previewBorderColor ?? Colors.blueGrey.shade100;
        final Color effectivePreviewBg =
            widget.previewBackgroundColor ?? Colors.white;
        final Color effectiveRemoveBg =
            widget.removeButtonBackgroundColor ?? Colors.black54;
        final Color effectiveRemoveIcon =
            widget.removeIconColor ?? Colors.white;

        return Obx(() {
          final files = widget.controller.attachments;
          final runtimeError = widget.controller.errorText.value;
          final validationError = field.errorText ?? '';
          final isProcessing = widget.controller.isProcessing.value;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!field.mounted) return;
            if (field.value != files) {
              field.didChange(files.toList());
            }
          });

          final combinedError =
          runtimeError.isNotEmpty ? runtimeError : validationError;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: widget.titleTextStyle ??
                    GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.34,
                    ),
              ),

              if (widget.subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  widget.subtitle!,
                  style: widget.subtitleTextStyle ??
                      GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                ),
              ],

              const SizedBox(height: 8),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tap area -> opens picker via controller.
                  InkWell(
                    onTap: widget.controller.pickFiles,
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      height: widget.tileSize,
                      width: widget.tileSize,
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                            width: 1,
                            color: effectiveTileBorder,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        color: effectiveTileBg,
                        child: Icon(
                          widget.icon,
                          size: widget.iconSize,
                          color: effectiveIconColor,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(width: widget.spacing),

                  // Attached file previews
                  Expanded(
                    child: files.isEmpty
                        ? (isProcessing
                        ? Align(
                      alignment: Alignment.topLeft,
                      child: DecoratedBox(
                        decoration: ShapeDecoration(
                          color: effectivePreviewBg,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(8),
                            side: BorderSide(
                              width: 1,
                              color: effectivePreviewBorder,
                            ),
                          ),
                        ),
                        child: const SizedBox(
                          height: 80,
                          width: 80,
                          child: Center(
                            child: SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                        : const SizedBox.shrink())
                        : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children:
                        List.generate(files.length, (index) {
                          final file = files[index];
                          final path = file.path;
                          final isImage = _isImagePath(path);
                          final isPdf = _isPdfPath(path);

                          IconData fileIcon =
                              Icons.insert_drive_file;
                          if (isPdf) {
                            fileIcon =
                              Icons.picture_as_pdf;
                          }
                          if (isImage) fileIcon = Icons.image;

                          return Padding(
                            padding:
                            const EdgeInsets.only(right: 12),
                            child: Stack(
                              children: [
                                DecoratedBox(
                                  decoration: ShapeDecoration(
                                    color: effectivePreviewBg,
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                      BorderRadius.circular(8),
                                      side: BorderSide(
                                        width: 1,
                                        color: effectivePreviewBorder,
                                      ),
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius:
                                    BorderRadius.circular(8),
                                    child: SizedBox(
                                      height: 80,
                                      width: 80,
                                      child: isProcessing
                                          ? const Center(
                                        child: SizedBox(
                                          height: 18,
                                          width: 18,
                                          child:
                                          CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      )
                                          : (isImage
                                          ? Image.file(
                                        file,
                                        fit: BoxFit.cover,
                                      )
                                          : Center(
                                        child: Icon(
                                          fileIcon,
                                          size: 30,
                                          color: Colors
                                              .grey.shade700,
                                        ),
                                      )),
                                    ),
                                  ),
                                ),

                                // Small "x" badge to remove individual file.
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: InkWell(
                                    onTap: () => widget.controller
                                        .removeAttachment(index),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: effectiveRemoveBg,
                                        shape: BoxShape.circle,
                                      ),
                                      padding:
                                      const EdgeInsets.all(2),
                                      child: Icon(
                                        Icons.close,
                                        size: 20,
                                        color: effectiveRemoveIcon,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ],
              ),

              if (combinedError.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    combinedError,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.red,
                    ),
                  ),
                ),
            ],
          );
        });
      },
    );
  }
}
