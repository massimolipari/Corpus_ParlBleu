dir$ = "../align/"

folders = Create Strings as folder list: "folders", dir$
n_folders = Get number of strings

# Get words to change
un_words = Read Strings from raw text file: "../etc/un.txt"
n_un_words = Get number of strings

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

		# Loop through phone tier
		n_phones = Get number of intervals: 2

		for k to n_phones
			selectObject: grid

			# Get the label, check if it's ein
			phone_label$ = Get label of interval: 2, k

			# Step 1: correct "w a" to "wa"
			if phone_label$ == "w"
				phone_end = Get end time of interval: 2, k
				next_phone$ = Get label of interval: 2, k + 1

				if next_phone$ == "a"
					# Check that the next phone is still in the same word
					word_interval = Get low interval at time: 1, phone_end
					word_end = Get end time of interval: 1, word_interval

					if phone_end <> word_end
						Remove right boundary: 2, k
						k = k - 1 # Decrement the counter because an interval was removed
					endif
				endif
			endif

			# Step 2: Change /ɛ̃/ to /œ̃/ as needed
			if phone_label == "ɛ̃"
				phone_start = Get start time of interval: 2, k
				word_interval = Get interval at time: 1, phone_start
				word_label$ = Get label of interval: 1, word_interval

				word_start = Get start time of interval: 1, word_interval
				word_end = Get end time of interval: 1, word_interval

				first_phone = Get high interval at time: 2, word_start
				last_phone = Get low interval at time: 2, word_end

				phone_index_in_word = k - first_phone + 1

				transcription$ = ""
				for l from first_phone to last_phone
					l_label$ = Get label of interval: 2, l
					transcription$ = transcription$ + j_label$
				endfor

				selectObject: un_words
				word_row = List row numbers where: self$[row, "word"]=word_label$ & self$[row, "transcription"]=transcription$ & self[row, "index"]=phone_index_in_word

				fix = Get value: word_row, "fix"

				if fix == 1
					selectObject: grid
					Set interval text: 2, k, "œ̃" 
				endif
			endif

			# Step 3: Change /ɛ/ to /ɜ/ as needed

			# Step 4: Change /a/ to /ɑ/ as needed

		endfor

		selectObject: grid
		Save as text file: dir_temp$ + current_file$
		Remove
		
	endfor

	selectObject: files
	Remove

endfor

selectObject: folders
plusObject: un_words
Remove