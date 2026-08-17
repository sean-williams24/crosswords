import { useEffect, useState } from "react";
import { localDateString } from "../../backword/date";
import {
  createWordOfTheDayRepository,
  type WordOfTheDayRepository
} from "../repository";
import type { WordOfTheDay } from "../types";

type WordOfTheDayCardProps = {
  date?: string;
  repository?: WordOfTheDayRepository;
};

const largeViewportQuery = "(min-width: 901px)";

function useLargeViewport() {
  const [isLargeViewport, setIsLargeViewport] = useState(
    () => window.matchMedia?.(largeViewportQuery).matches ?? false
  );

  useEffect(() => {
    const mediaQuery = window.matchMedia?.(largeViewportQuery);
    if (!mediaQuery) {
      return;
    }
    const updateViewport = () => setIsLargeViewport(mediaQuery.matches);
    updateViewport();
    mediaQuery.addEventListener("change", updateViewport);
    return () => mediaQuery.removeEventListener("change", updateViewport);
  }, []);

  return isLargeViewport;
}

function partOfSpeechExplainer(partOfSpeech: string): string | null {
  switch (partOfSpeech.toLowerCase()) {
    case "noun":
      return "Noun: a word that names a person, place, thing, or idea.";
    case "verb":
      return "Verb: a word that describes an action, state, or occurrence.";
    case "adjective":
      return "Adjective: a describing word that modifies a noun.";
    case "adverb":
      return "Adverb: a word that modifies a verb, adjective, or other adverb — often ending in -ly.";
    case "pronoun":
      return "Pronoun: a word used in place of a noun, such as he, she, or it.";
    case "preposition":
      return "Preposition: a word that shows the relationship between a noun and other words, such as in, on, or at.";
    case "conjunction":
      return "Conjunction: a word that connects words, phrases, or clauses — such as and, but, or or.";
    case "interjection":
      return "Interjection: a word or phrase that expresses strong emotion, such as oh! or wow!.";
    default:
      return null;
  }
}

function WordDetails({ word }: { word: WordOfTheDay }) {
  const explainer = partOfSpeechExplainer(word.partOfSpeech);

  return (
    <div className="wotd-detail">
      <div className="wotd-detail__primary">
        <div className="wotd-detail__desktop-heading">
          <p className="wotd-card__label">WORD OF THE DAY</p>
          <h2>{word.word}</h2>
        </div>
        <p className="wotd-detail__meta">
          <span>{word.pronunciation}</span>
          <b aria-hidden="true">•</b>
          <em>{word.partOfSpeech}</em>
        </p>
        <section className="wotd-detail__definition" aria-labelledby="wotd-definition-title">
          <h3 id="wotd-definition-title">DEFINITION</h3>
          <p>{word.definition}</p>
        </section>
      </div>

      <div className="wotd-detail__secondary">
        <section aria-labelledby="wotd-example-title">
          <h3 id="wotd-example-title">EXAMPLE</h3>
          <p className="wotd-detail__example">“{word.exampleSentence}”</p>
        </section>
        <section aria-labelledby="wotd-synonyms-title">
          <h3 id="wotd-synonyms-title">SYNONYMS</h3>
          <ul className="wotd-detail__synonyms">
            {word.synonyms.map((synonym) => <li key={synonym}>{synonym}</li>)}
          </ul>
        </section>
        <section aria-labelledby="wotd-etymology-title">
          <h3 id="wotd-etymology-title">ETYMOLOGY</h3>
          <p>{word.etymology}</p>
        </section>
        {explainer ? <p className="wotd-detail__explainer"><span aria-hidden="true">ⓘ</span>{explainer}</p> : null}
      </div>
    </div>
  );
}

export function WordOfTheDayCard({ date = localDateString(), repository }: WordOfTheDayCardProps) {
  const [word, setWord] = useState<WordOfTheDay | null>(null);
  const [isExpanded, setIsExpanded] = useState(false);
  const isLargeViewport = useLargeViewport();

  useEffect(() => {
    let isCurrent = true;
    setWord(null);
    setIsExpanded(false);
    let source: WordOfTheDayRepository;
    try {
      source = repository ?? createWordOfTheDayRepository();
    } catch {
      setWord(null);
      return () => {
        isCurrent = false;
      };
    }

    void source.getByDate(date)
      .then((loadedWord) => {
        if (isCurrent) {
          setWord(loadedWord);
        }
      })
      .catch(() => {
        if (isCurrent) {
          setWord(null);
        }
      });

    return () => {
      isCurrent = false;
    };
  }, [date, repository]);

  if (!word) {
    return null;
  }

  const drawerId = `wotd-details-${word.id}`;
  const detailsVisible = isExpanded || isLargeViewport;
  return (
    <section className={`wotd-widget${detailsVisible ? " wotd-widget--expanded" : ""}`} aria-label="Word of the Day">
      <button
        aria-controls={drawerId}
        aria-expanded={detailsVisible}
        className="wotd-card"
        onClick={() => setIsExpanded((expanded) => !expanded)}
        type="button"
      >
        <span className="wotd-card__label">WORD OF THE DAY</span>
        <strong>{word.word}</strong>
      </button>
      <div aria-hidden={!detailsVisible} className="wotd-drawer" id={drawerId}>
        <div className="wotd-drawer__inner"><WordDetails word={word} /></div>
      </div>
    </section>
  );
}
