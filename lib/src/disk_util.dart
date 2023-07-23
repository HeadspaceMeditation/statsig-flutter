// import 'dart:convert';
// import 'dart:io';
//
// // class DataStore {
// //
// //
// //   Future<void> put({String, })
// // }
//
// abstract class DiskUtil {
//   static write(String filename, String contents) async {
//     var dir = await _getTempDir();
//
//     var file = File("${dir.path}/$filename");
//     await file.writeAsString(contents);
//   }
//
//   static Future<void> append(String filename, String contents) async {
//     var dir = await _getTempDir();
//
//     var file = File("${dir.path}/$filename");
//     await file.writeAsString(
//       ",$contents",
//       mode: FileMode.append,
//     );
//   }
//
//   static Future<List<Map<String, dynamic>>> readAsJson(String filename) async {
//     List<Map<String, dynamic>>? result;
//
//     try {
//       var dir = await _getTempDir();
//       var file = File("${dir.path}/$filename");
//
//       var data = await file.readAsString();
//       if (data.isNotEmpty) {
//         List decoded = jsonDecode('[${data.substring(1)}]');
//
//         result = decoded.cast<Map<String, dynamic>>();
//       }
//     } catch (_, stack) {
//       print(_);
//     print(stack);
//     }
//
//     return result ?? [];
//   }
//
//   static Future<bool> delete(String filename) async {
//     try {
//       var dir = await _getTempDir();
//       var file = File("${dir.path}/$filename");
//       await file.delete();
//       return true;
//     } catch (_) {}
//     return false;
//   }
//
//   static Future<String> read(String filename,
//       {bool destroyAfterReading = false}) async {
//     var result = '';
//     try {
//       var dir = await _getTempDir();
//       var file = File("${dir.path}/$filename");
//       result = await file.readAsString();
//       if (destroyAfterReading) {
//         await file.delete();
//       }
//     } catch (_) {}
//
//     return result;
//   }
//
//   static Future<Directory> _getTempDir() async {
//     var dir = Directory("${Directory.systemTemp.path}/__statsig__");
//     if (!await dir.exists()) {
//       await dir.create();
//     }
//
//     return dir;
//   }
// }
