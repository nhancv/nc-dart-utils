import 'dart:async';
import 'dart:io';

extension FileExtention on FileSystemEntity {
  String get name {
    return this?.path?.split("/")?.last;
  }

  String get directoryPath {
    return this?.path?.replaceAll("/${name}", '');
  }
}

// @nhancv 10/24/2019: Get file in directory
Future<List<FileSystemEntity>> dirContents(Directory dir) {
  var files = <FileSystemEntity>[];
  var completer = Completer<List<FileSystemEntity>>();
  var lister = dir.list(recursive: false);
  lister.listen((file) => files.add(file),
      // should also register onError
      onDone: () => completer.complete(files));
  return completer.future;
}

// @nhancv 10/24/2019: Convert invalid file name in folder
void renameFile(List<FileSystemEntity> fileList) {
  fileList.forEach((f) {
    String fileName = f.name;
    String filePath = f.directoryPath;
    String newFileName = standardName(fileName);
    if (newFileName != null) {
      String newFilePath = '$filePath/$newFileName';
      f.renameSync(newFilePath);
    }
  });
}

// Convert abcXyz.png = to abc_xyz.png
// From: addNew.png
// => add_new.png
String standardName(String originalName) {
  RegExp validPattern = RegExp(r'^[a-z](?:_?[a-z0-9]+)*.png$');
  if (validPattern.stringMatch(originalName) == null) {
    // Detect addNew.png pattern
    RegExp pattern = RegExp(r'[a-z]{1,}[A-Z].{0,}.png');
    String fileName = originalName.replaceAll(' ', '_');
    String invalidName = pattern.stringMatch(fileName);
    if (invalidName != null) {
      // Trim space, remove first _
      String newName = invalidName.splitMapJoin(RegExp(r'[A-Z]+'),
          onMatch: (m) => '_${m.group(0).toLowerCase()}',
          onNonMatch: (n) => n.trim());
      fileName = fileName.replaceAll(pattern, newName);
    }
    return fileName
        .splitMapJoin(RegExp(r'^_[a-z]+'),
            onMatch: (m) => '${m.group(0).substring(1)}',
            onNonMatch: (n) => n.trim())
        .replaceAll(RegExp(r'_+.png'), '.png')
        .toLowerCase();
  }
  return null;
}

// Move <name>@2x.png to 2.0x/<name>.png
// Move <name>@3x.png to 3.0x/<name>.png
void moveFile(List<FileSystemEntity> fileList) {
  fileList.forEach((f) {
    String fileName = f.name;
    String filePath = f.directoryPath;

    // Move <name>@2x.png to 2.0x/<name>.png
    RegExp pattern2x = RegExp(r'@2x.png');
    if (pattern2x.stringMatch(fileName) != null) {
      String nameWithoutSuffix =
          fileName.substring(0, fileName.length - '@2x.png'.length);
      Directory('$filePath/2.0x').createSync(recursive: true);
      f.renameSync('$filePath/2.0x/$nameWithoutSuffix.png');
    }

    // Move <name>@3x.png to 3.0x/<name>.png
    RegExp pattern3x = RegExp(r'@3x.png');
    if (pattern3x.stringMatch(fileName) != null) {
      String nameWithoutSuffix =
          fileName.substring(0, fileName.length - '@3x.png'.length);
      Directory('$filePath/3.0x').createSync(recursive: true);
      f.renameSync('$filePath/3.0x/$nameWithoutSuffix.png');
    }
  });
}

// Run test standard function
void test() {
  Map<String, String> testMap = {
    'abc.png': null,
    'ic_test.png': null,
    'ic_test_2.png': null,
    'ic_test_2_.png': 'ic_test_2.png',
    'ic test.png': 'ic_test.png',
    '_ic test.png': 'ic_test.png',
    'addNew.png': 'add_new.png',
    'abcXYZ.png': 'abc_xyz.png',
    'abc zyz.png': 'abc_zyz.png',
    'abc XYZ.png': 'abc_xyz.png',
    'Zabc.png': 'zabc.png',
  };

  bool totalRes = true;
  testMap.forEach((input, expect) {
    String output = standardName(input);
    bool res = output == expect;
    if (totalRes && res == false) {
      totalRes = false;
    }
    print(
        'Input: $input - Output: $output - Expect: $expect - ${res ? 'TRUE' : 'FALSE'}');
  });
  print('Total: ${totalRes ? 'TRUE' : 'FALSE'}');
}

// - Standard file name in Directory
// - Standard place of file
// Context:
// ./res/addNew.png
// ./res/addNew@2x.png
// ./res/addNew@3x.png
//
// Output
// ./res/add_new.png
// ./res/2.0x/add_new.png
// ./res/3.0x/add_new.png
// --------
/// How to run:
/// - Create res folder
/// - Put images to inside res folder
/// - Run script
void main() async {
  // Test
  // test();

  String directory = './res';
  renameFile(await dirContents(Directory(directory)));
  moveFile(await dirContents(Directory(directory)));
}
