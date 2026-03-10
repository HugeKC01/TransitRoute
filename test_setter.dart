class MyClass {
  String? _id;
  String? get id => _id;
  set id(String? newId) {
    _id = newId;
  }
}
void main() {
  var c = MyClass();
  c.id = "hello";
  print(c.id);
}
