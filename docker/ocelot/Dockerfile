# Ocelot BitTorrent tracker (C++) for Gazelle.
# Single-stage so all runtime shared libs are present without version guessing.
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        g++ make pkg-config ca-certificates \
        libboost-system-dev libboost-iostreams-dev \
        libev-dev libmysql++-dev default-libmysqlclient-dev libmariadb-dev-compat \
        libgoogle-perftools-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY ocelot-1.0.tar.gz .
RUN tar xzf ocelot-1.0.tar.gz --strip-components=1 \
    && rm ocelot-1.0.tar.gz \
    # The bundled autotools macros scan hardcoded dirs that omit Debian's
    # multiarch libdir, so point each at /usr/lib/<triplet>.
    && ./configure \
        --with-boost-libdir="/usr/lib/$(gcc -dumpmachine)" \
        --with-ev-lib="/usr/lib/$(gcc -dumpmachine)" \
        --with-mysql-lib="/usr/lib/$(gcc -dumpmachine)" \
        --with-mysqlpp-lib="/usr/lib/$(gcc -dumpmachine)" \
    && make -j"$(nproc)" \
    && make install \
    && ldconfig \
    && rm -rf /build

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 2710
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
