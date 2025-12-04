# Use official Python image
FROM python:3.10-slim

# Set environment variables
# ENV PYTHONDONTWRITEBYTECODE 1
# ENV PYTHONUNBUFFERED 1

# Set work directory
WORKDIR /app

# Install dependencies
COPY Pipfile Pipfile.lock requirements.txt /app/
RUN pip install --upgrade pip
RUN pip install pipenv && pipenv install --system --deploy --ignore-pipfile
RUN pip install whitenoise==6.5.0

# Copy project
COPY . /app/

# Collect static files
RUN python manage.py collectstatic --noinput

# Expose port
EXPOSE 8000

# Start Gunicorn
CMD ["gunicorn", "littlelemon.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "3"]
