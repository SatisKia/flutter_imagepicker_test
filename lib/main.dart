import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State createState() => _MyHomePageState();
}

class _MyHomePageState extends State {
  double contentWidth  = 0.0;
  double contentHeight = 0.0;

  bool isMulti = true;

  List<XFile>? imageFiles;
  int imageIndex = 0;

  Image? image;
  double imageWidth = 0.0;
  double imageHeight = 0.0;
  double maxWidth = 0.0;
  double maxHeight = 0.0;

  static String localFileName = 'flutter_imagepicker_test';

  @override
  void initState() {
    super.initState();
    deleteTemporaryImages();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      Image? image = await loadImage(localFileName);
      if( image != null ){
        update(image);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    contentWidth  = MediaQuery.of( context ).size.width;
    contentHeight = MediaQuery.of( context ).size.height - MediaQuery.of( context ).padding.top - MediaQuery.of( context ).padding.bottom;

    maxWidth = contentWidth;
    maxHeight = contentHeight - contentWidth / 8;

    return Scaffold(
      appBar: AppBar(
          toolbarHeight: 0
      ),
      body: Column( children: [
        Row( children: [
          SizedBox(
              width: contentWidth / 2,
              height: contentWidth / 8,
              child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    primary: Colors.blue,
                    onPrimary: Colors.white,
                  ),
                  onPressed: onGallery,
                  child: Text(
                    "gallery",
                    style: TextStyle( fontSize: contentWidth / 16 ),
                  )
              )
          ),
          SizedBox(
              width: contentWidth / 2,
              height: contentWidth / 8,
              child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    primary: Colors.amber,
                    onPrimary: Colors.white,
                  ),
                  onPressed: onCamera,
                  child: Text(
                    "camera",
                    style: TextStyle( fontSize: contentWidth / 16 ),
                  )
              )
          ),
        ] ),
        InkWell(
            onTap: onNext,
            child: Container(
                width: maxWidth,
                height: maxHeight,
                alignment: Alignment.center,
                child: (image == null) ? const Icon(Icons.no_sim) : SizedBox(
                    width: imageWidth,
                    height: imageHeight,
                    child: image
                )
            )
        ),
      ] ),
    );
  }

  Future<Image> createImage(XFile imageFile) async {
    debugPrint(imageFile.path);
    File file = File.fromUri(Uri.file(imageFile.path));
    return Image.memory(file.readAsBytesSync());
  }

  Future saveImage(XFile imageFile, String fileName) async {
    Directory directory = await getApplicationDocumentsDirectory();
    String path = directory.path;

    File file = File.fromUri(Uri.file(imageFile.path));
    File saveFile = File('$path/$fileName');
    await saveFile.writeAsBytes(await file.readAsBytes());
  }

  Future<Image?> loadImage(String fileName) async {
    Directory directory = await getApplicationDocumentsDirectory();
    String path = directory.path;

    File file = File('$path/$fileName');
    if( file.existsSync() ) {
      return Image.memory(file.readAsBytesSync());
    }
    return null;
  }

  Future deleteImage(XFile imageFile) async {
    File file = File.fromUri(Uri.file(imageFile.path));
    try {
      debugPrint(imageFile.path);
      await file.delete();
      debugPrint("DELETE OK");
    } catch(e) {
      debugPrint("DELETE NG");
    }
  }

  Future deleteTemporaryImages() async {
    String temporaryDirectoryPath;
    if( Platform.isAndroid ){
      Directory directory = await getTemporaryDirectory();
      temporaryDirectoryPath = directory.path;
    } else {
      Directory directory = await getApplicationDocumentsDirectory();
      String path = directory.path;
      temporaryDirectoryPath = path.replaceFirst('/Documents', '/tmp');
    }
    clearTemporaryDirectoryImages(temporaryDirectoryPath);
  }
  Future clearTemporaryDirectoryImages(String temporaryDirectoryPath) async {
    Directory temporaryDirectory = Directory(temporaryDirectoryPath);
    if( temporaryDirectory.existsSync() ){
      Stream<FileSystemEntity> stream = temporaryDirectory.list(recursive: false, followLinks: false);
      stream.listen((entity) {
        debugPrint(entity.path);
        if( entity.path.contains('jpeg') || entity.path.contains('jpg') || entity.path.contains('png') ){
          try {
            entity.delete();
            debugPrint("DELETE OK");
          } catch(e) {
            debugPrint("DELETE NG");
          }
        }
      });
    }
  }

  Future<Size> getImageSize(Image image) async {
    Completer<Size> completer = Completer<Size>();
    ImageProvider<Object> imageProvider = image.image;
    ImageStream imageStream = imageProvider.resolve(ImageConfiguration.empty);
    imageStream.addListener(ImageStreamListener((ImageInfo imageInfo, _) {
      ui.Image uiImage = imageInfo.image;
      Size size = Size(
          uiImage.width.toDouble(),
          uiImage.height.toDouble()
      );
      completer.complete(size);
    }));
    return completer.future;
  }

  void update(Image image) async {
    Size size = await getImageSize(image);
    setState(() {
      this.image = image;
      imageWidth = size.width;
      imageHeight = size.height;
      if( imageWidth > maxWidth ){
        imageHeight /= (imageWidth / maxWidth);
        imageWidth = maxWidth;
      }
      if( imageHeight > maxHeight ){
        imageWidth /= (imageHeight / maxHeight);
        imageHeight = maxHeight;
      }
    });
  }

  void onGallery() async {
    ImagePicker imagePicker = ImagePicker();
    if( isMulti ){
      imageFiles = await imagePicker.pickMultiImage();
      if( imageFiles != null ) {
        imageIndex = 0;
        XFile imageFile = imageFiles![imageIndex];
        update(await createImage(imageFile));
        saveImage(imageFile, localFileName);
      } else {
        setState(() {
          image = null;
        });
      }
    } else {
      XFile? imageFile = await imagePicker.pickImage(source: ImageSource.gallery);
      if( imageFile != null ) {
        update(await createImage(imageFile));
        saveImage(imageFile, localFileName);
      } else {
        setState(() {
          image = null;
        });
      }
    }
  }

  void onNext() async {
    if( imageFiles != null && imageFiles!.length > 1 ){
      imageIndex++;
      if( imageIndex >= imageFiles!.length ){
        imageIndex = 0;
      }
      XFile imageFile = imageFiles![imageIndex];
      update(await createImage(imageFile));
      saveImage(imageFile, localFileName);
    }
  }

  void onCamera() async {
    ImagePicker imagePicker = ImagePicker();
    XFile? imageFile = await imagePicker.pickImage(source: ImageSource.camera);
    if( imageFile != null ) {
      update(await createImage(imageFile));
      saveImage(imageFile, localFileName);
    } else {
      setState(() {
        image = null;
      });
    }
  }
}
