AssNat Corpus: A time aligned corpus of political debates from the national assemblies of France and Québec

Approximately 18 hours of recorded proceedings from the national assemblies of both France (9 hours) and Québec (9 hours) that occured in the month of May, 2011.

The transcriptions provided by the national assemblies were re-transcribed manually to reflect, as much as possible, the verbatim audio record. This includes speech hesitations, dysfluencies, repetitions as well as background noise and non-speech sounds such as laughter, cough, etc.

Each individual speaker's turn is reflected in a unique short audio file. Longer speaker turns of several minutes were broken into approximately 100 second intervals at obvious pauses, which do not always reflect a sentence or other grammatical boundary.

The entire corpus was manually coded into IPA phonetic symbols reflecting the actual pronunciation of words. This IPA transcription was used for training the acoustic models. The forced alignment present in the text grids is the result of actual forced alignment using the orthographic transcription and are therefore not 100% in agreement with the manual phonetic transcription. However, I do have results presented in my thesis that show the results are not statistically different from what we might expect had the corpus been phonetically transcribed by different researchers (ie, the difference between automatic and manual is not significantly different from what we might expect the difference to be between manual and manual, given the published levels of disagreement between different human coders).

The acoustic models themselves are 8 Gaussian mixture, cross-word, context dependent, speaker adapted triphones. A complete description of the process of creating, training, and testing the models is given in my thesis (to be submitted soon, soon soon...). Cross-word triphones means, among other things, that the 'sp' phone is appended to each word in the dictionary, and is not a word on it's own. This is different from the P2FA aligner, which uses monophones. Triphones also mean that the phone you are interested in is the middle one (eg. for a triphone labelled ?-X+?, you want the X). The choice of triphone label is determined by HTK during state tying and sometimes look wonky.

You will notice there are more wav files (1173) than text grids (963). This is because some audio files crapped out during training and were discarded, though they remain in the wav folder. Use the list of text grids as any reference for finding and opening wav files.

The naming of files is straight-forward: ABC123-1. The first three letters stand for the dialect: ANQ = Québec and FNQ = France (why I chose FNQ I don't remember, but there it is). The three digits before the dash are speaker identifiers. The digit(s) after the dash indicate the unique turn for that particular speaker.

I have included the AssNatAligned.mlf file, from which the text grids were generated, since it is sometimes easier to work from that single file than from a bunch of smaller text grids. Depends on what you are looking at/for.

Please let me know if you need any help and/or further information or documentation.

Peter Milne
