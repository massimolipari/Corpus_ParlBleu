from polyglotdb import CorpusContext

def main():
    corpus_name = 'ParlBleu'

    with CorpusContext(corpus_name) as c:
        c.reset()

if __name__ == '__main__':
    main()
