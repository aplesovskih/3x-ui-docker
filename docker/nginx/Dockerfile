FROM nginx:stable

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        nginx-full \
        sqlite3 \
        openssl \
        curl \
        netcat-openbsd && \
    rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80 443 8443 9443

ENTRYPOINT ["/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
