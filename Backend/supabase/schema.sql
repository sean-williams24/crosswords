-- ============================================================
-- Crosswords App — Supabase Database Schema
-- ============================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- Puzzles table
-- ============================================================

CREATE TABLE puzzles (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    puzzle_number INT NOT NULL UNIQUE,
    date          DATE NOT NULL UNIQUE,
    grid_data     JSONB NOT NULL,
    clues         JSONB NOT NULL,
    is_free       BOOLEAN NOT NULL DEFAULT TRUE,
    published_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for fast date lookups
CREATE INDEX idx_puzzles_date ON puzzles (date);

-- ============================================================
-- Row Level Security
-- ============================================================

ALTER TABLE puzzles ENABLE ROW LEVEL SECURITY;

-- Allow anonymous (anon) users to read puzzles whose date is today or earlier.
-- This prevents leaking future puzzles.
CREATE POLICY "Public can read released puzzles"
    ON puzzles
    FOR SELECT
    USING (date <= CURRENT_DATE);

-- Only authenticated service-role users can insert/update/delete.
-- (The anon key used in the app cannot mutate data.)

-- ============================================================
-- Words of the Day table
-- ============================================================

CREATE TABLE words_of_the_day (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    date          DATE NOT NULL UNIQUE,
    word_data     JSONB NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for fast date lookups
CREATE INDEX idx_wotd_date ON words_of_the_day (date);

ALTER TABLE words_of_the_day ENABLE ROW LEVEL SECURITY;

-- Allow anonymous users to read words whose date is today or earlier.
CREATE POLICY "Public can read released words"
    ON words_of_the_day
    FOR SELECT
    USING (date <= CURRENT_DATE);

-- ============================================================
-- Example: Insert a puzzle
-- ============================================================
-- INSERT INTO puzzles (puzzle_number, date, grid_data, clues)
-- VALUES (
--   1,
--   '2026-03-07',
--   '{
--     "size": 9,
--     "cells": [
--       [{"letter":"S","clueNumber":1,"acrossClueId":0,"downClueId":1}, ...]
--     ]
--   }',
--   '[
--     {"id":0,"direction":"across","number":1,"text":"Celestial body","hint":"Hollywood celebrity","answer":"STAR","startRow":0,"startCol":0,"length":4},
--     ...
--   ]'
-- );
