-- Reschedule the queued Anagram launch before its first public release.
-- No Anagram rows had been released when this correction was approved. The
-- immutable trigger is restored in the same transaction by the migration runner.
DO $$
BEGIN
    IF (SELECT COUNT(*) FROM anagram_puzzles) <> 30 OR
       (SELECT MIN(puzzle_number) FROM anagram_puzzles) <> 1 OR
       (SELECT MAX(puzzle_number) FROM anagram_puzzles) <> 30 OR
       (SELECT MIN(date) FROM anagram_puzzles) <> DATE '2026-10-01' OR
       (SELECT MAX(date) FROM anagram_puzzles) <> DATE '2026-10-30' THEN
        RAISE EXCEPTION 'Unexpected Anagram queue; refusing to reschedule launch';
    END IF;
END;
$$;

DROP TRIGGER anagram_immutable ON anagram_puzzles;

-- Move the old dates out of the target range before assigning the replacement
-- dates because the date uniqueness constraint is intentionally immediate.
UPDATE anagram_puzzles
SET date = date + INTERVAL '100 years';

UPDATE anagram_puzzles AS puzzle
SET id = schedule.id,
    date = schedule.date
FROM (
    VALUES
        (1, '0edef1a5-5678-556d-b0fb-4831ddfd9204'::UUID, '2026-09-26'::DATE),
        (2, 'b8024071-ac2c-5489-8bb6-d42862fdd033'::UUID, '2026-09-27'::DATE),
        (3, '82918409-87b4-597b-96fc-3f0247c52f38'::UUID, '2026-09-28'::DATE),
        (4, '80ff9035-2d73-5687-b460-227dfebfd7af'::UUID, '2026-09-29'::DATE),
        (5, '9e1f4803-10a8-5a57-9b83-d4a38eaa4657'::UUID, '2026-09-30'::DATE),
        (6, 'f0c7c0ea-4e1d-5ba8-b6e8-a49f0b3be1fb'::UUID, '2026-10-01'::DATE),
        (7, 'ea8e93ef-81e8-55fe-9650-8dcb6786a29d'::UUID, '2026-10-02'::DATE),
        (8, '421db4d1-365a-5b3e-b7d3-1e1fef924139'::UUID, '2026-10-03'::DATE),
        (9, '96f9cb6b-54cb-59e7-85e4-39bcefc21df3'::UUID, '2026-10-04'::DATE),
        (10, '47ac5cc5-50c8-5a3f-b7d0-843bffc8924d'::UUID, '2026-10-05'::DATE),
        (11, '76484e4b-1671-546f-b8e7-60bc287cc948'::UUID, '2026-10-06'::DATE),
        (12, '9427986d-7f93-5c97-893a-e6957b2cb3eb'::UUID, '2026-10-07'::DATE),
        (13, 'fc60159e-77fe-5d09-93ee-3ceb8795df2c'::UUID, '2026-10-08'::DATE),
        (14, 'fdc3a819-c8b8-54a2-b95f-767b1fca66f5'::UUID, '2026-10-09'::DATE),
        (15, '41c8161f-c5dc-53a0-a037-aa6ae7bf1377'::UUID, '2026-10-10'::DATE),
        (16, 'f1209e55-7fd5-5d95-823f-889e6ed071f1'::UUID, '2026-10-11'::DATE),
        (17, '93c3903a-c995-50e2-a197-81767af4ff4a'::UUID, '2026-10-12'::DATE),
        (18, 'e12ffb7a-50ca-50d4-b58d-c02d39b01ce2'::UUID, '2026-10-13'::DATE),
        (19, '2e46e2d3-012c-51b9-a852-a9d0d7dfebab'::UUID, '2026-10-14'::DATE),
        (20, 'e675926d-ec8e-5a0a-b001-fa2d614c62d9'::UUID, '2026-10-15'::DATE),
        (21, '54e2aee1-ca2b-5d16-9451-413578fb8036'::UUID, '2026-10-16'::DATE),
        (22, 'be2b4aae-68b2-5c20-955d-a5679df4611f'::UUID, '2026-10-17'::DATE),
        (23, '882ad85f-baae-5096-aced-8594be8597de'::UUID, '2026-10-18'::DATE),
        (24, '1f3272f8-d135-5ec5-97ff-2b6118951e1b'::UUID, '2026-10-19'::DATE),
        (25, '536803db-e14d-5ccf-9b73-c2e5fa7dea38'::UUID, '2026-10-20'::DATE),
        (26, '56230784-bf2e-5499-99f0-cadb3af0379f'::UUID, '2026-10-21'::DATE),
        (27, '6e79703e-d950-5b4d-8531-c1461a6d6012'::UUID, '2026-10-22'::DATE),
        (28, 'ab1e10bd-7a28-5d1f-a235-a2433dc502f2'::UUID, '2026-10-23'::DATE),
        (29, '2eb8adcc-67bb-5272-8be1-672a0cf0a4a1'::UUID, '2026-10-24'::DATE),
        (30, 'e77379db-06bd-54a1-8d92-176fa8306061'::UUID, '2026-10-25'::DATE)
) AS schedule(puzzle_number, id, date)
WHERE puzzle.puzzle_number = schedule.puzzle_number;

CREATE TRIGGER anagram_immutable
    BEFORE UPDATE OR DELETE ON anagram_puzzles
    FOR EACH ROW EXECUTE FUNCTION reject_anagram_mutation();

DO $$
BEGIN
    IF (SELECT MIN(date) FROM anagram_puzzles) <> DATE '2026-09-26' OR
       (SELECT MAX(date) FROM anagram_puzzles) <> DATE '2026-10-25' THEN
        RAISE EXCEPTION 'Anagram launch reschedule verification failed';
    END IF;
END;
$$;
