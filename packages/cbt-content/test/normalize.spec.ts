import { describe, expect, it } from 'vitest';
import { normalizeBank } from '../src/normalize';

const BOM = '\uFEFF';

describe('cbt-content normalizeBank — real-world shape coverage', () => {
  it('shape 1+3: bare array, lowercase option record, lowercase answer letter (jamb biology)', () => {
    const { bundle, key, report } = normalizeBank(
      JSON.stringify([
        {
          question: 'Which organelle is known as the powerhouse of the cell?',
          option: { a: 'Nucleus', b: 'Ribosome', c: 'Mitochondrion', d: 'Golgi apparatus' },
          answer: 'c',
          explanation: 'Mitochondria produce ATP.',
        },
      ]),
      'biology.json',
    );
    expect(bundle.code).toBe('biology');
    expect(bundle.questions[0].options).toEqual({ A: 'Nucleus', B: 'Ribosome', C: 'Mitochondrion', D: 'Golgi apparatus' });
    expect(key.answers[bundle.questions[0].id]).toMatchObject({ type: 'mcq', letter: 'C', explanation: 'Mitochondria produce ATP.' });
    // explanation must NEVER leak into the bundle
    expect(JSON.stringify(bundle)).not.toContain('ATP');
    expect(report.kept).toBe(1);
  });

  it('shape 2: {course,title,questions[]} wrapper with uppercase options (sen101)', () => {
    const { bundle, key } = normalizeBank(
      JSON.stringify({
        course: 'SEN 101',
        title: 'Web Tech',
        total: 1,
        questions: [
          {
            id: 1,
            question: 'What does HTML stand for?',
            options: { A: 'Hyper Text Markup Language', B: 'Nope', C: 'Nope 2', D: 'Nope 3' },
            answer: 'A',
          },
        ],
      }),
      'sen101_questions.json',
    );
    expect(bundle.code).toBe('sen101'); // _questions suffix stripped
    expect(bundle.title).toBe('Web Tech');
    expect(key.answers['1']).toMatchObject({ letter: 'A' });
  });

  it('BOM is stripped and file parses (english.json regression)', () => {
    const { bundle } = normalizeBank(
      BOM + JSON.stringify([{ question: 'Pick B', option: { a: 'x', b: 'why B', c: 'y', d: 'z' }, answer: 'b' }]),
      'english.json',
    );
    expect(bundle.questionCount).toBe(1);
  });

  it('shape 4: options as [{letter,text,correct}] objects (COS102) + correct_letter', () => {
    const { bundle, key } = normalizeBank(
      JSON.stringify({
        questions: [
          {
            id: 1,
            section: 'Intro',
            question: 'Computing is fundamentally about:',
            options: [
              { letter: 'A', text: 'Faster hardware', correct: false },
              { letter: 'B', text: 'Solving problems', correct: true },
            ],
            correct_letter: 'B',
          },
          {
            id: 2,
            question: 'Flag derived from correct:true when no letter given',
            options: [
              { letter: 'A', text: 'Wrong', correct: false },
              { letter: 'B', text: 'Right', correct: true },
            ],
          },
        ],
      }),
      'COS102_500.json',
    );
    expect(bundle.code).toBe('cos102');
    expect(key.answers['1']).toMatchObject({ letter: 'B' });
    expect(key.answers['2']).toMatchObject({ letter: 'B' }); // derived from correct flag
    expect(bundle.questions[0].options).toEqual({ A: 'Faster hardware', B: 'Solving problems' });
  });

  it('shape 5: answers[] of accepted texts => text question (CVE105)', () => {
    const { bundle, key, report } = normalizeBank(
      JSON.stringify({
        questions: [
          { id: 1, question: 'What is the systematic way of acquiring knowledge?', answers: ['Science', 'science', 'SCIENCE'] },
        ],
      }),
      'CVE105.json',
    );
    expect(bundle.questions[0].type).toBe('text');
    expect(bundle.questions[0].options).toBeUndefined();
    expect(key.answers['1']).toMatchObject({ type: 'text', accepted: ['Science', 'science', 'SCIENCE'] });
    expect(report.text).toBe(1);
  });

  it('shape 7: options as bare string array, answer as full text (AMS101/MTH101/english)', () => {
    const { bundle, key } = normalizeBank(
      JSON.stringify([
        {
          id: 1,
          topic: 'Kinematics',
          question: 'In a perfectly inelastic collision',
          options: ['heat is gained', 'energy is lost', 'energy is gained', 'power is lost'],
          answer: 'energy is lost',
        },
        { id: 2, question: 'Letter answer still works', options: ['one', 'two', 'three', 'four'], answer: 'C' },
      ]),
      'MTH101.json',
    );
    expect(bundle.questions[0].options).toEqual({ A: 'heat is gained', B: 'energy is lost', C: 'energy is gained', D: 'power is lost' });
    expect(key.answers['1']).toMatchObject({ type: 'mcq', letter: 'B' });
    expect(key.answers['2']).toMatchObject({ letter: 'C' });
  });

  it('drops duplicates, empty stems, unanswerable; reassigns clashing ids', () => {
    const { bundle, report } = normalizeBank(
      JSON.stringify([
        { id: 1, question: 'Same stem twice?', option: { a: '1', b: '2' }, answer: 'a' },
        { id: 1, question: 'Same stem twice?', option: { a: '1', b: '2' }, answer: 'a' }, // dup stem
        { id: 2, question: '   ', option: { a: '1', b: '2' }, answer: 'a' }, // empty stem
        { id: 3, question: 'No answer material', option: { a: '1', b: '2' } }, // unanswerable
        { id: 1, question: 'Different stem, clashing id', option: { a: '1', b: '2' }, answer: 'b' }, // id reassigned
      ]),
      'messy.json',
    );
    expect(bundle.questionCount).toBe(2);
    expect(report.dropped.map((d) => d.reason)).toEqual(['duplicate stem', 'empty stem', 'no answer material found']);
    expect(bundle.questions[1].id).not.toBe('1');
  });

  it('answer text that matches an option resolves to its letter', () => {
    const { key } = normalizeBank(
      JSON.stringify([{ question: 'Pick', option: { a: 'Alpha', b: 'Beta' }, answer: 'Beta' }]),
      'textans.json',
    );
    expect(key.answers[bundle0(key)].type === 'mcq').toBe(true);
    function bundle0(k: typeof key): string {
      return Object.keys(k.answers)[0];
    }
  });
});
