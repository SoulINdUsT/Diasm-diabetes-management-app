"""One query through the production answer path; offline unless --live-url is set."""
import argparse
import json
from pathlib import Path

from evaluate import live_answerer, offline_answerer


def cli():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('question', nargs='?', default='when should I exercise?')
    parser.add_argument('--language', choices=['en', 'bn'], default='en')
    parser.add_argument('--live-url')
    args = parser.parse_args()
    if args.live_url:
        ask = live_answerer(args.live_url)
    else:
        path = Path(__file__).resolve().parent.parent / 'ai-data/knowledge_base.json'
        ask = offline_answerer(json.loads(path.read_text(encoding='utf-8')))
    print(json.dumps(ask(args.question, args.language), ensure_ascii=True, indent=2))


if __name__ == '__main__':
    cli()
