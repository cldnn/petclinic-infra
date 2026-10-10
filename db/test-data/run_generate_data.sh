#!/bin/bash
# PetClinic 부하 시험용 테스트 데이터 10만 건 생성
# 사용법: DB_HOST=<PROXY_ENDPOINT> ./run_generate_data.sh
# mysql 명령을 세 번 실행하므로 암호를 세 번 묻는다.

set -o pipefail

DB_HOST="${DB_HOST:?DB_HOST에 RDS Proxy 엔드포인트를 지정한다}"
DB_PORT="3306"
DB_USER="cloud9-pet"
DB_NAME="petclinic"

SQL_FILE="./generate_test_data.sql"
LOG_FILE="./generate_test_data.log"

echo "=========================================="
echo "PetClinic 테스트 데이터 생성"
echo "=========================================="
echo "시작 시간 : $(date)"
echo "DB        : $DB_NAME"
echo "SQL       : $SQL_FILE"
echo "로그      : $LOG_FILE"
echo

if [ ! -f "$SQL_FILE" ]; then
    echo "[FAIL] SQL 파일이 없다: $SQL_FILE"
    exit 1
fi

# ------------------------------------------------------------
# 1. 기존 테스트 데이터 확인 (중복 생성 방지)
# ------------------------------------------------------------
echo "[1/3] 기존 테스트 데이터 확인"

EXISTING=$(mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p --ssl -N "$DB_NAME" -e "
    SELECT
        (SELECT COUNT(*) FROM owners WHERE first_name LIKE 'LT_OWNER_%')
      + (SELECT COUNT(*) FROM pets   WHERE name LIKE 'LT_PET_%')
      + (SELECT COUNT(*) FROM visits WHERE description LIKE 'LT_VISIT_%');
    ")

if [ $? -ne 0 ]; then
    echo "[FAIL] DB 연결 또는 기존 데이터 확인 실패"
    exit 1
fi

if [ "$EXISTING" -ne 0 ]; then
    echo "[FAIL] 테스트 데이터가 이미 있다 (현재 $EXISTING 건). 실행을 중단한다."
    exit 1
fi

echo "[OK] 기존 테스트 데이터 없음"
echo

# ------------------------------------------------------------
# 2. SQL 실행
# ------------------------------------------------------------
echo "[2/3] 테스트 데이터 생성 시작"

mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p --ssl --show-warnings "$DB_NAME" \
    < "$SQL_FILE" 2>&1 | tee "$LOG_FILE"

MYSQL_EXIT=${PIPESTATUS[0]}
if [ "$MYSQL_EXIT" -ne 0 ]; then
    echo "[FAIL] 데이터 생성 중 오류 (종료 코드 $MYSQL_EXIT). 확인: tail -n 50 $LOG_FILE"
    exit 1
fi

# ------------------------------------------------------------
# 3. 최종 건수 확인
# ------------------------------------------------------------
echo
echo "[3/3] 최종 데이터 건수 확인"

RESULT=$(mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p --ssl -N "$DB_NAME" -e "
    SELECT
        (SELECT COUNT(*) FROM owners WHERE first_name LIKE 'LT_OWNER_%'),
        (SELECT COUNT(*) FROM pets   WHERE name LIKE 'LT_PET_%'),
        (SELECT COUNT(*) FROM visits WHERE description LIKE 'LT_VISIT_%');
    ")

if [ $? -ne 0 ]; then
    echo "[FAIL] 최종 데이터 검증 실패"
    exit 1
fi

read OWNER_COUNT PET_COUNT VISIT_COUNT <<< "$RESULT"

echo "owners : $OWNER_COUNT / 20000"
echo "pets   : $PET_COUNT / 30000"
echo "visits : $VISIT_COUNT / 50000"
echo

if [ "$OWNER_COUNT" -eq 20000 ] && [ "$PET_COUNT" -eq 30000 ] && [ "$VISIT_COUNT" -eq 50000 ]; then
    echo "[SUCCESS] 테스트 데이터 생성 완료 (총 100,000건, $(date))"
    exit 0
else
    echo "[FAIL] 생성 건수가 예상값과 다르다."
    exit 1
fi
