# ===========================
# Étape de Build (Compilation de l'extension)
# ===========================
FROM debian:bookworm AS builder

# Ajouter le dépôt PostgreSQL officiel
RUN apt-get update && apt-get install -y curl findutils ca-certificates gnupg lsb-release \
    && curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/postgresql-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/postgresql-keyring.gpg] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" | tee /etc/apt/sources.list.d/postgresql.list \
    && apt-get update

# Installer les dépendances nécessaires
RUN apt-get install -y \
    build-essential git cargo \
    postgresql-server-dev-16 postgresql-plperl-16 \
    pkg-config libssl-dev \
    && rm -rf /var/lib/apt/lists/*


# Installer Rust et Cargo
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# Installer `cargo-pgrx`
RUN cargo install --locked cargo-pgrx
# Initialiser pgrx après son installation
RUN cargo pgrx init --pg16 `which pg_config`

RUN echo "# Cloner et compiler PostgreSQL Anonymizer avec la bonne config"

RUN git clone --depth 1 --branch 2.0.0 https://gitlab.com/dalibo/postgresql_anonymizer.git
WORKDIR postgresql_anonymizer
RUN echo "******* make ********" 
RUN make extension PGVER="16" PG_CONFIG=$(which pg_config) 
RUN echo " ***** find ? *******"
RUN bash -c find / -name "*anon*"
RUN echo "******* install  ********"
RUN make install PGVER="pg16" G_CONFIG=$(which pg_config)


# ===========================
# Étape Finale (Run)
# ===========================
FROM postgres:16

COPY --from=builder  /postgresql_anonymizer/target/release/anon-pg16/usr/lib/postgresql/16/lib/anon.so /usr/lib/postgresql/16/lib/anon.so
COPY --from=builder /postgresql_anonymizer//target/release/anon-pg16/usr/share/postgresql/16/extension /usr/share/postgresql/16/extension


# Ajouter les scripts d'initialisation
COPY init-scripts /docker-entrypoint-initdb.d/

# Définir les variables d’environnement par défaut
ENV POSTGRES_USER=myuser
ENV POSTGRES_PASSWORD=mypassword
ENV POSTGRES_DB=mydb

EXPOSE 5432

