// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:folio/api/providers/database_provider.dart';
import 'package:folio/api/providers/self_note_provider.dart';
import 'package:folio/models/self_note.dart';
import 'package:folio/models/user.dart';
import 'package:uuid/uuid.dart';
import 'notes_screen.i18n.dart';

// ignore: must_be_immutable
class ImageNoteEditor extends StatefulWidget {
  late User u;

  ImageNoteEditor(this.u, {super.key});

  @override
  State<ImageNoteEditor> createState() => _ImageNoteEditorState();
}

class _ImageNoteEditorState extends State<ImageNoteEditor> {
  final _title = TextEditingController();
  final CropController _controller = CropController();

  File? _file;
  Uint8List? _imageData;

  Future<void> pickImage() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      final file = File(picked.path);
      final bytes = await file.readAsBytes();

      setState(() {
        _file = file;
        _imageData = bytes;
      });
    } on PlatformException catch (e) {
      log('Failed to pick image: $e');
    }
  }

  Widget cropImageWidget() {
    return SizedBox(
      height: 300,
      child: Crop(
        image: _imageData!,
        controller: _controller,
        // no aspectRatio → free crop like your original
        onCropped: _onCropped,
      ),
    );
  }

  Widget openImageWidget() {
    return InkWell(
      customBorder: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14.0),
      ),
      onTap: pickImage,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(14.0),
        ),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 8.0),
        child: Column(
          children: [
            Text(
              "click_here".i18n,
              style: const TextStyle(
                fontSize: 22.0,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text("select_image".i18n),
          ],
        ),
      ),
    );
  }

  void _cropImage() {
    _controller.crop(); // triggers _onCropped
  }

  Future<void> _onCropped(Uint8List croppedData) async {
    final base64Image = base64Encode(croppedData);

    List<SelfNote> selfNotes =
        await Provider.of<DatabaseProvider>(context, listen: false)
            .userQuery
            .getSelfNotes(userId: widget.u.id);

    selfNotes.add(SelfNote.fromJson({
      'id': const Uuid().v4(),
      'content': base64Image,
      'note_type': 'image',
      'title': _title.text,
    }));

    await Provider.of<DatabaseProvider>(context, listen: false)
        .userStore
        .storeSelfNotes(selfNotes, userId: widget.u.id);

    Provider.of<SelfNoteProvider>(context, listen: false).restore();
    Provider.of<SelfNoteProvider>(context, listen: false).restoreTodo();

    Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _title.dispose();
    _file = null; // no temp files anymore
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14.0)),
      ),
      contentPadding: const EdgeInsets.only(top: 10.0),
      title: Text("new_image".i18n),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 12.0, horizontal: 24.0),
            child: _imageData == null ? openImageWidget() : cropImageWidget(),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 12.0, horizontal: 24.0),
            child: TextField(
              controller: _title,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12.0),
                hintText: 'title'.i18n,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => setState(() => _title.clear()),
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          child: Text("cancel".i18n),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        TextButton(
          child: Text("next".i18n),
          onPressed: _cropImage,
        ),
      ],
    );
  }
}
