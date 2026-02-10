# CLAUDE.md

이 파일은 AI 에이전트(Claude 등)가 프로젝트를 이해하는 데 필요한 컨텍스트를 제공합니다.

## 프로젝트 개요

**Traefik + Loki + Grafana Template**

Docker Compose 기반의 Traefik 리버스 프록시 + 로그 기반 요청 카운팅 스택입니다. Traefik으로 서비스 트래픽을 라우팅하고, access log를 Loki에 저장하여 엔드포인트별 요청 수를 정확하게 일별/주별/월별로 카운팅합니다.

### 기술 스택
- **Traefik v3.0**: 리버스 프록시 및 로드 밸런서
- **Loki 2.9.0**: 로그 집계 및 저장 (30일 보관)
- **Promtail 2.9.0**: 컨테이너 로그 수집 에이전트
- **Grafana v10.3.0**: 로그 시각화 및 카운팅 대시보드
- **Docker Compose**: 컨테이너 오케스트레이션

## 아키텍처

```
                    ┌──────────────────────────────────────────────────┐
                    │                   Docker Network                  │
                    │                   (traefik-net)                   │
┌─────────┐         │  ┌─────────────┐      ┌─────────────────────────┐ │
│ Client  │─────────┼──│   Traefik   │──────│  Backend Services       │ │
│         │   :80   │  │   :80/:443  │      │  (sample-app, etc.)     │ │
└─────────┘   :443  │  │   :8080     │      └─────────────────────────┘ │
                    │  └──────┬──────┘                                  │
                    │         │ stdout (access log)                     │
                    │         ▼                                         │
                    │  ┌─────────────┐      ┌─────────────────────────┐ │
                    │  │  Promtail   │──────│        Loki             │ │
                    │  │  (수집)     │      │   :3100 (30일 보관)     │ │
                    │  └─────────────┘      └───────────┬─────────────┘ │
                    │                                   │               │
                    │                          ┌────────▼──────────┐    │
                    │                          │     Grafana       │    │
                    │                          │     :3000         │    │
                    │                          └───────────────────┘    │
                    └──────────────────────────────────────────────────┘
```

### 포트 구성
| 포트 | 서비스 | 용도 |
|------|--------|------|
| 80 | Traefik | HTTP 진입점 |
| 443 | Traefik | HTTPS 진입점 |
| 8080 | Traefik | Dashboard (localhost만 바인딩) |
| 3000 | Grafana | Web UI (외부 노출) |

## 핵심 파일 설명

### 설정 파일
| 파일 | 역할 |
|------|------|
| `docker-compose.yml` | 전체 서비스 정의. 네트워크, 볼륨, 서비스 구성 |
| `traefik/traefik.yml` | Traefik 정적 설정 (entry points, providers, access log) |
| `traefik/dynamic/middlewares.yml` | 재사용 가능한 미들웨어 정의 |
| `traefik/dynamic/tls.yml` | TLS 설정 (기본 비활성화) |
| `loki/loki-config.yml` | Loki 저장소 설정 (30일 보관, 파일시스템) |
| `promtail/promtail-config.yml` | Traefik access log 수집 및 라벨 추출 |
| `grafana/provisioning/datasources/datasources.yml` | Loki 데이터소스 자동 설정 |
| `grafana/provisioning/dashboards/dashboards.yml` | 대시보드 프로비저닝 설정 |
| `grafana/dashboards/endpoint-counting-dashboard.json` | 엔드포인트별 요청 카운팅 대시보드 |

### 볼륨
- `loki_data`: Loki 로그 데이터 (30일 보관)
- `grafana_data`: Grafana 설정 및 데이터

## 주요 설정 상세

### Traefik Entry Points
```yaml
web: ":80"       # HTTP
websecure: ":443" # HTTPS
```

### Traefik Access Log
JSON 형식으로 stdout에 출력합니다. Promtail이 Docker 로그로부터 수집합니다.

### Promtail 라벨 추출
Traefik access log에서 다음 필드를 Loki 라벨로 추출합니다:
- `service`: Traefik 서비스명 (ServiceName)
- `router`: Traefik 라우터명 (RouterName)
- `method`: HTTP 메소드 (RequestMethod)
- `status_class`: 응답 상태 클래스 (2xx, 3xx, 4xx, 5xx) - 카디널리티 최적화

> 개별 status_code(200, 404 등)는 라벨 카디널리티가 높아 Loki 성능에 영향을 줄 수 있어 status_class로 그룹화합니다. 정확한 status_code가 필요한 경우 쿼리 타임에 JSON 파싱으로 접근: `| json | status_code="404"`

### Health Check 자동 필터링
Promtail에서 다음 경로의 요청은 자동으로 드롭하여 Loki에 저장하지 않습니다:
- `/health`, `/healthz`, `/ping`, `/ready`, `/readyz`, `/livez`, `/status`, `/favicon.ico`

이를 통해 불필요한 로그 저장을 줄이고 카운팅 노이즈를 제거합니다.

### 사전 정의된 미들웨어
1. **rate-limit**: 100 req/s, burst 50
2. **secure-headers**: XSS 필터, HSTS, Content-Type nosniff
3. **compress**: gzip 압축 (SSE 제외)
4. **retry**: 3회 재시도, 100ms 간격
5. **circuit-breaker**: 네트워크 에러 30% 또는 5xx 25% 초과 시 차단
6. **strip-api-prefix**: /api prefix 제거
7. **add-request-id**: 요청 소스 식별 헤더 추가 (X-Request-Source)
8. **dashboard-auth**: Dashboard BasicAuth (프로덕션용, 기본 비활성화)

### 엔드포인트 카운팅 (LogQL 예시)
```logql
# 일별 서비스 요청 수
sum by (service) (count_over_time({container="traefik", service=~".+"}[1d]))

# 주별 라우터 요청 수
sum by (router) (count_over_time({container="traefik", router=~".+"}[1w]))

# 월별 서비스별 상태클래스 분포
sum by (service, status_class) (count_over_time({container="traefik"}[30d]))

# 특정 상태 코드 필터링 (쿼리 타임 JSON 파싱)
count_over_time({container="traefik"} | json | DownstreamStatus="404" [1d])

# 특정 경로 필터링 (런타임 JSON 파싱)
count_over_time({container="traefik"} | json | RequestPath=~"/api/.*" [1d])

# URL 경로별 요청 수 Top 20 (쿼리 타임 JSON 파싱)
topk(20, sum by (RequestPath) (count_over_time({container="traefik"} | json | RequestPath=~".*" [1d])))

# URL 경로별 상태 클래스 분포
sum by (RequestPath, status_class) (count_over_time({container="traefik"} | json [1d]))
```

### 대시보드 변수
| 변수 | 타입 | 설명 |
|------|------|------|
| `aggregation` | custom | 집계 기간 (1d/1w/30d) |
| `service` | query | Traefik 서비스 필터 |
| `router` | query | Traefik 라우터 필터 |
| `path_filter` | textbox | URL 경로 정규식 필터 (기본: `.*`) |

## 개발 가이드

### 새 서비스 추가
1. `docker-compose.yml`에 서비스 정의
2. `traefik-net` 네트워크에 연결
3. Traefik 라벨 추가:
   - `traefik.enable=true`
   - `traefik.http.routers.<name>.rule=Host(...)`
   - `traefik.http.routers.<name>.entrypoints=web`
   - `traefik.http.services.<name>.loadbalancer.server.port=<port>`

### 미들웨어 적용
```yaml
labels:
  - "traefik.http.routers.my-service.middlewares=rate-limit@file,secure-headers@file"
```

### HTTPS 활성화
1. `traefik/dynamic/tls.yml` 주석 해제
2. 인증서 파일 준비 (cert.pem, key.pem)
3. `docker-compose.yml`에 볼륨 마운트 추가

## 명령어

```bash
# 시작
docker compose up -d

# 로그 확인
docker compose logs -f traefik
docker compose logs -f loki
docker compose logs -f promtail
docker compose logs -f grafana

# 재시작 (설정 변경 후)
docker compose restart traefik

# 중지
docker compose down

# 데이터 포함 완전 삭제
docker compose down -v
```

## 접속 정보
- Traefik Dashboard: http://traefik.localhost:8080
- Grafana: http://grafana.localhost:3000 (admin/admin)
- Sample App: http://app.localhost

## 보안 고려사항

1. **Traefik Dashboard**: 8080 포트는 localhost만 바인딩. 프로덕션에서는 `dashboard-auth@file` 미들웨어 활성화 권장
2. **Grafana 비밀번호**: `.env` 파일에서 `GF_SECURITY_ADMIN_PASSWORD` 환경변수로 변경 (기본값: admin)
3. **TLS**: 프로덕션에서는 HTTPS 활성화 필수
4. **Loki**: 인증 비활성화 상태. 포트를 외부에 노출하지 않도록 주의

## 트러블슈팅 팁

1. **서비스가 안 보임**: `traefik.enable=true` 라벨과 `traefik-net` 네트워크 확인
2. **Loki에 로그 안 들어옴**: `docker compose logs promtail`로 수집 상태 확인
3. **Grafana 대시보드 비어 있음**: Loki 데이터소스 연결 확인, 시간 범위 조정
4. **Traefik 로그**: `docker compose logs traefik | grep -i error`
