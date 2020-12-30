import 'dart:convert';
import 'dart:io';

const String json = '''
{
  "id": 0,
  "name": "string",
  "starts_at": "string",
  "ends_at": "string",
  "is_finished": true,
  "rating": {
    "slug": "string",
    "name": "string"
  },
  "social_media_links": [{
    "id": 0,
    "url": "string",
    "icon": "string",
    "name": "string"
  }],
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
    // ignore: leading_newlines_in_multiline_strings
    return 'Template{}';
  }
}
  ''';

/// Cache model name here
Map<String, int> modelNames = <String, int>{};

/// Convert to Uppercase first char
/// Ex: socialable => Socialable
String standardFieldName(String propertyName) {
  final String name =
      '${propertyName.substring(0, 1).toUpperCase()}${propertyName.substring(1)}';
  return name;
}

/// Convert to class name, remove last 's'
/// Ex: socialables => Socialable
String standardClassName(String propertyName) {
  final String name = standardFieldName(propertyName);
  if (name.endsWith('s')) {
    return name.substring(0, name.length - 1);
  }
  return name;
}

/// Standard file name from json key
String standardClassFile(String jsonKey) {
  if (jsonKey.endsWith('s')) {
    jsonKey = jsonKey.substring(0, jsonKey.length - 1);
  }
  return '$jsonKey.dart';
}

/// Convert json key to dart key
/// Ex: socialable_id => socialableId
String standardPropertyName(String jsonKey) {
  List<String> comps = jsonKey.split('_');
  for (int i = 1; i < comps.length; i++) {
    comps[i] = standardFieldName(comps[i]);
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
  } else if (value != null) {
    type = 'object';
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
    String classFile = standardClassFile(key);
    if (type == 'object' && !modelNames.containsKey(className)) {
      createModel(classFile, className, value);

      /// Add imports
      String importsPattern = 'class $rootModelClassName {';
      String tmpImports = 'import \'$classFile\';\n$importsPattern';
      classContent = classContent.replaceAll(importsPattern, tmpImports);
    } else if (type == 'List<dynamic>' && value is List && value.length > 0) {
      dynamic firstI = value[0];
      String listType = findValueType(firstI);
      if (listType == 'object' && !modelNames.containsKey(className)) {
        createModel(classFile, className, firstI);

        /// Add imports
        String importsPattern = 'class $rootModelClassName {';
        String tmpImports = 'import \'$classFile\';\n$importsPattern';
        classContent = classContent.replaceAll(importsPattern, tmpImports);
      }
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
      if (type == 'object') {
        String className = standardClassName(standardName);
        tmpFactory +=
            '\t\t\t\t$standardName: json[\'$key\'] != null ? $className.fromJson(json[\'$key\'] as Map<String, dynamic>) : null,\n';
      } else if (type == 'List<dynamic>' && value is List && value.length > 0) {
        dynamic firstI = value[0];
        String listType = findValueType(firstI);
        if (listType == 'object') {
          String propertyName = standardPropertyName(key);
          String className = standardClassName(propertyName);
          tmpFactory +=
              '\t\t\t\t$standardName: json[\'$key\'] != null ? List<$className>.from((json[\'$key\'] as List<dynamic>).map<$className>((dynamic x) => $className.fromJson(x as Map<String, dynamic>))) : <$className>[],\n';
        } else {
          tmpFactory +=
              '\t\t\t\t$standardName: List<$listType>.from(json[\'$key\'] as List<dynamic>),\n';
        }
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
      if (type == 'object') {
        String className = standardClassName(standardName);
        tmpProperties += '\tfinal $className $standardName;\n';
      } else if (type == 'List<dynamic>' && value is List && value.length > 0) {
        dynamic firstI = value[0];
        String listType = findValueType(firstI);
        if (listType == 'object') {
          String propertyName = standardPropertyName(key);
          String className = standardClassName(propertyName);
          tmpProperties += '\tfinal List<$className> $standardName;\n';
        } else {
          tmpProperties += '\tfinal List<$type> $standardName;\n';
        }
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
      String type = findValueType(value);
      if (type == 'object') {
        tmpToJson += '\t\t\t\t\'$key\': $standardName?.toJson(),\n';
      } else if (type == 'List<dynamic>' && value is List && value.length > 0) {
        dynamic firstI = value[0];
        String listType = findValueType(firstI);
        if (listType == 'object') {
          String propertyName = standardPropertyName(key);
          String className = standardClassName(propertyName);
          tmpToJson +=
              '\t\t\t\t\'$key\': List<$className>.from($standardName.map<Map<String, dynamic>>(($className x) => x.toJson())),\n';
        } else {
          tmpToJson += '\t\t\t\t\'$key\': $standardName,\n';
        }
      } else {
        tmpToJson += '\t\t\t\t\'$key\': $standardName,\n';
      }
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
  final String rootModelFileName = 'event.dart';
  final String rootModelClassName = 'Event';
  createModel(rootModelFileName, rootModelClassName, decodedJson);
}
