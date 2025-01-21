# This script performs several manipulations on Peter's original TextGrids, while also changing the file hierarchy.
# Output: The ANQ files (TextGrids and WAVs) only, with UTF-8 TextGrids that look more like the MFA output, organized into folders by speaker (named according to their new IDs).
# Author: Massimo Lipari
# Created: 2024-05-19
# Last updated: 2024-05-19
# NOTE: WAV files with no corresponding TextGrid (failed alignment) will not be copied.
# TODO: Rename the individual files too, once the naming scheme has been finalized.

# Get the preference for file encoding (code from Jose Joaquin Atria, https://gitlab.com/cpran/plugin_serialise/blob/master/procedures/preferences.proc)
.file$ = if unix      then "prefs5"           else
  ...    if windows   then "Preferences5.ini" else
  ...    if macintosh then "Prefs5"           else
  ...    "--undefined--" fi fi fi

.file$ = preferencesDirectory$ + "/" + .file$
.preferences$ = readFile$(.file$)
.output$ = extractLine$(.preferences$, "TextEncoding.outputEncoding: ")

# Use a more standard encoding for TextGrids than the original corpus
Text writing preferences: "UTF-8"

root_dir$ = "../corpus/AssNat/"
grid_dir$ = root_dir$ + "AlignedGrids/"
sound_dir$ = root_dir$ + "WAV/"

output_root$ = "../align/"

# Load the lookup table for converting from old speaker IDs to new ones
lookup_dir$ = "../meta/id.csv"
lookup = Read Table from comma-separated file: lookup_dir$

# Loop through the (ANQ) TextGrids, peform cleanup, save files in new location
grid_list = Create Strings as file list: "grid_list", grid_dir$ + "ANQ*.TextGrid"
n_grids = Get number of strings

for i to n_grids
    selectObject: grid_list
    grid_name$ = Get string: i
    grid = Read from file: grid_dir$ + grid_name$

    # Get the new ID number associate with the speaker, create the folder (if it doesn't already exist)
    id_old = number(right$(left$(grid_name$, 6), 3))

    selectObject: lookup
    n_row = Search column: "id_original", string$(id_old)
    id_new = Get value: n_row, "id"

    speaker_dir$ = output_root$ + string$(id_new) + "/"
    createFolder: speaker_dir$

    # Clean up the TextGrid
    selectObject: grid

    # Step 1. Isolate pauses (currently attached to previous word)

    # Get the total number of elements on the phone tier
    n_segs = Get number of intervals: 1

    # Loop through the phone tier, add boundaries before pauses
    for j to n_segs
      phone_label$ = Get label of interval: 1, j

      if phone_label$ == "sp"
        start = Get start time of interval: 1, j
        end = Get end time of interval: 1, j

        # Create a new word for the silence, set a label (in curly braces)
        nocheck Insert boundary: 2, start
        word_interval = Get interval at time: 2, start
        Set interval text: 2, word_interval, "{" + phone_label$ + "}"
      endif
    endfor

    # Step 2. Rearrange the tiers, change the names (match MFA output, mainly for ease of use with PGDB)
    Duplicate tier: 2, 1, "words"
    Remove tier: 3
    Set tier name: 2, "phones"

    # Save the TextGrid in the new location
    Save as text file: speaker_dir$ + grid_name$
    Remove

    # Open, copy, and remove the corresponding WAV file
    sound_name$ = grid_name$ - ".TextGrid" + ".wav"
    sound = Read from file: sound_dir$ + sound_name$
    Save as WAV file: speaker_dir$ + sound_name$
    Remove
endfor

selectObject: grid_list
plusObject: lookup
Remove

# Restore the original output setting
Text writing preferences: .output$
