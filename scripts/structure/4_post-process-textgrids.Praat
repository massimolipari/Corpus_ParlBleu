dir$ = "../align/"

folders = Create Strings as folder list: "folders", dir$
n_folders = Get number of strings

# Get words to change
un_words = Read Table from comma-separated file: "../etc/un.csv"
e3_words = Read Table from comma-separated file: "../etc/3.csv"
ah_words = Read Table from comma-separated file: "../etc/ah.csv"


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

			# Get the label
			phone_label$ = Get label of interval: 2, k

			# Step 1: Change /ɛ̃/ to /œ̃/ as needed
			if phone_label$ == "ɛ̃"
				@get_transcription: k

				selectObject: un_words
				word_row = Extract rows where: "self$[""word""]=word_label$ & self$[""transcription""]=transcription$ & self[""index""]=phone_index_in_word"

				is_in_table = Get number of rows
				if is_in_table == 1
					fix = Get value: 1, "round"

					if fix == 1
						selectObject: grid
						Set interval text: 2, k, "œ̃"
					endif
				endif

				selectObject: word_row
				Remove
			endif

			# Step 2: Change /ɛ/ to /ɜ/ as needed
			selectObject: grid
			if phone_label$ == "ɛ"
				@get_transcription: k

				selectObject: e3_words
				word_row = Extract rows where: "self$[""word""]=word_label$ & self$[""transcription""]=transcription$ & self[""index""]=phone_index_in_word"

				is_in_table = Get number of rows
				if is_in_table == 1
					fix = Get value: 1, "long"

					if fix == 1
						selectObject: grid
						Set interval text: 2, k, "ɜ"
					endif
				endif

				selectObject: word_row
				Remove
			endif

			# Step 3: Change /a/ to /ɑ/ as needed
			selectObject: grid
			if phone_label$ == "a"
				@get_transcription: k

				selectObject: ah_words
				word_row = Extract rows where: "self$[""word""]=word_label$ & self$[""transcription""]=transcription$ & self[""index""]=phone_index_in_word"

				is_in_table = Get number of rows
				if is_in_table == 1
					fix = Get value: 1, "long"

					if fix == 1
						selectObject: grid
						Set interval text: 2, k, "ɑ"
					endif
				endif

				selectObject: word_row
				Remove
			endif

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
plusObject: e3_words
plusObject: ah_words
Remove

procedure get_transcription: .phone
	phone_start = Get start time of interval: 2, .phone
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

		if l_label$ == "œ̃"
			l_label$ = "ɛ̃"
		endif

		if l_label$ == "ɜ"
			l_label$ = "ɛ"
		endif

		if l_label$ == "ɑ" and word_label$ <> "saaremaa"
			l_label$ = "a"
		endif

		transcription$ = transcription$ + l_label$ + "."
	endfor
	
	transcription$ = transcription$ - "."
endproc
