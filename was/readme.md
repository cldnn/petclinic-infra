# Spring PetClinic Sample Application

[![Build Status](https://travis-ci.org/spring-petclinic/spring-framework-petclinic.svg?branch=master)](https://travis-ci.org/spring-petclinic/spring-framework-petclinic/) 
[![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=spring-petclinic_spring-framework-petclinic&metric=alert_status)](https://sonarcloud.io/dashboard?id=spring-petclinic_spring-framework-petclinic)
[![Coverage](https://sonarcloud.io/api/project_badges/measure?project=spring-petclinic_spring-framework-petclinic&metric=coverage)](https://sonarcloud.io/dashboard?id=spring-petclinic_spring-framework-petclinic)

GCP Cloud 과제 수행을 위한 Java Spring 으로 개발된 Sample Application 입니다. 

**3-layer architecture** (i.e. presentation --> service --> repository) 로 Tomcat 에 배포하여 2 Tier 로 구성하거나
또는 nginx 등의 Web 서버를 통해서 Tomcat 을 연결하는 3 Tier 구성을 테스트할 수 있습니다. 

## Understanding the Spring Petclinic application with a few diagrams

[See the presentation here](http://fr.slideshare.net/AntoineRey/spring-framework-petclinic-sample-application) (2017 update)

## Running petclinic locally

### Tomcat 설치 및 Start
Tomcat 설치 가이드를 참조하여 Tomcat 설치 후, tomcat-users.xml 에 User 및 Role 추가

[ Ubuntu 18.04 : Tomcat 9 설치하는 방법 ](https://jjeongil.tistory.com/1351)

Tomcat User 및 Role 추가

```
# $TOMCAT_HOME/conf/tomcat-users.xml 파일에 아래 행들을 추가

    <role rolename="manager-script"/>
    <role rolename="manager-gui"/>
    <role rolename="manager-jmx"/>
    <role rolename="manager-status"/>
    <user username="tomcat" password="tomcat" roles="manager-gui,manager-script,manager-status,manager-jmx"/>
```

Tomcat 을 실행 ( 위의 Tomcat 설치 가이드를 통해서 이미 실행되어 있는 경우에는 Skip )

```
$TOMCAT_HOME/bin/catalina.sh start
```

### Tomcat 배포 ( H2 In-memory Database 활용 )
```
git clone https://github.com/SteveKimbespin/petclinic_btc.git 
cd petclinic_btc
./mvnw tomcat7:deploy
```

You can then access petclinic here: [http://localhost:8080/petclinic](http://localhost:8080/petclinic)

<img width="1042" alt="petclinic-screenshot" src="https://cloud.githubusercontent.com/assets/838318/19727082/2aee6d6c-9b8e-11e6-81fe-e889a5ddfded.png">

### 외부에 구성한 MySQL Database 연결 방법

MySQL 을 각 CSP 의 DB Service 로 구성
  - database 명 : petclinic  
  - db user 및 password 설정

MySQL database 접속 설정을 하기 위해, pom.xml 파일에 정의 된 'MySQL' profile 을 아래와 같이 수정후, 재배포(redeploy)한다.
  - jdbc.url 부분에 정의되어 있는 DNS 또는 IP Address 를 연결하고자 하는 MySQL IP 로 변경한다. ( 필요시 database 도 수정)
  - db 접속 User ID 및 Password 수정

```
<properties>
    <jpa.database>MYSQL</jpa.database>
    <jdbc.driverClassName>com.mysql.cj.jdbc.Driver</jdbc.driverClassName>
    <jdbc.url>jdbc:mysql://localhost:3306/petclinic?useUnicode=true</jdbc.url>
    <jdbc.username>petclinic</jdbc.username>
    <jdbc.password>petclinic</jdbc.password>
</properties>
```

Tomcat 에 재배포

```
# 기존에 배포되어 있는 환경에 MySQL 연결 설정 수정후, 재배포 하는 경우
./mvnw tomcat7:redeploy -P MySQL

# 최초 배포하는 경우
./mvnw tomcat7:deploy -P MySQL
```


You can then access petclinic here: [http://localhost:8080/petclinic](http://localhost:8080/petclinic)

## 라이선스와 변경 사항

이 소스는 [SteveKimbespin/petclinic_btc](https://github.com/SteveKimbespin/petclinic_btc)에서 받아 Cloud 9 팀이 변경한 것이다. petclinic_btc는 [Spring Framework PetClinic](https://github.com/spring-petclinic/spring-framework-petclinic)을 바탕으로 한 실습용 저장소다. 원본처럼 Apache License 2.0을 따르며, 전문은 [`LICENSE.txt`](LICENSE.txt)에 있다. 고친 파일에는 머리 주석에 `Modified by Cloud 9 (2026)`을 기록하였다.

### 수정한 파일

| 파일 | 수정 내용 |
| --- | --- |
| `pom.xml` | Spring Framework 5.3.39, Tomcat 9.0.122로 올림. Spring BOM 추가. MySQL 드라이버를 `com.mysql:mysql-connector-j` 8.4.0으로 교체. Secrets Manager JDBC 드라이버(`aws-secretsmanager-jdbc` 2.1.3)를 JDBC 드라이버로 지정. `whoami.jsp`용 AWS SDK `elasticloadbalancingv2` 2.41.3 추가. MySQL 프로필의 접속 주소, 계정, 암호 기본값 제거. H2, HSQLDB, PostgreSQL 프로필 제거. `datasource-config.xml`을 리소스 필터링에서 제외 |
| `web/OwnerController.java`, `web/VisitController.java` | 폼 바인딩을 차단 목록에서 허용 목록 방식으로 변경.(CVE-2024-38820) |
| `web/PetController.java` | 허용 목록 바인딩, URL의 `petId` 사용, 보호자와 반려동물 관계 검증. |
| `jsp/pets/createOrUpdatePetForm.jsp` | 숨은 `id` 필드 제거. |
| `spring/data-access.properties`, `spring/datasource-config.xml` | 접속 주소와 계정을 JVM 시스템 속성으로 받음. 연결 검증 추가. 시작 시 DB 초기화 SQL 비활성화. |
| `web/PetControllerTests.java` | 보호자와 반려동물 관계 검증에 맞추어 테스트 수정. |

### 추가한 파일

| 파일 | 내용 |
| --- | --- |
| `WEB-INF/web.xml` | 400 오류를 `exception.jsp`로 연결. |
| `whoami.jsp` | 응답한 WAS와 대상 그룹 상태 표시. |
| `global-bundle.pem` | Amazon RDS 인증서 번들. AWS가 공개 배포하는 CA 인증서다.([출처](https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem)) |

### 삭제한 파일

- `src/main/resources/db/h2`, `db/hsqldb`, `db/postgresql`: MySQL만 사용하므로 삭제하였다.
