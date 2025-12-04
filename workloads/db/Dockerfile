FROM postgres:16
ENV POSTGRES_PASSWORD=test123
ENV POSTGRES_USER=postgres
ENV POSTGRES_DB=testdb
COPY init.sql /docker-entrypoint-initdb.d/
EXPOSE 5432
