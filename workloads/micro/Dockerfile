FROM python:3.12-slim
WORKDIR /app
COPY app.py requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt && pip install --no-cache-dir gunicorn httpx flask requests
EXPOSE 5000
CMD ["gunicorn", "-w", "4", "-b", "0.0.0.0:5000", "app:app"]