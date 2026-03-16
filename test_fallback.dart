void main() {
  String stopId = 'F_N20';
  String prefix = 'F_N2';
  bool matches = prefix == stopId ||
              (stopId.startsWith(prefix) &&
                  (prefix == 'F_' || !prefix.startsWith('F_')));
  print('Matches: \$matches');
}
