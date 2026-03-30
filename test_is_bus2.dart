void main() {
  final id = 'PK22';
  bool isNonBus = false;
  final nonBusPrefixes = ['CEN','E','N','S','W','RN','RW','BL','PK','YL','A','PP','F_','SRT'];
  for (final p in nonBusPrefixes) {
    if (id.startsWith(p) && !id.startsWith('ST_')) {
      isNonBus = true;
      break;
    }
  }
  print('isNonBus: \$isNonBus');
}
