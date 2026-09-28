FROM python:3.12-slim
WORKDIR /app
COPY src/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt
COPY src /app/src
COPY fixtures /app/fixtures
ENV PYTHONPATH=/app/src
WORKDIR /app/src
EXPOSE 8000
CMD ["uvicorn","app:app","--host","0.0.0.0","--port","8000"]
