clearinfo

form: "Get by-speaker breakdown of data length"
	text: "Dir", ""
	text: "Output dir", ""
endform

running_length = 0

table = Create Table with column names: "table", 0, {"speaker", "duration"}
folders = Create Strings as folder list: "folders", dir$
n_folders = Get number of strings



for i to n_folders
	speaker_length = 0

	selectObject: folders
	folder$ = Get string: i
	dir_temp$ = dir$ + folder$ + "/"

	files = Create Strings as file list: "files", dir_temp$ + "*.wav"

	n_files = Get number of strings

	for j to n_files
		selectObject: files
		current_file$ = Get string: j

		sound = Read from file: dir_temp$ + current_file$
		length = Get total duration
		speaker_length = speaker_length + length

		selectObject: sound
		Remove
	endfor

	selectObject: files
	Remove

	if (speaker_length > 0)
		appendInfoLine: "Speaker " + folder$ + " had a total duration of: " + string$(speaker_length) + " s."

		selectObject: table
		Append row
		curr_row = Get number of rows

		Set string value: curr_row, "speaker", folder$
		Set numeric value: curr_row, "duration", speaker_length
		running_length = running_length + speaker_length
	endif

endfor

selectObject: table
Save as comma-separated file: output_dir$

plusObject: folders
Remove

appendInfoLine: "COMPLETE. The total duration is: " + string$(running_length) + " s."