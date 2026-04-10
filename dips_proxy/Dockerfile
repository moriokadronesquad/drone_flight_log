FROM python:3.11-slim

WORKDIR /app

# 依存パッケージインストール
COPY pyproject.toml .
RUN pip install --no-cache-dir .

# アプリケーションコピー
COPY app/ app/

# データディレクトリ（トークン保存用）
RUN mkdir -p data

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
