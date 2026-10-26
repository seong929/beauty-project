# Cosmetics Management System

화장품 온라인 판매 및 유통 관리 시스템

## 기술 스택
- Frontend: Flutter (Riverpod, MVVM)
- Backend: FastAPI
- Database: MySQL
- Platform: Android

## 프로젝트 구조
- backend: FastAPI 서버
- frontend: Flutter 애플리케이션
- database: MySQL SQL 파일

## 팀원 역할
- A: 고객 (스마트폰)
- B: 본사 직원 (태블릿)
- C: 본사 관리자 및 배송업체 담당자 (태블릿)

## 데이터베이스
- Database Name: cosmetics_management
- MySQL 8.0.16 이상

## 고객·주문 API

첨부 고객·주문 코드를 현재 스키마에 맞춰 `backend/routers/customer`에 이식했다.
기존 API 경로와 폼 이름을 유지하며, `backend/main.py`에 라우터를 연결했다.

실행 방법, API 입력, 스키마 변경 대응 및 검증 결과는
[고객·주문 이식 검수](docs/customer_migration.md)를 참고한다.
