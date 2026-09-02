import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
/** jsonDecode - turns JSON string into Dart object (Map or List)
 * jsonEncode - turns Dart object (Map or List) into JSON string
 */
import 'dart:convert';

Future<void> getAccessToken() async {
  final String clientId = dotenv.env['CLIENT_ID'] ?? '';
  final String clientSecret = dotenv.env['CLIENT_SECRET'] ?? '';

  final String credentials = base64Encode(
    utf8.encode('$clientId:$clientSecret'),
  );

  final response = await http.post(
    Uri.parse('https://oauth.fatsecret.com/connect/token'),
    headers: {
      'Authorization': 'Basic $credentials',
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: {'grant_type': 'client_credentials', 'scope': 'basic'},
  );

  if (response.statusCode == 200) {
    final Map<String, dynamic> body = jsonDecode(response.body);
    debugPrint(body.toString());
  } else {
    throw Exception('Failed to get access token: ${response.statusCode}');
  }
}

void main() async {
  await dotenv.load(fileName: ".env");
  await getAccessToken();
}
