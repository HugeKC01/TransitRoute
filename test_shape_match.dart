void main() {
  final pointNames = ['N24', null, null, 'N23', null, 'N22'];
  final route = ['N22', 'N23', 'N24'];
  
  int? findIdx(String name) {
    for (int i=0; i<pointNames.length; i++) {
      if (pointNames[i] == name) return i;
    }
    return null;
  }
  
  final i1 = findIdx(route.first);
  final i2 = findIdx(route.last);
  print('i1: $i1, i2: $i2');
}
