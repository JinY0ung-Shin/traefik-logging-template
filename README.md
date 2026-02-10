# Traefik + Loki + Grafana Template

Docker Compose 기반 Traefik 리버스 프록시 + 로그 기반 엔드포인트 요청 카운팅 스택

## 빠른 시작

```bash
git clone <repository-url> && cd traefik-prometheus-template
docker compose up -d
```

## 접속 정보

| 서비스 | URL | 비고 |
|--------|-----|------|
| Traefik Dashboard | http://traefik.localhost:8080 | |
| Grafana | http://grafana.localhost:3000 | admin/admin |
| Sample App | http://app.localhost | |

## 스택 구성

```
Client → Traefik (리버스 프록시)
              ↓ access log (stdout)
         Promtail (로그 수집)
              ↓
           Loki (로그 저장, 30일 보관)
              ↓
         Grafana (카운팅 대시보드)
```

- **Traefik**: 서비스 라우팅 + JSON access log 출력
- **Promtail**: Traefik 컨테이너 로그 수집, 서비스/라우터/메소드/상태코드 라벨 추출
- **Loki**: 로그 저장 (30일 보관), LogQL로 정확한 카운팅
- **Grafana**: 일별/주별/월별 엔드포인트 요청 수 대시보드

## 엔드포인트 카운팅

Grafana의 **Endpoint Request Counting** 대시보드에서 확인할 수 있습니다:

- 서비스별 / 라우터(엔드포인트)별 요청 수
- 일별 / 주별 / 월별 집계 전환
- HTTP 상태 코드, 메소드별 분포
- 상세 테이블 (정확한 수치)
- 최근 access log 실시간 조회

> 로그 기반이므로 조회 시점에 관계없이 **항상 동일한 값**을 보장합니다.

## 서비스 추가

```yaml
my-service:
  image: my-service:latest
  networks:
    - traefik-net
  labels:
    - "traefik.enable=true"
    - "traefik.http.routers.my-service.rule=Host(`my-service.localhost`)"
    - "traefik.http.routers.my-service.entrypoints=web"
    - "traefik.http.services.my-service.loadbalancer.server.port=8080"
    # 미들웨어 적용 (선택)
    - "traefik.http.routers.my-service.middlewares=rate-limit@file,secure-headers@file"
```

## 기존 Docker Compose 프로젝트 통합

### 1. 네트워크 추가

기존 `docker-compose.yml`에 외부 네트워크를 추가합니다:

```yaml
networks:
  traefik-net:
    external: true
```

### 2. 기존 서비스에 Traefik 설정 추가

```yaml
services:
  my-api:
    image: my-api:latest
    networks:
      - traefik-net
      - default
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.my-api.rule=Host(`api.mydomain.com`)"
      - "traefik.http.routers.my-api.entrypoints=web"
      - "traefik.http.services.my-api.loadbalancer.server.port=3000"
```

### 3. 실행

```bash
# 이 템플릿 먼저 실행 (네트워크 생성)
docker compose up -d

# 기존 프로젝트에서 실행
cd /path/to/my-project
docker compose up -d
```

## 미들웨어

| 이름 | 설명 |
|------|------|
| `rate-limit@file` | 100 req/s, burst 50 |
| `secure-headers@file` | XSS, HSTS 등 보안 헤더 |
| `compress@file` | gzip 압축 |
| `retry@file` | 3회 재시도 |
| `circuit-breaker@file` | 에러율 30% 초과 시 차단 |

## 스케일링

```bash
docker compose up -d --scale sample-app=3
```

> `container_name` 제거 필요

## 주요 명령어

```bash
docker compose up -d          # 시작
docker compose logs -f        # 로그
docker compose down           # 중지
docker compose down -v        # 데이터 포함 삭제
```

---

상세 설정은 [CLAUDE.md](./CLAUDE.md) 참고

## License

MIT
