class Puzzle {
  final String id;
  final String title;
  final String description;
  final List<List<int>> grid;
  final List<List<int>> solution;
  final double bestTime;
  final String bestPlayerName;
  final List<String> hints;

  Puzzle({
    required this.id,
    required this.title,
    required this.description,
    required this.grid,
    required this.solution,
    required this.bestTime,
    required this.bestPlayerName,
    required this.hints,
  });

  factory Puzzle.fromJson(Map<String, dynamic> json) {
    return Puzzle(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      grid: (json['grid'] as List).map((row) => List<int>.from(row)).toList(),
      solution: (json['solution'] as List).map((row) => List<int>.from(row)).toList(),
      bestTime: (json['best_time'] as num).toDouble(),
      bestPlayerName: json['best_player_name'] as String,
      hints: List<String>.from(json['hints']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'grid': grid,
      'solution': solution,
      'best_time': bestTime,
      'best_player_name': bestPlayerName,
      'hints': hints,
    };
  }

  // Calculate number of rows and columns
  int get rows => grid.length;
  int get columns => getMaxColumns();

  // Get maximum number of columns across all rows
  int getMaxColumns() {
    int maxCols = 0;
    for (var row in grid) {
      if (row.length > maxCols) {
        maxCols = row.length;
      }
    }
    return maxCols;
  }

  // Clone the puzzle with a new grid
  Puzzle copyWith({
    String? id,
    String? title,
    String? description,
    List<List<int>>? grid,
    List<List<int>>? solution,
    double? bestTime,
    String? bestPlayerName,
    List<String>? hints,
  }) {
    return Puzzle(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      grid: grid ?? List.from(this.grid.map((row) => List<int>.from(row))),
      solution: solution ?? List.from(this.solution.map((row) => List<int>.from(row))),
      bestTime: bestTime ?? this.bestTime,
      bestPlayerName: bestPlayerName ?? this.bestPlayerName,
      hints: hints ?? List<String>.from(this.hints),
    );
  }

  // Check if the current grid matches the solution
  bool isSolved() {
    if (grid.length != solution.length) return false;
    
    for (int i = 0; i < grid.length; i++) {
      if (grid[i].length != solution[i].length) return false;
      
      for (int j = 0; j < grid[i].length; j++) {
        if (grid[i][j] != solution[i][j]) return false;
      }
    }
    
    return true;
  }

  // Find all empty tiles (represented by 0)
  List<List<int>> findAllEmptyTiles() {
    List<List<int>> emptyPositions = [];
    for (int i = 0; i < grid.length; i++) {
      for (int j = 0; j < grid[i].length; j++) {
        if (grid[i][j] == 0) {
          emptyPositions.add([i, j]);
        }
      }
    }
    return emptyPositions;
  }
  
  // This method is kept for backward compatibility
  List<int> findEmptyTile() {
    final emptyTiles = findAllEmptyTiles();
    return emptyTiles.isNotEmpty ? emptyTiles.first : [-1, -1];
  }
} 
