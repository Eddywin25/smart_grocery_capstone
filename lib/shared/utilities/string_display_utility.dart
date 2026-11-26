

// Extension utility for string formating for data display
extension StringDisplayUtility on String {

  // Capitalize a string
  String get capitalized {
    if (isEmpty) return this;

    return this[0].toUpperCase() +
        substring(1).toLowerCase();
  }

  // Convert a string to title case
  String get titleCase {
    return split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : word[0].toUpperCase() +
                    word.substring(1).toLowerCase(),
        )
        .join(' ');
  }
}

// Extension utility for determining grammar based on quantity of items
extension GrammerCount on int {

  String itemReference() {
    return this == 1
        ? 'item'
        : 'items';
  }

  String needReference() {
    return this == 1
        ? 'needs'
        : 'need';
  }
}