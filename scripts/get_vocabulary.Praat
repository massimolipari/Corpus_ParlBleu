dir$ = "../align/"

folders = Create Strings as folder list: "folders", dir$
n_folders = Get number of strings

vocabulary_output$ = "../etc/vocabulary.tsv"
writeFileLine: vocabulary_output$, "word" + tab$ + "transcription"

for i to n_folders
	selectObject: folders
	folder$ = Get string: i
	dir_temp$ = dir$ + folder$ + "/"

	files = Create Strings as file list: "files", dir_temp$ + "*.TextGrid"
	n_files = Get number of strings

	for j to n_files
		selectObject: files
		current_file$ = Get string: j

		grid = Read from file: dir_temp$ + current_file$

		# Loop through word tier
		n_words = Get number of intervals: 1

		for k to n_words
			selectObject: grid

            word_label$ = Get label of interval: 1, k

            if word_label$ <> ""
				word_start = Get start time of interval: 1, k
                word_end = Get end time of interval: 1, k

				first_phone = Get high interval at time: 2, word_start
				last_phone = Get low interval at time: 2, word_end

				transcription$ = ""
				for l from first_phone to last_phone
					l_label$ = Get label of interval: 2, l
					transcription$ = transcription$ + l_label$
				endfor

                appendFileLine: vocabulary_output$, word_label$ + tab$ + transcription$
            endif
		endfor

		selectObject: grid
		Remove
	endfor

	selectObject: files
	Remove
endfor

selectObject: folders
Remove