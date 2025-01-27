root_dir$ = "../align/"
sample_path$ = "../proto/vowels_sample.csv"
output_path$ = "../proto/vowels_sample_checked.csv"

sample = Read Table from comma-separated file: sample_path$
n_row = Get number of rows
Append column: "ok"
Append column: "note"

for i to n_row
    selectObject: sample
    speaker$ = Get value: i, "speaker"
    speaker_dir$ = root_dir$ + speaker$ + "/"

    discourse$ = Get value: i, "discourse"
    sound_path$ = speaker_dir$ + discourse$ + ".wav"
    tg_path$ = sound_path$ - ".wav" + ".TextGrid"

    phone$ = Get value: i, "phone"
    phone_begin = Get value: i, "phone_begin"
    phone_end = Get value: i, "phone_end"
    
    sound = Read from file: sound_path$
    tg = Read from file: tg_path$

    plusObject: sound

    View & Edit
    editor: tg
        Zoom: phone_begin - 0.5, phone_end + 0.5
        Select: phone_begin, phone_end
    endeditor

    beginPause: "Check"
        comment: "Phone: " + phone$
        comment: "Should this token be used?"
        text: "Note", ""
    annot = endPause: "Yes", "No", 1

    selectObject: sound
    plusObject: tg
    Remove

    selectObject: sample
    Set numeric value: i, "ok", 2 - annot
    Set string value: i, "note", note$
endfor

selectObject: sample
    Save as comma-separataed file: output_path$
	Remove
