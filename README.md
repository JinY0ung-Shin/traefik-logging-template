# Traefik + Prometheus + Grafana Template

Docker Compose 기반 Traefik 리버스 프록시 모니터링 스택

## 빠른 시작

```bash
git clone <repository-url> && cd traefik-prometheus-template
cp .env.example .env
docker compose up -d
```

## 접속 정보

| 서비스 | URL | 비고 |
|--------|-----|------|
| Traefik Dashboard | http://traefik.localhost:8080 | |
| Grafana | http://grafana.localhost:3000 | admin/admin |
| Sample App | http://app.localhost | |
| Prometheus | http://prometheus.localhost | IP 제한 |

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

이미 `docker-compose.yml`로 서비스를 운영 중이라면 다음 단계로 통합할 수 있습니다.

### 1. 네트워크 추가

기존 `docker-compose.yml`에 외부 네트워크를 추가합니다:

```yaml
networks:
  traefik-net:
    external: true
```

### 2. 기존 서비스에 Traefik 설정 추가

각 서비스에 네트워크와 라벨을 추가합니다:

```yaml
services:
  my-api:
    image: my-api:latest
    # ports: 제거 (Traefik이 라우팅)
    networks:
      - traefik-net
      - default  # 내부 통신용 (DB 등)
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.my-api.rule=Host(`api.mydomain.com`)"
      - "traefik.http.routers.my-api.entrypoints=web"
      - "traefik.http.services.my-api.loadbalancer.server.port=3000"

  my-frontend:
    image: my-frontend:latest
    networks:
      - traefik-net
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.my-frontend.rule=Host(`mydomain.com`)"
      - "traefik.http.routers.my-frontend.entrypoints=web"
      - "traefik.http.services.my-frontend.loadbalancer.server.port=80"

  # DB 등 외부 노출 불필요한 서비스는 그대로 유지
  postgres:
    image: postgres:15
    networks:
      - default  # traefik-net 불필요
```

### 3. 템플릿 스택 실행

```bash
# 이 템플릿 디렉토리에서 먼저 실행 (네트워크 생성)
docker compose up -d

# 기존 프로젝트 디렉토리에서 실행
cd /path/to/my-project
docker compose up -d
```

### 4. 단일 Compose 파일로 합치기 (선택)

하나의 파일로 관리하려면 이 템플릿의 서비스를 기존 파일에 복사합니다:

```yaml
# 기존 docker-compose.yml에 추가
services:
  # 기존 서비스들...

  traefik:
    image: traefik:v3.0
    # ... (이 템플릿의 traefik 설정 복사)

  prometheus:
    image: prom/prometheus:v2.50.0
    # ... (이 템플릿의 prometheus 설정 복사)

  grafana:
    image: grafana/grafana:10.3.0
    # ... (이 템플릿의 grafana 설정 복사)

networks:
  traefik-net:
    driver: bridge
  default:
    driver: bridge

volumes:
  prometheus_data:
  grafana_data:
```

### 통합 체크리스트

- [ ] `traefik-net` 네트워크에 연결
- [ ] `traefik.enable=true` 라벨 추가
- [ ] 라우팅 규칙 설정 (`Host`, `PathPrefix` 등)
- [ ] 포트 번호 지정 (`loadbalancer.server.port`)
- [ ] 기존 `ports` 매핑 제거 (선택, 직접 접근 차단)

## 스케일링

```bash
docker compose up -d --scale sample-app=3
```

> `container_name` 제거 필요

## 미들웨어

| 이름 | 설명 |
|------|------|
| `rate-limit@file` | 100 req/s, burst 50 |
| `secure-headers@file` | XSS, HSTS 등 보안 헤더 |
| `compress@file` | gzip 압축 |
| `retry@file` | 3회 재시도 |
| `circuit-breaker@file` | 에러율 30% 초과 시 차단 |

## 주요 명령어

```bash
docker compose up -d          # 시작
docker compose logs -f        # 로그
docker compose down           # 중지
docker compose down -v        # 데이터 포함 삭제
```

## 환경 변수

```bash
# .env
PROMETHEUS_ALLOWED_IPS=192.168.1.0/24,10.0.0.0/8
```

---

상세 설정은 [CLAUDE.md](./CLAUDE.md) 참고

## License

MIT
