"""Source-preserving repairs for the nine live-review findings.

No index or medical content edits. Selected passages are copied from the existing
knowledge records. Protected passages must survive generation intact; this is a
text-fidelity check, not clinical validation or a general entailment validator.
"""
import re

from assistant_copy import COPY
from assistant_policy import contains, normalize_text


VERBATIM_CONTRACT = (
    'Return all supplied evidence text verbatim, in its supplied order, joined by spaces. '
    'Do not shorten, paraphrase, translate, add statements, or omit qualifications. '
    'Cite all supplied evidence IDs. This preservation rule takes precedence over '
    'the requested response language; unavailable translations are handled separately.'
)

# These records lost monitoring, escalation, causality, or grammatical meaning
# during free-form rewriting. Preserve the existing prose instead.
PRESERVE_RECORDS = {
    'basics_en_027', 'mental_en_006', 'complications_en_002',
    'complications_en_413', 'type2_en_034', 'exercise_en_005',
}


def qa_answer(source, question):
    return next((qa['answer'] for qa in source.get('qa_pairs', [])
                 if normalize_text(qa['question']) == normalize_text(question)), '')


def symptoms_need_assessment(question, intent):
    return intent == 'symptoms_risk' and contains(normalize_text(question), [
        'test', 'tests', 'tested', 'testing', 'screening', 'screened', 'diagnosis', 'diagnosed',
    ])


def prepare_evidence(row, intent, question, source):
    document = row['document']
    fields = ['retrieval_text']
    preserve = row['id'] in PRESERVE_RECORDS
    q = normalize_text(question)
    qa_question = None
    if row['id'] == 'nutrition_en_307' and contains(q, ['why', 'always', 'all the time']):
        qa_question = 'Why do I feel hungry all the time?'
    elif row['id'] == 'type2_en_032' and contains(q, ['protein']) and contains(q, ['urine']):
        qa_question = 'What are signs of kidney damage in diabetes?'
    if qa_question:
        answer = qa_answer(source, qa_question)
        if answer:
            # Hunger asks for an explanation first; kidney signs need their
            # nephropathy context first so "early stages" has a clear referent.
            document = (answer + ' ' + document if row['id'] == 'nutrition_en_307'
                        else document + ' ' + answer)
            fields.append('qa_pairs: ' + qa_question)
        preserve = True
    if row['id'] == 'exercise_en_008':
        # Reuse the existing safety boundary, including swallowing/consciousness.
        # That boundary is policy copy, not a claim that it occurs in the KB.
        document = COPY['low_glucose_actions'][0]
        fields = ['assistant_copy.COPY.low_glucose_actions.en']
        preserve = True
    elif row['id'] == 'exercise_en_010':
        # A general precautions answer does not need an interval that could be
        # mistaken for an individual target. Retain the source's nonnumeric
        # checking/avoidance guidance without introducing replacement thresholds.
        document = ' '.join([source['description']] + [
            sentence for sentence in re.split(r'(?<=[.!?])\s+', document)
            if not any(c.isdigit() for c in sentence)
        ])
        fields = ['description', 'retrieval_text: nonnumeric sentences']
        preserve = True
    elif symptoms_need_assessment(question, intent):
        if row['id'] == 'type2_en_006':
            # Supply testing evidence without importing diagnostic cutoffs.
            document = qa_answer(source, 'How is type 2 diabetes diagnosed?')
            fields = ['qa_pairs: How is type 2 diabetes diagnosed?']
        preserve = True
    return {**row, 'document': document, 'preserve_text': preserve, 'source_fields': fields}


def add_assessment_evidence(selected, knowledge):
    """Cover both the symptoms and assessment/testing facets, at most three IDs.

    These complementary records are read from the existing KB after candidate
    retrieval; no embeddings or Chroma documents need to change.
    """
    rows = [r for r in selected if r['id'] not in {'type2_en_003', 'type2_en_006'}][:1]
    for source_id in ['type2_en_003', 'type2_en_006']:
        source = knowledge.get(source_id)
        if source:
            rows.append(dict(id=source_id, document=source['retrieval_text'],
                             metadata=dict(title=source['section_title'], category=source['category']),
                             evidence_origin='knowledge_supplement'))
    return rows
