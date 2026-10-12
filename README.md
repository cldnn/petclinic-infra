# 펫 클리닉 3계층 아키텍처 인프라 구축 프로젝트

- PetClinic 샘플을 사용하여 AWS 서울 리전에 3계층(CloudFront → 웹 → WAS → RDS)으로 구축한 프로젝트의 설정 파일과 문서를 모은 저장소입니다.
- 기간: 2026. 9. 21. ~ 2026. 10. 14. (13일 작업)

- **구축 절차서**: [Wiki](https://github.com/cldnn/petclinic-infra/wiki)

## 폴더

| 폴더 | 내용 |
| --- | --- |
| `iam/identity/` | IAM 고객 관리형 정책 (권한 정책) |
| `iam/trust/` | IAM 역할 신뢰 정책 |
| `web/` | Apache 리버스 프록시 설정(`proxy.conf`), 안내 페이지(`index.html`), CloudFront 오류 페이지 |
| `was/` | PetClinic 애플리케이션 소스 (Java 8, Tomcat 9, MySQL) |
| `db/test-data/` | 부하 시험용 테스트 데이터 SQL과 실행 스크립트 |

## 구성 요약

| 항목 | 값 |
| --- | --- |
| 리전, 가용 영역 | `ap-northeast-2`, 2a와 2c |
| VPC | `10.9.0.0/22`, NAT 게이트웨이 없음 (S3 게이트웨이 엔드포인트, 인터페이스 엔드포인트 사용) |
| 웹 | Amazon Linux 2023 arm64, `t4g.micro`, Apache 2.4, Auto Scaling |
| WAS | Amazon Linux 2023 arm64, `t4g.small`, Corretto 8, Tomcat 9, Auto Scaling |
| DB | RDS for MySQL 8.4 Multi-AZ `db.t4g.small`, RDS Proxy (TLS 필수) |
| 서버 접속 | Systems Manager Session Manager |

## 올리지 않은 것

빌드 결과물 (WAR), 설치 패키지 (`*.tar.gz`), 키 페어, 액세스 키, 암호, CloudFront 사용자 지정 헤더 값은 저장소에 올리지 않았습니다.
