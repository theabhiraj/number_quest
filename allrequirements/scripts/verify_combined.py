import json

def verify_combined_puzzles():
    # Load the combined file
    with open('allrequirements/firebaseStructure.json', 'r') as f:
        data = json.load(f)
        puzzles = data['numberquests']['puzzles']
    
    # Check if we have all 525 puzzles
    puzzle_count = len(puzzles)
    if puzzle_count != 525:
        print(f"Error: Expected 525 puzzles, but found {puzzle_count}")
        return
    
    # Verify that all puzzles from 1 to 525 are present
    missing_puzzles = []
    for i in range(1, 526):
        puzzle_id = f"puzzle{i}"
        if puzzle_id not in puzzles:
            missing_puzzles.append(puzzle_id)
    
    if missing_puzzles:
        print(f"Error: Missing {len(missing_puzzles)} puzzles: {missing_puzzles}")
        return
    
    # Verify the difficulty levels
    expected_difficulty = {
        (1, 16): "easy",
        (17, 100): "medium",
        (101, 250): "hard",
        (251, 525): "expert"
    }
    
    difficulty_errors = []
    for i in range(1, 526):
        puzzle_id = f"puzzle{i}"
        puzzle = puzzles[puzzle_id]
        
        # Determine expected difficulty for this puzzle
        expected = None
        for (start, end), diff in expected_difficulty.items():
            if start <= i <= end:
                expected = diff
                break
        
        if puzzle['difficulty'] != expected:
            difficulty_errors.append(f"Puzzle {i}: expected '{expected}', found '{puzzle['difficulty']}'")
    
    if difficulty_errors:
        print(f"Error: Found {len(difficulty_errors)} difficulty level issues:")
        for error in difficulty_errors[:10]:  # Show only first 10 errors
            print(f"  {error}")
        if len(difficulty_errors) > 10:
            print(f"  ... and {len(difficulty_errors) - 10} more errors")
        return
    
    # Check some specific puzzles to ensure they're from the expected source
    examples = [1, 15, 30]
    generated = [31, 100, 250, 525]
    
    print("Verification successful! All 525 puzzles are present with correct difficulty levels.")
    print("\nSample puzzles:")
    
    for i in examples + generated:
        puzzle_id = f"puzzle{i}"
        puzzle = puzzles[puzzle_id]
        print(f"Puzzle {i}: {puzzle['difficulty']} - Grid size: {len(puzzle['grid'])}x{len(puzzle['grid'][0])}")

if __name__ == "__main__":
    verify_combined_puzzles() 