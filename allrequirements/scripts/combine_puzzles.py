import json
import os
import shutil

def combine_puzzle_files():
    # Load example puzzles (1-30) from firebaseStructure.json
    with open('allrequirements/firebaseStructure.json', 'r') as f:
        example_data = json.load(f)
        example_puzzles = example_data['numberquests']['puzzles']
    
    # Load generated puzzles (31-525) from firebaseStructure_full.json
    with open('allrequirements/firebaseStructure_full.json', 'r') as f:
        full_data = json.load(f)
        full_puzzles = full_data['numberquests']['puzzles']
    
    # Create a new combined puzzles dictionary
    combined_puzzles = {}
    
    # Add example puzzles (1-30) first
    for key, value in example_puzzles.items():
        combined_puzzles[key] = value
    
    # Add generated puzzles (31-525)
    for key, value in full_puzzles.items():
        if key not in combined_puzzles:  # Skip duplicates
            combined_puzzles[key] = value
    
    # Create the final data structure
    combined_data = {
        "numberquests": {
            "puzzles": combined_puzzles
        }
    }
    
    # Count puzzles in each file
    example_count = len(example_puzzles)
    full_count = len(full_puzzles)
    combined_count = len(combined_puzzles)
    
    print(f"Example puzzles: {example_count}")
    print(f"Full puzzles: {full_count}")
    print(f"Combined puzzles: {combined_count}")
    
    # Check if we have all 525 puzzles
    if combined_count == 525:
        print("Successfully combined all 525 puzzles!")
        
        # Create a backup of the original file
        backup_path = 'allrequirements/firebaseStructure_backup.json'
        shutil.copy2('allrequirements/firebaseStructure.json', backup_path)
        print(f"Original file backed up to {backup_path}")
        
        # Save the combined data directly to firebaseStructure.json
        with open('allrequirements/firebaseStructure.json', 'w') as f:
            json.dump(combined_data, f, indent=2)
        print("firebaseStructure.json has been updated with all 525 puzzles.")
    else:
        print(f"Warning: Expected 525 puzzles, but got {combined_count}.")
        print("Please check for duplicates or missing puzzles.")

if __name__ == "__main__":
    combine_puzzle_files() 