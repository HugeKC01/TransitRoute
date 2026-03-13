void main() {
  final pointNames = ['W1', null, null, null, null, null, null, null, 'S1'];
  
  void findPath(String sA, String sB) {
    List<int> aLocs = [];
    List<int> bLocs = [];
    for(int i=0; i<pointNames.length; i++){
      if(pointNames[i] == sA) aLocs.add(i);
      if(pointNames[i] == sB) bLocs.add(i);
    }
    
    if(aLocs.isNotEmpty && bLocs.isNotEmpty) {
      int bestGap = 999999;
      int bestA = -1;
      int bestB = -1;
      for(int a in aLocs) {
        for (int b in bLocs) {
          int gap = (a - b).abs();
          if (gap < bestGap) {
            bestGap = gap;
            bestA = a;
            bestB = b;
          }
        }
      }
      print('A:$sA, B:$sB -> bestA: $bestA, bestB: $bestB');
    } else {
      print('Not found $sA -> $sB');
    }
  }

  findPath('W1', 'CEN');
  findPath('CEN', 'S1');
}
