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
