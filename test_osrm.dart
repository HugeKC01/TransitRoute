import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final url = 'https://router.project-osrm.org/route/v1/walking/100.5,13.7;100.51,13.71?overview=full&geometries=geojson';
  final response = await http.get(Uri.parse(url));
  print(response.statusCode);
  print(response.body.substring(0, 100));
}
