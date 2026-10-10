USE petclinic;

SET SESSION cte_max_recursion_depth = 60000;

-- ============================================================
-- 테스트 데이터가 이미 존재하는지 확인
-- ============================================================

SELECT COUNT(*) AS existing_test_owners
FROM owners
WHERE first_name LIKE 'LT_OWNER_%';

SELECT COUNT(*) AS existing_test_pets
FROM pets
WHERE name LIKE 'LT_PET_%';

SELECT COUNT(*) AS existing_test_visits
FROM visits
WHERE description LIKE 'LT_VISIT_%';

-- ============================================================
-- Transaction 시작
-- ============================================================

START TRANSACTION;

-- ============================================================
-- 1. owners 20,000건
-- ============================================================

INSERT INTO owners (
    first_name,
    last_name,
    address,
    city,
    telephone
)
WITH RECURSIVE seq AS (
    SELECT 1 AS n
    UNION ALL
    SELECT n + 1
    FROM seq
    WHERE n < 20000
)
SELECT
    CONCAT('LT_OWNER_', LPAD(n, 5, '0')),
    CONCAT('LoadTest', LPAD(n, 5, '0')),
    CONCAT(n, ' Load Test Street'),
    CASE MOD(n, 5)
        WHEN 0 THEN 'Seoul'
        WHEN 1 THEN 'Busan'
        WHEN 2 THEN 'Incheon'
        WHEN 3 THEN 'Daejeon'
        ELSE 'Daegu'
    END,
    CONCAT('019', LPAD(n, 8, '0'))
FROM seq;

-- ============================================================
-- 2. owners 생성 결과
-- ============================================================

SELECT COUNT(*) AS generated_owners
FROM owners
WHERE first_name LIKE 'LT_OWNER_%';

-- ============================================================
-- 3. pets 30,000건 (실제 생성된 owner ID를 ROW_NUMBER로 매핑)
-- ============================================================

INSERT INTO pets (
    name,
    birth_date,
    type_id,
    owner_id
)
WITH RECURSIVE seq AS (
    SELECT 1 AS n
    UNION ALL
    SELECT n + 1
    FROM seq
    WHERE n < 30000
),
test_owners AS (
    SELECT
        id,
        ROW_NUMBER() OVER (ORDER BY id) AS rn
    FROM owners
    WHERE first_name LIKE 'LT_OWNER_%'
)
SELECT
    CONCAT('LT_PET_', LPAD(seq.n, 5, '0')),
    DATE_ADD('2015-01-01', INTERVAL MOD(seq.n, 3650) DAY),
    MOD(seq.n - 1, 6) + 1,
    o.id
FROM seq
JOIN test_owners o
    ON o.rn = MOD(seq.n - 1, 20000) + 1;

-- ============================================================
-- 4. pets 생성 결과
-- ============================================================

SELECT COUNT(*) AS generated_pets
FROM pets
WHERE name LIKE 'LT_PET_%';

-- ============================================================
-- 5. visits 50,000건 (실제 생성된 pet ID를 ROW_NUMBER로 매핑)
-- ============================================================

INSERT INTO visits (
    pet_id,
    visit_date,
    description
)
WITH RECURSIVE seq AS (
    SELECT 1 AS n
    UNION ALL
    SELECT n + 1
    FROM seq
    WHERE n < 50000
),
test_pets AS (
    SELECT
        id,
        ROW_NUMBER() OVER (ORDER BY id) AS rn
    FROM pets
    WHERE name LIKE 'LT_PET_%'
)
SELECT
    p.id,
    DATE_ADD('2024-01-01', INTERVAL MOD(seq.n, 1000) DAY),
    CONCAT(
        'LT_VISIT_',
        LPAD(seq.n, 5, '0'),
        '_',
        CASE MOD(seq.n, 5)
            WHEN 0 THEN 'CHECKUP'
            WHEN 1 THEN 'VACCINATION'
            WHEN 2 THEN 'DENTAL'
            WHEN 3 THEN 'EXAM'
            ELSE 'FOLLOWUP'
        END
    )
FROM seq
JOIN test_pets p
    ON p.rn = MOD(seq.n - 1, 30000) + 1;

-- ============================================================
-- 6. visits 생성 결과
-- ============================================================

SELECT COUNT(*) AS generated_visits
FROM visits
WHERE description LIKE 'LT_VISIT_%';

-- ============================================================
-- 7. FK 검증 (모두 0이어야 정상)
-- ============================================================

SELECT COUNT(*) AS pets_without_owner
FROM pets p
LEFT JOIN owners o
    ON p.owner_id = o.id
WHERE p.name LIKE 'LT_PET_%'
  AND o.id IS NULL;

SELECT COUNT(*) AS pets_without_type
FROM pets p
LEFT JOIN types t
    ON p.type_id = t.id
WHERE p.name LIKE 'LT_PET_%'
  AND t.id IS NULL;

SELECT COUNT(*) AS visits_without_pet
FROM visits v
LEFT JOIN pets p
    ON v.pet_id = p.id
WHERE v.description LIKE 'LT_VISIT_%'
  AND p.id IS NULL;

-- ============================================================
-- 8. Commit
-- ============================================================

COMMIT;

-- ============================================================
-- 9. 최종 결과
-- ============================================================

SELECT COUNT(*) AS final_test_owners
FROM owners
WHERE first_name LIKE 'LT_OWNER_%';

SELECT COUNT(*) AS final_test_pets
FROM pets
WHERE name LIKE 'LT_PET_%';

SELECT COUNT(*) AS final_test_visits
FROM visits
WHERE description LIKE 'LT_VISIT_%';
