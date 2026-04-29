// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:folio/api/providers/database_provider.dart';
import 'package:folio/api/providers/user_provider.dart';
import 'package:folio/models/user.dart';
import 'package:folio_mobile_ui/common/bottom_sheet_menu/bottom_sheet_menu_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:folio_mobile_ui/screens/settings/settings_screen.i18n.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crop_your_image/crop_your_image.dart';

// ignore: must_be_immutable
class UserMenuProfilePic extends StatelessWidget {
  late User u;

  UserMenuProfilePic(this.u, {super.key});

  @override
  Widget build(BuildContext context) {
    // if (!Provider.of<PlusProvider>(context)
    //     .hasScope(PremiumScopes.nickname)) {
    //   return const SizedBox();
    // }

    return BottomSheetMenuItem(
      onPressed: () {
        showDialog(
            context: context, builder: (context) => UserProfilePicEditor(u));
      },
      icon: const Icon(Icons.camera_alt_rounded),
      title: Text("edit_profile_picture".i18n),
    );
  }
}

// ignore: must_be_immutable
class UserProfilePicEditor extends StatefulWidget {
  late User u;

  UserProfilePicEditor(this.u, {super.key});

  @override
  State<UserProfilePicEditor> createState() => _UserProfilePicEditorState();
}

class _UserProfilePicEditorState extends State<UserProfilePicEditor> {
  late final UserProvider user;

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
        aspectRatio: 1.0,
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
            Text(
              "select_profile_picture".i18n,
            ),
          ],
        ),
      ),
    );
  }

  void _cropImage() {
    _controller.crop(); // triggers onCropped
  }

  void _onCropped(Uint8List croppedData) async {
    final base64Image = base64Encode(croppedData);

    widget.u.picture = base64Image;

    Provider.of<DatabaseProvider>(context, listen: false)
        .store
        .storeUser(widget.u);

    Provider.of<UserProvider>(context, listen: false).refresh();

    debugPrint('Image cropped and saved');
  }

  @override
  void initState() {
    super.initState();
    user = Provider.of<UserProvider>(context, listen: false);
  }

  @override
  void dispose() {
    _file = null; // no temp files to delete anymore
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14.0)),
      ),
      contentPadding: const EdgeInsets.only(top: 10.0),
      title: Text("edit_profile_picture".i18n),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 12.0, horizontal: 24.0),
            child: _imageData == null ? openImageWidget() : cropImageWidget(),
          ),
          if (widget.u.picture != "")
            TextButton(
              child: Text(
                "remove_profile_picture".i18n,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.red,
                ),
              ),
              onPressed: () {
                widget.u.picture = "";
                Provider.of<DatabaseProvider>(context, listen: false)
                    .store
                    .storeUser(widget.u);
                Provider.of<UserProvider>(context, listen: false).refresh();
                Navigator.of(context).pop(true);
              },
            ),
        ],
      ),
      actions: [
        TextButton(
          child: Text("cancel".i18n),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        TextButton(
          child: Text("done".i18n),
          onPressed: () {
            _cropImage();
            Navigator.of(context).pop(true);
          },
        ),
      ],
    );
  }
}
