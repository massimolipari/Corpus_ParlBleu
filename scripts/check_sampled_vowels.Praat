root_dir$ = "../align/"
sample_path$ = "../proto/vowels_sample_checked.csv"
output_path$ = "../proto/vowels_sample_checked.csv"

sample = Read Table from comma-separated file: sample_path$
n_row = Get number of rows
# Append column: "ok"
# Append column: "note"

ok_count = 0

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
        Play: phone_begin, phone_end
    endeditor

    beginPause: "Check"
        comment: "Row " + string$(i) + " of " + string$(n_row)
        comment: "Phone: " + phone$ + " (" + string$(ok_count) + " of 50 ok)"
        comment: "Should this token be used?"
        text: "Note", ""
    annot = endPause: "Yes", "No", 1

    selectObject: sound
    plusObject: tg
    Remove

    ok = 2 - annot
    ok_count = ok_count + ok

    selectObject: sample
    Set numeric value: i, "ok", ok
    Set string value: i, "note", note$
    Save as comma-separated file: output_path$

    # If there are already 50 ok tokens, skip to the next phone
    if ok_count >= 50
        i = i + 100 - (i mod 100)
        ok_count = 0
    endif
endfor

selectObject: sample
Remove
