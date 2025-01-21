import os
import shutil

input_grid_dir = '../corpus/exp/align'
input_wav_dir = '../corpus/exp/segm'
output_dir = '../test'

# Get list of speakers
speakers = [s for s in os.listdir(input_grid_dir) if os.path.isdir(os.path.join(input_grid_dir, s))]
print(speakers)

for speaker in speakers:
    # Create the folder in the destination if it doesn't already exist
    speaker_input_grid_dir = os.path.join(input_grid_dir, speaker)
    speaker_input_wav_dir = os.path.join(input_wav_dir, speaker)
    speaker_output_dir = os.path.join(output_dir, speaker)

    if not os.path.isdir(speaker_output_dir):
        os.mkdir(speaker_output_dir)

    # Get list of files
    files = [f for f in os.listdir(speaker_input_grid_dir) if f != '.DS_Store']

    for file in files:
        # Get input file names
        grid = os.path.join(speaker_input_grid_dir, file)

        wav_name = file.split('.')[0] + '.wav'
        wav = os.path.join(speaker_input_wav_dir, wav_name)

        # Make output paths
        grid_output = os.path.join(speaker_output_dir, file)
        wav_output = os.path.join(speaker_output_dir, wav_name)

        # Copy the TextGrid and WAV file to the new destination
        shutil.copy(grid, grid_output)
        shutil.copy(wav, wav_output)
