FROM debian:bookworm-slim

LABEL maintainer="thomas.saillard2@univ-eiffel.fr"

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    LC_TYPE=en_US.UTF-8 \
    # UV configuration
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy

RUN apt-get update && apt-get install -y --no-install-recommends \
    sudo \
    gnupg2 \
    libasound2 \
    libasound2-data \
    locales \
    wget \
    curl \
    ca-certificates \
    build-essential \
    libssl-dev \
    nasm \
    openssl \
    unzip \
    git \
    libbsd-dev \
    # Programming languages
    ghc \
    clang \
    ocaml-nox \
    ocaml \
    perl \
    perl-doc \
    # Java (architecture agnostic)
    openjdk-17-jdk \
    # Database
    postgresql \
    sqlite3 \
    # R
    r-base \
    # LaTeX - Use specific packages instead of texlive-full
    texlive-base \
    texlive-latex-base \
    texlive-latex-recommended \
    texlive-latex-extra \
    texlive-fonts-recommended \
    texlive-science \
    texlive-lang-french \
    latexmk \
    # PDF utilities
    poppler-utils \
    && apt-get clean \
    && apt-get autoclean \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Configure locale
RUN echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
    && locale-gen "en_US.UTF-8" \
    && dpkg-reconfigure -f noninteractive locales

# Install UV early (needed for Python installation)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"

# Install Python and PyPy via uv
RUN uv python install cpython@3.14 cpython@3.11 pypy@3.11 && \
    # Create symlinks for Python 3.11
    PYTHON_PATH=$(uv python find cpython@3.11) && \
    PYTHON_BIN_DIR=$(dirname "$PYTHON_PATH") && \
    ln -sf "$PYTHON_PATH" /usr/local/bin/python3 && \
    ln -sf "$PYTHON_PATH" /usr/local/bin/python && \
    ln -sf "$PYTHON_BIN_DIR/pip3" /usr/local/bin/pip3 2>/dev/null || true && \
    ln -sf "$PYTHON_BIN_DIR/pip" /usr/local/bin/pip 2>/dev/null || true && \
    # Create symlinks for Python 3.14
    PYTHON_PATH=$(uv python find cpython@3.14) && \
    PYTHON_BIN_DIR=$(dirname "$PYTHON_PATH") && \
    ln -sf "$PYTHON_PATH" /usr/local/bin/python3.14 && \
    ln -sf "$PYTHON_BIN_DIR/pip3" /usr/local/bin/pip3.14 2>/dev/null || true && \
    # Create symlinks for PyPy
    PYPY_PATH=$(uv python find pypy@3.11) && \
    ln -sf "$PYPY_PATH" /usr/local/bin/pypy3 && \
    ln -sf "$PYPY_PATH" /usr/local/bin/pypy

RUN ARCH=$(arch | sed 's/x86_64/amd64/' | sed 's/aarch64/arm64/') && \
    update-alternatives --install /usr/bin/java java /usr/lib/jvm/java-17-openjdk-${ARCH}/bin/java 2 && \
    update-alternatives --install /usr/bin/javac javac /usr/lib/jvm/java-17-openjdk-${ARCH}/bin/javac 2 && \
    ln -sf /usr/lib/jvm/java-17-openjdk-${ARCH} /usr/lib/jvm/java-17-openjdk

ENV JAVA_HOME="/usr/lib/jvm/java-17-openjdk"

# Create utils directory structure
RUN mkdir -p /utils/libs
ENV PATH="/utils/libs/:${PATH}" \
    PYTHONPATH="/utils/libs/"

RUN ARCH_SUFFIX=$(arch | sed 's/x86_64/x64/' | sed 's/aarch64/aarch64/') && \
    wget --progress=dot:giga "https://download.oracle.com/java/26/latest/jdk-26_linux-${ARCH_SUFFIX}_bin.tar.gz" -O /tmp/jdk-26.tar.gz && \
    mkdir -p /usr/lib/jvm/jdk-26-oracle && \
    tar -xzf /tmp/jdk-26.tar.gz -C /usr/lib/jvm/jdk-26-oracle --strip-components=1 && \
    rm -f /tmp/jdk-26.tar.gz && \
    update-alternatives --install /usr/bin/java java /usr/lib/jvm/jdk-26-oracle/bin/java 3 && \
    update-alternatives --install /usr/bin/javac javac /usr/lib/jvm/jdk-26-oracle/bin/javac 3

# Download JUnit standalone jar (only once, latest version)
RUN wget --progress=dot:giga \
    https://repo1.maven.org/maven2/org/junit/platform/junit-platform-console-standalone/1.10.3/junit-platform-console-standalone-1.10.3.jar \
    -O /utils/junit-platform-console-standalone.jar

# Download JavaParser jar
RUN wget --progress=dot:giga \
    https://repo1.maven.org/maven2/com/github/javaparser/javaparser-core/3.26.1/javaparser-core-3.26.1.jar \
    -O /utils/javaparser-core.jar

# Install Scala 2.13.18 (compatible with Spark 4.x)
ENV SCALA_VERSION=2.13.18
RUN wget --progress=dot:giga \
    https://github.com/scala/scala/releases/download/v${SCALA_VERSION}/scala-${SCALA_VERSION}.tgz \
    -O /tmp/scala.tgz && \
    tar -xzf /tmp/scala.tgz -C /usr/local && \
    ln -sf /usr/local/scala-${SCALA_VERSION} /usr/local/scala && \
    rm -f /tmp/scala.tgz

ENV PATH="/usr/local/scala/bin:${PATH}"

# Install Apache Spark 4.1.1 (pre-built with Scala 2.13, Hadoop 3)
ENV SPARK_VERSION=4.1.1
RUN wget --progress=dot:giga \
    https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop3.tgz \
    -O /tmp/spark.tgz && \
    tar -xzf /tmp/spark.tgz -C /usr/local && \
    ln -sf /usr/local/spark-${SPARK_VERSION}-bin-hadoop3 /usr/local/spark && \
    rm -f /tmp/spark.tgz

ENV SPARK_HOME="/usr/local/spark"
ENV PATH="${SPARK_HOME}/bin:${SPARK_HOME}/sbin:${PATH}"

ENV NODE_VERSION=v20.13.1 \
    NVM_DIR=/usr/local/nvm

RUN mkdir -p ${NVM_DIR} /var/www/.npm/_logs && \
    wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash && \
    . ${NVM_DIR}/nvm.sh && \
    nvm install ${NODE_VERSION}

ENV PATH="/usr/local/nvm/versions/node/${NODE_VERSION}/bin:${PATH}"

# Copy package.json separately for better caching
COPY package.json /tmp/package.json
RUN cd /tmp && \
    npm install && \
    npm i -D @swc/cli @swc/core && \
    rm -rf /tmp/package.json /tmp/node_modules

# Setup npm permissions
RUN touch /var/www/.npm/_update-notifier-last-checked && \
    chmod 755 -R /var/www/.npm/ && \
    chown -R www-data:www-data /var/www/.npm/

RUN yes | cpan -l > /dev/null 2>&1 || true


COPY libraries.py /utils/libraries.py

# Install Python packages
COPY requirements.txt /tmp/requirements.txt
RUN uv pip install --system --break-system-packages -r /tmp/requirements.txt && \
    rm -f /tmp/requirements.txt && \
    uv cache clean


WORKDIR /home/student
RUN chmod -R a+rwx /home/student

RUN rm -rf /tmp/* /var/tmp/*

CMD ["bash"]
