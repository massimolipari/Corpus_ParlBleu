import polyglotdb.io as pgio
from polyglotdb import CorpusContext
import logging
import yaml
import os
import sys
import argparse

def main():
    # Set up logging to both the console and a file
    logging.basicConfig(
        level = logging.INFO,
        format = '%(asctime)s %(levelname)s: %(message)s',
        datefmt = '%Y-%m-%d %H:%M:%S',
        handlers = [
            logging.FileHandler(filename = './logs/polyglot.log', mode = 'w', encoding = 'UTF-8'),
            logging.StreamHandler(stream = sys.stdout)
        ]
    )

    arg_parser = argparse.ArgumentParser(description = 'Load corpus into PolyglotDB.')
    arg_parser.add_argument('-d', '--dir', help = 'Corpus root directory.',
                            action = 'store', default = '../align')
    arg_parser.add_argument('-c', '--corpus', help = 'Corpus name.',
                            action = 'store', default = 'ParlBleu')
    arg_parser.add_argument('-y', '--yaml', help = 'Path to YAML file.',
                            action = 'store', default = '../meta/corpus_meta.yaml')
    arg_parser.add_argument('-p', '--procedure', help = 'What procedure(s) to perform.',
                            action = 'extend', nargs = '+', choices = ['all', 'reset', 'import', 'phones', 'enrich', 'formants', 'query_vowels', 'query_vowel_formants', 'query_sibilants'], default = [])
    arg_parser.add_argument('-v', '--verbose', help = 'Set verbosity of output.',
                            action = 'store_true', default = True)
    
    args = arg_parser.parse_args()

    logging.info(f'PROCESSING {args.corpus}...')

    logging.info('Reading YAML file...')
    with open(args.yaml) as file:
        corpus_meta = yaml.safe_load(file)

    if 'reset' in args.procedure:
        reset_corpus(args.corpus)
    else: logging.info('Reset option not selected, skipping...')

    if 'import' in args.procedure:
        import_corpus(args.corpus, args.dir, args.verbose)
    else: logging.info('Import option not selected, skipping...')

    if 'phones' in args.procedure:
        logging.info('Summary of phoneset:')
        summarize_phoneset(args.corpus)

    if 'enrich' in args.procedure:
        enrich_corpus(args.corpus, args.dir, corpus_meta, args.verbose)
    else: logging.info('Enrichment option not selected, skipping...')

    if 'formants' in args.procedure:
        measure_formants(args.corpus, args.verbose)

    if 'query_vowels' in args.procedure:
        query_vowels(args.corpus, args.dir, args.verbose)
    else: logging.info('Vowel query option (no formants) not selected, skipping...')

    if 'query_vowel_formants' in args.procedure:
        query_vowel_formants(args.corpus, args.dir, args.verbose)
    else: logging.info('Vowel query option (formants) not selected, skipping...')

    if 'query_sibilants' in args.procedure:
        query_sibilants(args.corpus, args.dir, args.verbose)
    else: logging.info('Sibilant query option (no acoustics) not selected, skipping...')

    logging.info(f'COMPLETED PROCESSING FOR CORPUS {args.corpus}.')

def reset_corpus(corpus_name):
    logging.info('Resetting...')

    with CorpusContext(corpus_name) as c:
        c.reset()

def import_corpus(corpus_name, corpus_root, verbose):
    logging.info('Importing...')
    parser = pgio.inspect_mfa(corpus_root)
    parser.call_back = print

    with CorpusContext(corpus_name) as c:
        c.load(parser, corpus_root)

    if verbose:
        summarize_phoneset(corpus_name)

def summarize_phoneset(corpus_name):
    from polyglotdb.query.base.func import Count, Average

    with CorpusContext(corpus_name) as c:
        q = c.query_graph(c.phone).group_by(c.phone.label.column_name('phone'))
        results = q.aggregate(Count().column_name('count'), Average(c.phone.duration).column_name('average_duration'))
        for r in results:
            logging.info(f'The phone {r["phone"]} had {r["count"]} occurrences and an average duration of {r["average_duration"]}.')

def enrich_corpus(corpus_name, corpus_root, meta, verbose):
    logging.info('Enriching...')

    # Sibilant enrichment
    if verbose:
        logging.info(f'Creating sibilant subset...')
    with CorpusContext(corpus_name) as c:
        c.encode_type_subset('phone', meta['sibilants'], 'sibilant')

    # Vowel enrichment
    if verbose:
        logging.info(f'Creating vowel subset...')
    with CorpusContext(corpus_name) as c:
        c.encode_type_subset('phone', meta['vowels'], 'vowel')

    # Syllabic enrichment (uses vowel set if syllabics not specified)
    if verbose:
        logging.info(f'Creating syllabic subset...')
    with CorpusContext(corpus_name) as c:
        syllabics = meta['syllabics']

        if meta['syllabics'] is None:
            logging.info('No syllabic segments specified, using vowels...')
            syllabics = meta['vowels']

        c.encode_type_subset('phone', syllabics, 'syllabic')

    # Automatic syllabification
    logging.info('Encoding syllables...')
    with CorpusContext(corpus_name) as c:
        c.encode_syllables(syllabic_label = 'syllabic')
    
    # Utterance enrichment (using pauses)
    logging.info('Utterance enrichment...')
    if meta['pauses'] is None:
        raise Exception(f'No pause phone labels in the `pauses` line of the YAML file for corpus {corpus_name}.')

    with CorpusContext(corpus_name) as c:
        c.encode_pauses(meta['pauses'])
        c.encode_utterances(min_pause_length = 0.15)

    # Rate enrichment
    logging.info('Rate enrichment...')
    with CorpusContext(corpus_name) as c:
        c.encode_rate('utterance', 'syllable', 'speech_rate')
        c.encode_count('word', 'syllable', 'num_syllables')

def measure_formants(corpus_name, verbose):
    from polyglotdb.acoustics.formants.refined import analyze_formant_points_refinement

    vowel_prototypes_path = '../meta/prototypes.csv'

    with CorpusContext(corpus_name) as c:
        c.config.praat_path = os.path.expanduser('~/praat')

        logging.info("Refined formant calculations...")
        analyze_formant_points_refinement(c,
                                            duration_threshold = 0.05,
                                            num_iterations = 20,
                                            vowel_prototypes_path = vowel_prototypes_path,
                                            drop_formant = False,
                                            output_tracks = True)

def query_utterances(corpus_name, corpus_root, verbose):
    logging.info('Querying utterances...')
    export_path = os.path.join(corpus_root, f'./data/{corpus_name}_utterances.csv')

    with CorpusContext(corpus_name) as c:
        q = c.query_graph(c.utterance)
        
        # Copied from the SPADE utterance extraction format (on GitHub: MontrealCorpusTools/SPADE/utterances.py)
        q = q.columns(c.utterance.speaker.name.column_name('speaker'),
                        c.utterance.id.column_name('utterance_label'),
                        c.utterance.begin.column_name('utterance_begin'),
                        c.utterance.end.column_name('utterance_end'),
                        c.utterance.following.begin.column_name('following_utterance_begin'),
                        c.utterance.following.end.column_name('following_utterance_end'),
                        c.utterance.speech_rate.column_name('speech_rate'),
                        c.utterance.discourse.name.column_name('discourse'),
                        c.utterance.discourse.speech_begin.column_name('discourse_begin'),
                        c.utterance.discourse.speech_end.column_name('discourse_end'),
                        )

        logging.info(f'Exporting full query to {export_path}...')
        q.to_csv(export_path)

def query_vowels(corpus_name, corpus_root, verbose):
    logging.info('Querying the corpus for all vowels (no formants)...')
    export_path = os.path.join(corpus_root, f'../extract/{corpus_name}_vowels.csv')

    # Get all vowels
    with CorpusContext(corpus_name) as c:

        q = c.query_graph(c.phone)
        q.filter(c.phone.subset == 'vowel',
                 c.phone.duration >= 0.05,
                 )
        
        q = q.columns(c.phone.discourse.name.column_name('discourse'),
                      c.phone.utterance.speaker.name.column_name('speaker'),
                      c.phone.label.column_name('phone'),
                      c.phone.duration.column_name('phone_duration'),
                      c.phone.begin.column_name('phone_begin'),
                      c.phone.end.column_name('phone_end'),
                      c.phone.word.phone.position.column_name('phone_position'),
                      c.phone.previous.label.column_name('previous_phone'),
                      c.phone.following.label.column_name('following_phone'),
                      c.phone.following.following.label.column_name('following_following_phone'),
                      c.phone.syllable.label.column_name('syllable'),
                      c.phone.syllable.begin.column_name('syllable_begin'),
                      c.phone.syllable.end.column_name('syllable_end'),
                      c.phone.word.label.column_name('word'),
                      c.phone.word.transcription.column_name('transcription'),
                      c.phone.syllable.word.begin.column_name('word_begin'),
                      c.phone.syllable.word.end.column_name('word_end'),
                      c.phone.syllable.word.utterance.begin.column_name('utterance_begin'),
                      c.phone.syllable.word.utterance.begin.column_name('utterance_end'),
                      c.phone.syllable.word.utterance.speech_rate.column_name('utterance_speech_rate'),
                      )

        logging.info(f'Exporting full query to {export_path}...')
        q.to_csv(export_path)

def query_vowel_formants(corpus_name, corpus_root, verbose):
    logging.info('Querying the corpus for all vowels (with formants)...')
    export_path = os.path.join(corpus_root, f'../extract/{corpus_name}_vowels.csv')

    # Get all vowels
    with CorpusContext(corpus_name) as c:

        q = c.query_graph(c.phone)
        q.filter(c.phone.subset == 'vowel',
                 c.phone.duration >= 0.05,
                 )
        
        formants_prop = c.phone.formants
        formants_prop.relative_time = True
        formants_track = formants_prop.interpolated_track
        formants_track.num_points = 21
        
        q = q.columns(c.phone.discourse.name.column_name('discourse'),
                      c.phone.utterance.speaker.name.column_name('speaker'),
                      c.phone.label.column_name('phone'),
                      c.phone.duration.column_name('phone_duration'),
                      c.phone.begin.column_name('phone_begin'),
                      c.phone.end.column_name('phone_end'),
                      c.phone.word.phone.position.column_name('phone_position'),
                      c.phone.previous.label.column_name('previous_phone'),
                      c.phone.following.label.column_name('following_phone'),
                      c.phone.following.following.label.column_name('following_following_phone'),
                      c.phone.syllable.label.column_name('syllable'),
                      c.phone.syllable.begin.column_name('syllable_begin'),
                      c.phone.syllable.end.column_name('syllable_end'),
                      c.phone.word.label.column_name('word'),
                      c.phone.word.transcription.column_name('transcription'),
                      c.phone.syllable.word.begin.column_name('word_begin'),
                      c.phone.syllable.word.end.column_name('word_end'),
                      c.phone.syllable.word.utterance.begin.column_name('utterance_begin'),
                      c.phone.syllable.word.utterance.begin.column_name('utterance_end'),
                      c.phone.syllable.word.utterance.speech_rate.column_name('utterance_speech_rate'),
                      formants_track
                      )

        logging.info(f'Exporting full query to {export_path}...')
        q.to_csv(export_path)

def query_sibilants(corpus_name, corpus_root, verbose):
    logging.info('Querying sibilants...')
    export_path = os.path.join(corpus_root, f'./data/{corpus_name}_sibilants.csv')

    logging.info('Querying the corpus for all sibilants...')
    # Get all sibilants
    with CorpusContext(corpus_name) as c:

        q = c.query_graph(c.phone)

        q.filter(c.phone.subset == 'sibilant',
                 )
        
        q = q.columns(c.phone.discourse.name.column_name('discourse'),
                      c.phone.utterance.speaker.name.column_name('speaker'),
                      c.phone.label.column_name('phone'),
                      c.phone.duration.column_name('phone_duration'),
                      c.phone.begin.column_name('phone_begin'),
                      c.phone.end.column_name('phone_end'),
                      c.phone.word.phone.position.column_name('phone_position'),
                      c.phone.previous.label.column_name('previous_phone'),
                      c.phone.following.label.column_name('following_phone'),
                      c.phone.following.following.label.column_name('following_following_phone'),
                      c.phone.syllable.label.column_name('syllable'),
                      c.phone.syllable.begin.column_name('syllable_begin'),
                      c.phone.syllable.end.column_name('syllable_end'),
                      c.phone.word.label.column_name('word'),
                      c.phone.word.transcription.column_name('transcription'),
                      c.phone.syllable.word.begin.column_name('word_begin'),
                      c.phone.syllable.word.end.column_name('word_end'),
                      c.phone.syllable.word.utterance.begin.column_name('utterance_begin'),
                      c.phone.syllable.word.utterance.begin.column_name('utterance_end'),
                      c.phone.syllable.word.utterance.speech_rate.column_name('utterance_speech_rate'),
                      )

        logging.info(f'Exporting full query to {export_path}...')
        q.to_csv(export_path)

if __name__ == '__main__':
    main()
