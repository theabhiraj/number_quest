# No. Quest

A Flutter puzzle game app that dynamically fetches puzzles from Firebase Realtime Database. The puzzles can be of varying grid sizes (e.g., 3×3, 4×3, 6×6).

## Features

- Fetches puzzle data from Firebase Realtime Database
- Supports multiple puzzle sizes
- Interactive tile movement with two empty spaces
- Timer to track solving time
- Hints available for each puzzle
- Best time tracking and updating
- Responsive UI design

## Setup Instructions

### Prerequisites

- Flutter SDK (version 3.29.0 or later)
- Firebase account
- Android Studio / VS Code with Flutter extensions

### Firebase Setup

1. Create a Firebase project in the [Firebase Console](https://console.firebase.google.com/)
2. Add an Android app to your Firebase project
   - Use package name: `com.abhiraj.number_quest`
   - Register the app and download the `google-services.json` file
3. Place the `google-services.json` file in the `android/app` directory
4. Set up the Realtime Database
   - Create a Realtime Database in your Firebase project
   - Import the sample data structure below or create your own puzzles

### Sample Data Structure

```json
{
  "numberquests": {
    "puzzles": {
      "puzzle1": {
        "id": "puzzle1",
        "title": "3x3 Puzzle",
        "description": "Arrange numbers in a 3x3 grid.",
        "grid": [
          [1, 2, 3],
          [4, 5, 6],
          [7, 0, 0]
        ],
        "solution": [
          [1, 2, 3],
          [4, 5, 6],
          [7, 0, 0]
        ],
        "best_time": 120,
        "best_player_name": "xyz",
        "hints": ["Start from the top left corner."]
      }
      // Add more puzzles as needed
    }
  }
}
```

### Running the App

1. Clone the repository
2. Run `flutter pub get` to install dependencies
3. Connect a device or start an emulator
4. Run `flutter run` to start the app

## How to Play

1. Select a puzzle from the home screen
2. Tap on tiles adjacent to the empty spaces to move them
3. Try to arrange the numbers to match the solution pattern
4. View your time and the best time
5. Use hints if needed
6. Complete the puzzle as quickly as possible to set a new record!

## Technologies Used

- Flutter for UI
- Firebase Realtime Database for backend
- Dart programming language

## License

This project is licensed under the MIT License.

# No. Quest Puzzles

This repository contains 525 puzzles for the No. Quest game, organized from easiest to hardest difficulty levels.

## Puzzle Structure

Each puzzle follows this JSON structure:

```json
{
  "id": "puzzleX",
  "title": "Level X",
  "description": "Arrange numbers in grid.",
  "grid": [
    [1, 2, 3],
    [4, 5, 6],
    [7, 0, 0]
  ],
  "solution": [
    [1, 2, 3],
    [4, 5, 6],
    [7, 0, 0]
  ],
  "best_time": 120,
  "best_player_name": "",
  "hints": ["A hint to help solve the puzzle."],
  "difficulty": "easy"
}
```

## Puzzle Mechanics

- Each puzzle has exactly **two empty spaces** (represented by zeros)
- In the solution, the empty spaces are always positioned at the bottom-right corner
- Players need to slide tiles into the empty spaces to arrange numbers in order

## Difficulty Levels

The puzzles are categorized into the following difficulty levels:

- **Easy (1-16)**: Small 2x2 and 3x3 grids with simple moves
- **Medium (17-100)**: 3x3 and 4x4 grids with more complex arrangements
- **Hard (101-250)**: 4x4 and 5x5 grids requiring strategic thinking
- **Expert (251-525)**: 5x5, 6x6, and 7x7 grids with challenging configurations

## Grid Size Progression

- Levels 1-50: Mostly 3x3 grids
- Levels 51-150: Mostly 4x4 grids
- Levels 151-350: Mostly 5x5 grids
- Levels 351-450: Mostly 6x6 grids
- Levels 451-525: Mostly 7x7 grids

## Files

- `allrequirements/firebaseStructure.json`: Contains example puzzles
- `allrequirements/firebaseStructure_full.json`: Contains all 525 puzzles
- `scripts/generate_puzzles.py`: Script used to generate the puzzles

## Generation Method

The puzzles were generated using a Python script that:

1. Creates solved grids of appropriate sizes based on level, with two empty spaces
2. Performs an increasing number of random valid moves to shuffle the grid
3. Assigns appropriate difficulty levels, best times, and hints

Having two empty spaces adds strategic depth to the puzzles, as players can use both spaces to maneuver tiles more efficiently.
