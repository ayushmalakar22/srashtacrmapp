void main() {
  Map<String, dynamic> stats = {"a": 1};
  try {
    print('value: \$${stats['draft']}');
  } catch (e) {
    print('Error: $e');
  }
}
