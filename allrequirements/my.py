import copy
import json
import random

def generate_solution():
    """
    Generates the solved 3x3 grid.
    - Pick 7 unique random numbers from 1 to 99.
    - Sort them in ascending order.
    - Fill the grid in row-major order with the first 7 numbers,
      and use 0 for the last two cells.
    
    For example, if sorted numbers are [1, 23, 58, 61, 75, 79, 84],
    the solution will be:
       [ [1, 23, 58],
         [61, 75, 79],
         [84, 0, 0] ]
    """
    numbers = sorted(random.sample(range(1, 100), 7))
    solution = [
        numbers[0:3],
        numbers[3:6],
        [numbers[6], 0, 0]
    ]
    return solution

def find_zero_positions(board):
    """Return a list of (row, col) positions for the zeros in the board."""
    return [(i, j) for i in range(3) for j in range(3) if board[i][j] == 0]

def get_adjacent(pos):
    """Return the valid adjacent positions in a 3x3 grid for a given position."""
    i, j = pos
    directions = [(-1, 0), (1, 0), (0, -1), (0, 1)]
    return [(i + di, j + dj) for di, dj in directions if 0 <= i + di < 3 and 0 <= j + dj < 3]

def get_possible_moves(board):
    """
    Returns a list of valid moves.
    Each move is a tuple ((from_row, from_col), (to_row, to_col)), where
    a nonzero tile from the "from" cell (adjacent to a zero cell) can slide into the "to" cell.
    """
    moves = []
    zeros = find_zero_positions(board)
    for z in zeros:
        for adj in get_adjacent(z):
            if board[adj[0]][adj[1]] != 0:  # There is a tile to move
                moves.append((adj, z))
    return moves

def apply_move(board, move):
    """
    Applies a move to the board by swapping the nonzero tile with the zero.
    Move is a tuple: ((from_row, from_col), (to_row, to_col)).
    """
    (fi, fj), (ti, tj) = move
    board[ti][tj], board[fi][fj] = board[fi][fj], board[ti][tj]
    return board

def scramble_board(solution, move_count):
    """
    Starts from the solved board and applies a given number of valid moves
    to scramble it.
    
    Args:
      solution: the solved board (sorted numbers with trailing zeros)
      move_count: the number of moves to apply
    
    Returns:
      the scrambled board.
    """
    board = copy.deepcopy(solution)
    last_move = None
    for _ in range(move_count):
        moves = get_possible_moves(board)
        # Avoid immediately reversing the previous move.
        if last_move:
            moves = [m for m in moves if not (m[0] == last_move[1] and m[1] == last_move[0])]
        if not moves:
            break  # Should not happen for a valid 3x3 board with two zeros.
        move = random.choice(moves)
        board = apply_move(board, move)
        last_move = move
    return board

def generate_puzzle_fixed(move_count):
    """
    Creates a puzzle by scrambling the solved board with exactly move_count moves.
    
    Returns:
      A tuple (scrambled grid, solution grid)
    """
    solution = generate_solution()
    puzzle = scramble_board(solution, move_count)
    # Ensure that the scrambled grid is not identical to the solution.
    if puzzle == solution:
        puzzle = scramble_board(solution, move_count + 1)
    return puzzle, solution

def main():
    puzzles = {}
    total_puzzles = 25

    # Create puzzles with IDs "puzzle5" to "puzzle29".
    # The move count is fixed as follows:
    #   - puzzle5: 2 moves
    #   - puzzle6: 3 moves
    #   - puzzle7: 5 moves
    #   - puzzle8: 6 moves
    #   - puzzle9 to puzzle29: moves increase linearly from 7 up to 25.
    for idx in range(1, total_puzzles + 1):
        puzzle_id_number = idx + 4  # This will produce numbers 5, 6, ... 29.
        puzzle_id = f"puzzle{puzzle_id_number}"
        title = f"Level {puzzle_id_number}"  # Title matches the puzzle id number.
        
        best_player_name = "Rohit"
        best_time = 0.0026
        description = "Arrange numbers in grid."
        difficulty = "easy"
        hints = ["Swap the numbers to match the solution."]
        
        if idx == 1:
            move_count = 2
        elif idx == 2:
            move_count = 3
        elif idx == 3:
            move_count = 5
        elif idx == 4:
            move_count = 6
        else:
            # For puzzles with idx 5 to 25 (i.e. IDs 9 to 29), interpolate from 7 up to 25 moves.
            move_count = round(7 + (25 - 7) * (idx - 5) / 20)
        
        grid, solution = generate_puzzle_fixed(move_count)
        
        puzzles[puzzle_id] = {
            "best_player_name": best_player_name,
            "best_time": best_time,
            "description": description,
            "difficulty": difficulty,
            "grid": grid,
            "hints": hints,
            "id": puzzle_id,
            "solution": solution,
            "title": title
        }
    
    # Write the puzzles to a JSON file.
    with open("puzzles.json", "w") as f:
        json.dump(puzzles, f, indent=2)
    
    print("Generated 'puzzles.json' with 25 puzzles (IDs puzzle5 to puzzle29) with proper grid and solution.")

if __name__ == "__main__":
    main()
