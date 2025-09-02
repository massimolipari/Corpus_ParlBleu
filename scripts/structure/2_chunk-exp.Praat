# This script extracts all filled intervals from a long TextGrid and exports them (along with the corresponding sound file segment) into a speaker-specific directory.
# Output: The new files (TextGrids and WAVs) only, organized into folders by speaker (named according to their new IDs).
# Author: Massimo Lipari
# Created 2024-06-09
# Last updated: 2024-06-09

input_dir$ = "../corpus/exp/long/"
output_dir$ = "../corpus/exp/segm/"

createFolder: output_dir$

file_list = Create Strings as file list: "file_list", input_dir$ + "*.TextGrid"
n_files = Get number of strings

for i to n_files
    selectObject: file_list
    grid_name$ = Get string: i
    name$ = grid_name$ - ".TextGrid"
    sound_name$ = name$ + ".wav"

    # Open the files
    sound = Open long sound file: input_dir$ + sound_name$
    grid = Read from file: input_dir$ + grid_name$

    # Loop through the tiers
    selectObject: grid

    n_tiers = Get number of tiers

    for j to (n_tiers - 1)
		selectObject: grid
		tier_name$ = Get tier name: j
		speaker_dir$ = output_dir$ + tier_name$ + "/"
		createFolder: speaker_dir$

		# Loop through the intervals
		n_intervals = Get number of intervals: j
		n_filled_intervals = 0

		for k to n_intervals
			selectObject: grid
			interval_label$ = Get label of interval: j, k

			if interval_label$ <> ""
				n_filled_intervals = n_filled_intervals + 1
				start = Get start time of interval: j, k
				end = Get end time of interval: j, k

				temp1 = Extract part: start, end, 0
				temp2 = Extract one tier: j

				Save as text file: speaker_dir$ + tier_name$ + "_f" + string$(n_filled_intervals) + "_int" + string$(k) +  "_" + grid_name$

				selectObject: sound
				temp3 = Extract part: start, end, "no"
				Save as WAV file: speaker_dir$ + tier_name$ + "_f" + string$(n_filled_intervals) + "_int" + string$(k) +  "_" + sound_name$

				selectObject: temp1
				plusObject: temp2
				plusObject: temp3
				Remove
	    	endif
		endfor
    endfor

    selectObject: sound
    plusObject: grid
    Remove

endfor

selectObject: file_list
Remove