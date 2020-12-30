import 'dart:convert';
import 'dart:io';

const String json = '''
{
  "id": 0,
  "url": "string",
  "socialable_id": 0,
  "socialable_type": "string",
  "social_media_slug": "string",
  "icon": "string",
  "name": "string",
  "test": {
    "id": 0
  },
  "empty": {}
}
''';

final String classTemplate = '''
class Template {
  Template();

  factory Template.fromJson(Map<String, dynamic> json) => Template();

  ///#region PROPERTIES
  ///#endregion

  Map<String, dynamic> toJson() => <String, dynamic>{};

  @override
  String toString() {
    return 'Template{}';
  }
}
  ''';

/// Cache model name here
Map<String, int> modelNames = <String, int>{};

/// Convert to class name
/// Ex: socialable => Socialable
String standardClassName(String propertyName) {
  return '${propertyName.substring(0, 1).toUpperCase()}${propertyName.substring(1)}';
}

/// Convert json key to dart key
/// Ex: socialable_id => socialableId
String standardPropertyName(String jsonKey) {
  List<String> comps = jsonKey.split('_');
  for (int i = 1; i < comps.length; i++) {
    comps[i] = standardClassName(comps[i]);
  }
  return comps.join();
}

/// Return type of value
String findValueType(dynamic value) {
  /// Find type of value
  String type = 'dynamic';
  if (value is int) {
    type = 'int';
  } else if (value is double) {
    type = 'double';
  } else if (value is bool) {
    type = 'bool';
  } else if (value is String) {
    type = 'String';
  } else if (value is List<dynamic>) {
    type = 'List<dynamic>';
  }
  return type;
}

/// Create new dart class file, place in models folder
Future<File> genClassFile(String fileName, String content) async {
  Directory('models').createSync(recursive: true);
  final File file = File('models/$fileName');
  return file.writeAsString(content);
}

/// Parse and create class
Future<void> createModel(
  String rootModelFileName,
  String rootModelClassName,
  Map<String, dynamic> decodedJson,
) async {
  String classContent = classTemplate;
  classContent = classContent.replaceAll('Template', rootModelClassName);

  /// Create sub model
  decodedJson.forEach((String key, dynamic value) {
    String type = findValueType(value);
    String propertyName = standardPropertyName(key);
    String className = standardClassName(propertyName);
    String classFile = '$key.dart';
    if (type == 'dynamic' && !modelNames.containsKey(className)) {
      createModel(classFile, className, value);

      /// Add imports
      String importsPattern = 'class $rootModelClassName {';
      String tmpImports = 'import \'$classFile\';\n$importsPattern';
      classContent = classContent.replaceAll(importsPattern, tmpImports);
    }
  });

  /// New endline import
  String importsPattern = 'class $rootModelClassName {';
  classContent = classContent.replaceAll(importsPattern, '\n$importsPattern');

  /// Check property length
  int propertyLength = decodedJson.length;
  if (propertyLength > 0) {
    /// Update constructor
    String constructorPattern = '$rootModelClassName();';
    String tmpConstructor = '$rootModelClassName({\n';
    decodedJson.forEach((String key, dynamic value) {
      String standardName = standardPropertyName(key);
      tmpConstructor += '\t\tthis.$standardName,\n';
    });
    tmpConstructor += '\t});';
    classContent =
        classContent.replaceFirst(constructorPattern, tmpConstructor);

    /// Update factory fromJson
    String factoryPattern = '$rootModelClassName();';
    String tmpFactory = '$rootModelClassName(\n';
    decodedJson.forEach((String key, dynamic value) {
      String standardName = standardPropertyName(key);
      String type = findValueType(value);
      if (type == 'dynamic') {
        String className = standardClassName(standardName);
        tmpFactory +=
            '\t\t\t\t$standardName: json[\'$key\'] != null ? $className.fromJson(json[\'$key\'] as Map<String, dynamic>) : null,\n';
      } else {
        tmpFactory += '\t\t\t\t$standardName: json[\'$key\'] as $type,\n';
      }
    });
    tmpFactory += '\t\t\t);';
    classContent = classContent.replaceFirst(factoryPattern, tmpFactory);

    /// Add properties
    String propertiesPattern = '///#region PROPERTIES';
    String tmpProperties = '$propertiesPattern\n';
    decodedJson.forEach((String key, dynamic value) {
      String standardName = standardPropertyName(key);
      String type = findValueType(value);
      if (type == 'dynamic') {
        String className = standardClassName(standardName);
        tmpProperties += '\tfinal $className $standardName;\n';
      } else {
        tmpProperties += '\tfinal $type $standardName;\n';
      }
    });
    classContent = classContent.replaceAll(propertiesPattern, tmpProperties);

    /// Update to json
    String toJsonPattern = '<String, dynamic>{};';
    String tmpToJson = '<String, dynamic>{\n';
    decodedJson.forEach((String key, dynamic value) {
      String standardName = standardPropertyName(key);
      tmpToJson += '\t\t\t\t\'$key\': $standardName,\n';
    });
    tmpToJson += '\t\t\t};';
    classContent = classContent.replaceFirst(toJsonPattern, tmpToJson);

    /// Update to String
    String toStringPattern = '\'$rootModelClassName{}\';';
    String tmpToString = '\'\'\'$rootModelClassName{\n';
    decodedJson.forEach((String key, dynamic value) {
      String standardName = standardPropertyName(key);
      tmpToString += '\t\t$standardName: \$$standardName,\n';
    });
    tmpToString += '\t}\'\'\';';
    classContent = classContent.replaceFirst(toStringPattern, tmpToString);
  }
  genClassFile(rootModelFileName, classContent);
}

Future<void> main() async {
  final Map<String, dynamic> decodedJson = jsonDecode(json);
  final String rootModelFileName = 'rating.dart';
  final String rootModelClassName = 'Rating';
  createModel(rootModelFileName, rootModelClassName, decodedJson);
}
