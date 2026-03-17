FROM mcr.microsoft.com/azure-sql-edge:latest

USER root

# Install sqlcmd (mssql-tools18) permanently into the image
RUN apt-get update && \
    ACCEPT_EULA=Y apt-get install -y curl apt-transport-https gnupg2 && \
    curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - && \
    curl https://packages.microsoft.com/config/ubuntu/20.04/prod.list \
        > /etc/apt/sources.list.d/mssql-release.list && \
    apt-get update && \
    ACCEPT_EULA=Y apt-get install -y mssql-tools18 unixodbc-dev && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Add sqlcmd to PATH for all users
ENV PATH="$PATH:/opt/mssql-tools18/bin"

USER mssql
