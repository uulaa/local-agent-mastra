# Локал AI Агент — Суулгах бүрэн заавар

Энэ заавар нь төслийг `git clone` хийснээс эхлээд ажиллаж байгаа демо хүртэл
алхам алхмаар хүргэнэ. Бүх зүйл таны компьютер дээр локал ажиллана — гадаад
(cloud) AI үйлчилгээ ашиглахгүй.

## Систем юу хийдэг вэ?

**Jarvis** нэртэй AI туслах нь асуултын төрлөөс хамаарч хоёр өгөгдлийн эх
үүсвэрийн аль тохирохыг өөрөө сонгож хариулна:

- **PostgreSQL** — бодит бизнесийн тоон мэдээлэл (борлуулалт, нэхэмжлэх,
  худалдан авагч гэх мэт). Жишээ: «Өнгөрсөн сарын борлуулалт хэд байсан бэ?»
- **Qdrant** — компанийн дотоод баримт бичгүүдээс утгын хайлт (дүрэм журам,
  бодлого). Жишээ: «Манай амралтын бодлого ямар вэ?»

Мөн харилцан ярианы санах ойтой тул өмнөх асуултаа үргэлжлүүлж асууж болно.

## 1. Урьдчилсан шаардлага

| Шаардлага | Тайлбар |
| --- | --- |
| **Docker Desktop** | Windows/Mac: [docker.com](https://www.docker.com/products/docker-desktop/)-оос суулгана. Linux: Docker Engine + Compose v2 |
| **Дискний зай** | Ойролцоогоор 10 GB (Docker image + AI модель ~3 GB) |
| **RAM** | Хамгийн багадаа 8 GB (16 GB байвал илүү хурдан) |
| **Интернет** | Зөвхөн эхний ажиллуулалтад — модель татахад хэрэгтэй |

Docker ажиллаж байгаа эсэхийг шалгах:

```sh
docker --version
docker compose version
```

Хоёулаа хувилбараа хэвлэвэл бэлэн. Алдаа гарвал Docker Desktop-оо нээж,
бүрэн ачаалагдтал хүлээгээрэй.

## 2. Төслийг татах

```sh
git clone <repo-url> ai-agent
cd ai-agent
```

Хавтасны бүтэц:

```
ai-agent/
├── ai-agent-web/    Чат интерфейс (Next.js)
├── ai-agent-back/   AI агент (Mastra) + хэрэгслүүд
└── deployment/      docker-compose + тохиргоо (.env)
```

## 3. Тохиргоо (.env)

Бүх тохиргоо [deployment/.env](deployment/.env) файлд байгаа бөгөөд **ажиллахад
бэлэн утгуудтай** — юу ч засалгүйгээр шууд ажиллуулж болно. Хүсвэл дараах
утгуудыг өөрчилж болно:

```ini
# AI модель (tool calling дэмждэг байх ЁСТОЙ: qwen3 / qwen2.5 болно, Gemma болохгүй!)
OLLAMA_MODEL=qwen3:4b        # сул компьютерт: qwen3:1.7b (хурдан, чанар арай сул)

# Моделийн sampling параметрүүд
LLM_TEMPERATURE=0.3
LLM_TOP_P=0.9
LLM_TOP_K=30

# Баримт бичгийг хэсэглэх (Qdrant ingest)
CHUNK_SIZE=400
CHUNK_OVERLAP=60

# Портууд (өөр програмтай зөрчилдвөл солино)
WEB_PORT=3000
BACK_PORT=4111
POSTGRES_PORT=5432
```

## 4. Ажиллуулах

```sh
cd deployment
docker compose up -d --build
```

**Эхний ажиллуулалт удаан** (интернетийн хурднаас хамаарч 10–30 минут):
Docker image-үүд build хийгдэж, AI модель (~2.9 GB) татагдана. Дараагийн
удаа хэдхэн секундэд асна — модель, өгөгдөл бүгд Docker volume-д хадгалагдана.

Энэ нэг команд дараахыг **бүгдийг автоматаар** хийнэ:

1. PostgreSQL асаад демо өгөгдлөөр дүүргэнэ (12 хүснэгт, мянга мянган мөр)
2. Qdrant асна
3. Ollama асаад qwen3 + embedding моделийг татна (`llm-init`)
4. Компанийн баримтуудыг Qdrant руу оруулна (`ingest`)
5. Backend (Mastra) болон Web UI асна

## 5. Бүх үйлчилгээ ажиллаж байгааг шалгах

```sh
docker compose ps -a
```

Хүлээгдэж буй төлөвүүд:

| Үйлчилгээ | Төлөв |
| --- | --- |
| `web` | Up |
| `back` | Up |
| `postgres` | Up (healthy) |
| `qdrant` | Up (healthy) |
| `llm` | Up (healthy) |
| `llm-init` | **Exited (0)** — нэг удаа ажиллаад дуусдаг (модель татах) |
| `ingest` | **Exited (0)** — нэг удаа ажиллаад дуусдаг (баримт оруулах) |

`Exited (0)` нь эдгээр хоёрын хувьд хэвийн — алдаа биш!

## 6. Агентыг турших

Хөтчөөр **http://localhost:3000** нээнэ. Дараах асуултуудыг туршаарай:

- **«Who are you?»** → «I am the AI assistant of Novatech Solutions. My name
  is Jarvis.» гэж хариулна (хэдхэн секунд)
- **«What were last month's sales?»** → Агент өгөгдлийн санг шалгаж, SQL
  бичиж, бодит тоогоор хариулна. **CPU дээр 1–4 минут** болно — «Querying
  database…» гэсэн үйл явц харагдана.
- **«What is our vacation policy?»** → Баримт бичгээс хайж, эх сурвалжийг
  дурдаж хариулна (~1 минут)
- Монголоор ч асууж болно — асуусан хэлээрээ хариулдаг.
- Санах ойг турших: «Намайг Эрдэнэ гэдэг» гээд дараа нь «Намайг хэн гэдэг
  билээ?» гэж асуугаарай.

Мөн **http://localhost:4111** дээр Mastra playground нээгдэнэ — агентын tool
дуудалтуудыг дэлгэрэнгүй харж болно.

## 7. Алдаа засах (Troubleshooting)

### Лог харах

```sh
docker compose logs back      # backend-ийн лог
docker compose logs web       # frontend-ийн лог
docker compose logs llm-init  # модель татсан лог
docker compose logs ingest    # баримт оруулсан лог
docker compose logs -f back   # шууд (live) дагаж харах
```

### Түгээмэл асуудлууд

| Асуудал | Шийдэл |
| --- | --- |
| `docker: command not found` / холбогдохгүй | Docker Desktop асаагүй байна — нээгээд бүрэн ачаалагдтал хүлээнэ |
| `port is already allocated` | Тухайн портыг өөр програм эзэлсэн — `deployment/.env` дотор портоо солиод `docker compose up -d` дахин ажиллуулна |
| `llm-init` Exited (1) | Модель татаж чадаагүй (интернет тасарсан) — `docker compose up -d` дахин ажиллуулахад үргэлжлүүлж татна |
| Хариулт хэт удаан | CPU inference удаан байдаг. `.env`-д `OLLAMA_MODEL=qwen3:1.7b` болгоод: `docker compose up -d llm-init && docker compose restart back` |
| Веб нээгдэхгүй | `docker compose ps` — `web` Up эсэхийг шалгана. Унтарсан бол `docker compose up -d web` |
| «Error: ... Is the Mastra server running» | `back` унтарсан — `docker compose logs back` хараад `docker compose up -d back` |
| Код өөрчилсний дараа шинэчлэгдэхгүй | `docker compose up -d --build` (build хийхгүй бол хуучин image ажиллана) |

### Дахин эхлүүлэх

```sh
docker compose restart          # бүх үйлчилгээг дахин асаана
docker compose down             # бүгдийг унтраана (өгөгдөл хадгалагдана)
docker compose down -v          # бүгдийг унтрааж, ӨГӨГДЛИЙГ УСТГАНА
                                # (модель дахин татагдаж, өгөгдөл дахин үүснэ)
```

### Баримт бичиг нэмэх/солих

Өөрийн баримтуудыг (`.md` эсвэл `.txt`) `ai-agent-back/docs/` хавтаст хийгээд:

```sh
docker compose build ingest && docker compose run --rm ingest
```

## Асуулт байвал

Дэлгэрэнгүй техникийн мэдээллийг дараах README-үүдээс үзнэ үү:

- [deployment/README.md](deployment/README.md) — Docker stack-ийн бүтэц
- [ai-agent-back/README.md](ai-agent-back/README.md) — Агент, хэрэгслүүд, санах ой
- [ai-agent-web/README.md](ai-agent-web/README.md) — Чат интерфейс
