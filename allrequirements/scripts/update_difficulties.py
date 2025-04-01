import json

def update_difficulty_levels():
    # Load the combined file
    with open('allrequirements/firebaseStructure.json', 'r') as f:
        data = json.load(f)
        puzzles = data['numberquests']['puzzles']
    
    # Define the expected difficulty ranges
    difficulty_ranges = {
        (1, 16): "easy",
        (17, 100): "medium",
        (101, 250): "hard",
        (251, 525): "expert"
    }
    
    # Count before update
    difficulties_before = {}
    for puzzle in puzzles.values():
        diff = puzzle['difficulty']
        difficulties_before[diff] = difficulties_before.get(diff, 0) + 1
    
    # Update difficulty levels based on puzzle number
    changes_made = 0
    for i in range(1, 526):
        puzzle_id = f"puzzle{i}"
        if puzzle_id in puzzles:
            current_difficulty = puzzles[puzzle_id]['difficulty']
            
            # Determine expected difficulty for this puzzle
            expected_difficulty = None
            for (start, end), diff in difficulty_ranges.items():
                if start <= i <= end:
                    expected_difficulty = diff
                    break
            
            # Update if different
            if current_difficulty != expected_difficulty:
                puzzles[puzzle_id]['difficulty'] = expected_difficulty
                changes_made += 1
    
    # Count after update
    difficulties_after = {}
    for puzzle in puzzles.values():
        diff = puzzle['difficulty']
        difficulties_after[diff] = difficulties_after.get(diff, 0) + 1
    
    # Save the updated data
    with open('allrequirements/firebaseStructure.json', 'w') as f:
        json.dump(data, f, indent=2)
    
    # Print summary
    print(f"Made {changes_made} difficulty level changes")
    print("\nDifficulty distribution before:")
    for diff, count in difficulties_before.items():
        print(f"  {diff}: {count} puzzles")
    
    print("\nDifficulty distribution after:")
    for diff, count in difficulties_after.items():
        print(f"  {diff}: {count} puzzles")
    
    print("\nFinal difficulty breakdown:")
    print(f"  Easy (1-16): {difficulties_after.get('easy', 0)} puzzles")
    print(f"  Medium (17-100): {difficulties_after.get('medium', 0)} puzzles")
    print(f"  Hard (101-250): {difficulties_after.get('hard', 0)} puzzles")
    print(f"  Expert (251-525): {difficulties_after.get('expert', 0)} puzzles")

if __name__ == "__main__":
    update_difficulty_levels() 