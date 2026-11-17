FROM python:3.12-slim
ENV PYTHONUNBUFFERED=1 PORT=8080
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
COPY static ./static
# Cloud Run: 인스턴스 1개당 스레드 8개. 요청 제한시간은 Gemini 응답 대기를 고려해 90초
CMD exec gunicorn --bind :${PORT} --workers 1 --threads 8 --timeout 90 app:app
