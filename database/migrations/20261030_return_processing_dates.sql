-- 기존 DB에 한 번 적용한다. 과거 처리일을 추정하거나 다른 날짜로 채우지 않는다.
-- 신규 DB는 database/skin_project.sql에 동일 컬럼이 포함되어 있다.
ALTER TABLE return_requests
    ADD COLUMN approved_on DATE NULL
        COMMENT '반품 승인 처리일 (과거 미기록 데이터는 NULL)',
    ADD COLUMN inspection_completed_on DATE NULL
        COMMENT '반품 검수 완료 처리일 (과거 미기록 데이터는 NULL)';
