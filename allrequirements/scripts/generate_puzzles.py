import json
import random
import copy
import os

def generate_puzzles():
    puzzles = {}
    
    # First, load existing puzzles as a template
    with open('allrequirements/firebaseStructure.json', 'r') as f:
        data = json.load(f)
        puzzles = data['numberquests']['puzzles']
    
    # Starting from puzzle31 to puzzle525
    for i in range(31, 526):
        level_num = i
        
        # Determine puzzle size and difficulty
        if i <= 100:
            difficulty = "medium"
            if i <= 50:
                size = 3
                best_time = 100 + i
            else:
                size = 4
                best_time = 150 + i
        elif i <= 250:
            difficulty = "hard"
            if i <= 150:
                size = 4
                best_time = 200 + i
            else:
                size = 5
                best_time = 250 + i
        else:
            difficulty = "expert"
            if i <= 350:
                size = 5
                best_time = 300 + i
            elif i <= 450:
                size = 6
                best_time = 350 + i
            else:
                size = 7
                best_time = 400 + i
        
        # Create a solved grid
        solution = []
        counter = 1
        for row in range(size):
            new_row = []
            for col in range(size):
                # Add two zeros at the end
                if row == size - 1 and (col == size - 1 or col == size - 2):
                    new_row.append(0)  # Two empty spaces at bottom-right
                else:
                    new_row.append(counter)
                    counter += 1
            solution.append(new_row)
        
        # Create a shuffled grid - we'll make more complex shuffles as the level increases
        grid = copy.deepcopy(solution)
        
        # More shuffling for higher levels
        shuffle_count = min(10 + i // 10, 500)
        
        # Find the two empty cells (0) - start with the first one
        empty1_row, empty1_col = size - 1, size - 2
        empty2_row, empty2_col = size - 1, size - 1
        
        # Perform random valid moves to shuffle
        for _ in range(shuffle_count):
            # Randomly choose which empty space to move
            if random.choice([True, False]):
                empty_row, empty_col = empty1_row, empty1_col
                other_empty_row, other_empty_col = empty2_row, empty2_col
            else:
                empty_row, empty_col = empty2_row, empty2_col
                other_empty_row, other_empty_col = empty1_row, empty1_col
            
            # Possible moves: up, down, left, right
            moves = []
            if empty_row > 0:
                # Don't move up if the other empty space is there
                if not (empty_row - 1 == other_empty_row and empty_col == other_empty_col):
                    moves.append((-1, 0))  # up
            if empty_row < size - 1:
                # Don't move down if the other empty space is there
                if not (empty_row + 1 == other_empty_row and empty_col == other_empty_col):
                    moves.append((1, 0))   # down
            if empty_col > 0:
                # Don't move left if the other empty space is there
                if not (empty_row == other_empty_row and empty_col - 1 == other_empty_col):
                    moves.append((0, -1))  # left
            if empty_col < size - 1:
                # Don't move right if the other empty space is there
                if not (empty_row == other_empty_row and empty_col + 1 == other_empty_col):
                    moves.append((0, 1))   # right
            
            if not moves:
                continue
                
            # Choose a random move
            dr, dc = random.choice(moves)
            new_empty_row, new_empty_col = empty_row + dr, empty_col + dc
            
            # Swap the empty cell with the chosen neighbor
            grid[empty_row][empty_col] = grid[new_empty_row][new_empty_col]
            grid[new_empty_row][new_empty_col] = 0
            
            # Update empty cell position
            if empty_row == empty1_row and empty_col == empty1_col:
                empty1_row, empty1_col = new_empty_row, new_empty_col
            else:
                empty2_row, empty2_col = new_empty_row, new_empty_col
        
        # Generate a hint based on level
        hint_types = [
            "Start by focusing on the top row.",
            "Work on positioning one row at a time.",
            "Move the empty spaces strategically.",
            "Try to get the first few numbers in place first.",
            "Focus on fixing the bottom row last.",
            "Solve the puzzle row by row.",
            "Start by fixing the numbers in the corners.",
            "Work methodically from top to bottom.",
            "Fix the positions of the largest numbers last.",
            "Use the two empty spaces to your advantage."
        ]
        
        hint = random.choice(hint_types)
        
        # Create the puzzle entry
        puzzle_id = f"puzzle{i}"
        puzzles[puzzle_id] = {
            "id": puzzle_id,
            "title": f"Level {i}",
            "description": "Arrange numbers in grid.",
            "grid": grid,
            "solution": solution,
            "best_time": best_time,
            "best_player_name": "",
            "hints": [hint],
            "difficulty": difficulty
        }
    
    # Update the data with all puzzles
    data['numberquests']['puzzles'] = puzzles
    
    # Save the full data back to a new file
    with open('allrequirements/firebaseStructure_full.json', 'w') as f:
        json.dump(data, f, indent=2)
    
    print(f"Generated {len(puzzles)} puzzles in total.")

if __name__ == "__main__":
    generate_puzzles() 