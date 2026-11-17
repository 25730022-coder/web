# D-Tective

딥페이크·스미싱·가짜뉴스를 탐지하는 채팅형 웹서비스. 프론트엔드와 Gemini 연동 백엔드를 **Cloud Run 서비스 1개**로 배포합니다.

```
dtective/
├─ app.py            Flask 백엔드 (Gemini 호출, /api/analyze /api/chat /api/ranking)
├─ static/index.html 프론트엔드
├─ .env              API 키 입력 파일 (Git·Docker 이미지에는 포함되지 않음)
├─ requirements.txt  Dockerfile
```

## 1. 로컬에서 실행

1. 프로젝트 폴더의 **`.env`** 파일을 메모장(또는 Cursor)으로 엽니다. (맥·리눅스는 숨김 파일이라 `ls -a`로 보입니다)
2. `GEMINI_API_KEY=` 뒤에 발급받은 키를 따옴표 없이 붙여넣고 저장합니다.
3. 실행합니다. 이후로는 키를 다시 입력할 필요가 없습니다.

```bash
pip install -r requirements.txt
python app.py        # http://localhost:8080
```

API 키는 Google AI Studio(aistudio.google.com)에서 발급합니다. `.env`는 `.gitignore`에 들어 있어 Git에 올라가지 않지만, **GitHub에 올릴 때 `.env`가 빠졌는지 꼭 확인하고, 키를 채팅창·코드에 붙여 넣지 마세요.**

## 2. Cloud Run 배포

```bash
gcloud config set project 내_프로젝트_ID
gcloud services enable run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com secretmanager.googleapis.com

# API 키를 Secret Manager에 저장
printf %s "발급받은_키" | gcloud secrets create gemini-api-key --data-file=-

# Cloud Run 실행 계정이 비밀을 읽을 수 있게 권한 부여
PROJECT_NUMBER=$(gcloud projects describe $(gcloud config get-value project) --format='value(projectNumber)')
gcloud secrets add-iam-policy-binding gemini-api-key \
  --member="serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"

# 이 폴더에서 배포 (.env 는 서버로 올라가지 않으며, 서버에서는 위 Secret 이 키로 사용됩니다)
gcloud run deploy dtective --source . --region asia-northeast3 --allow-unauthenticated \
  --set-secrets GEMINI_API_KEY=gemini-api-key:latest \
  --set-env-vars GEMINI_MODEL=gemini-flash-latest,RATE_LIMIT_PER_MIN=10 \
  --max-instances 3 --concurrency 20
```

배포가 끝나면 출력되는 `https://dtective-xxxx.run.app` 주소로 PC·모바일에서 접속할 수 있습니다.

## 3. 꼭 확인할 것

- **비용 보호**: 누구나 접속하는 서비스라 Gemini 호출 비용이 늘 수 있습니다. Google Cloud 콘솔 → 결제 → 예산 및 알림에서 예산 알림을 만들고, `--max-instances`를 유지하세요.
- **모델 이름**: `GEMINI_MODEL`의 기본값은 `gemini-flash-latest`(최신 Flash 별칭)입니다. 발표·시연 전에는 동작을 확인한 모델명(예: 공식 문서의 `gemini-3.x-flash`)으로 고정해 결과가 바뀌지 않게 하세요. 모델명이 틀리면 화면에 "AI 설정에 문제가 있어요"가 표시됩니다.
- **요청 제한**(`RATE_LIMIT_PER_MIN`)과 **오늘의 위험 순위**는 인스턴스 메모리에 저장됩니다. 인스턴스가 여러 개이거나 재시작되면 초기화되고 인스턴스마다 따로 집계됩니다. 정확한 집계가 필요하면 Firestore 같은 저장소로 옮기세요.
- 회원가입·로그인·탈퇴·채팅 기록은 아직 **브라우저 저장소(localStorage)** 데모입니다. 여러 기기 공유와 서버 저장은 다음 단계(Firebase Auth + Firestore 등)에서 연결합니다.
- 가짜뉴스 분석은 Google 검색 근거를 함께 쓰고(지원되지 않는 모델이면 자동으로 검색 없이 분석), 자동 유형 선택에서는 검색을 쓰지 않습니다.
- AI 판정은 확정이 아닌 참고 정보입니다. 화면 안내 문구를 유지하세요.

## API 요약

| 요청 | 본문 | 응답 |
|---|---|---|
| `POST /api/analyze` | `{type, text, image:{mime,data(base64)}}` | `{type, verdict, risk, title, summary, reasons, cautions}` |
| `POST /api/chat` | `{message, mode, context, history}` | `{reply}` |
| `GET /api/ranking` | - | `{items:[{label,count}]}` |

오류는 `{error: "사용자에게 보여줄 한국어 안내"}`와 함께 400·413·422·429·502·503으로 반환됩니다.
