root_dir$ = "../align/"
sample_path$ = "../proto/vowels_sample_checked.csv"
output_root$ = "../proto/"

buffer = 0.027

createFolder(output_root$ + "male/")
createFolder(output_root$ + "male/sounds/")
createFolder(output_root$ + "female/")
createFolder(output_root$ + "female/sounds/")

sample = Read Table from comma-separated file: sample_path$
n_row = Get number of rows

for i to n_row
    selectObject: sample
    ok = Get value: i, "ok"

    if ok == 1
        speaker$ = Get value: i, "speaker"
        speaker_dir$ = root_dir$ + speaker$ + "/"

        if i <= 1700
            gender$ = "female/"
        else
            gender$ = "male/"
        endif

        discourse$ = Get value: i, "discourse"
        sound_path$ = speaker_dir$ + discourse$ + ".wav"

        phone$ = Get value: 1, "phone"
        phone_begin = Get value: i, "phone_begin"
        phone_end = Get value: i, "phone_end"
        
        sound = Read from file: sound_path$
        Extract part: phone_begin - buffer, phone_end + buffer, "rectangular", 1, "no"

        file_name$ = string$(i) + "_" + phone$ + "_" + discourse$ + ".wav"
        Save as WAV file: output_root$ + gender$ + "sounds/" + file_name$

        plusObject: sound
        Remove
    endif
endfor

selectObject: sample
Remove
