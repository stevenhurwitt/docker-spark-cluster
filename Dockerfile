FROM openjdk:8-jre-slim-buster as builder

ARG shared_workspace=/opt/workspace

RUN rm /bin/sh && ln -s /bin/bash /bin/sh

# Add Dependencies for PySpark
RUN apt-get update && apt-get install -y curl nano wget zip unzip software-properties-common ssh net-tools ca-certificates zlib1g-dev libjpeg62-turbo-dev libffi-dev python3 python3-pip python3-matplotlib python3-numpy python3-pandas

RUN update-alternatives --install "/usr/bin/python" "python" "$(which python3)" 1

# Fix the value of PYTHONHASHSEED
# Note: this is needed when you use Python 3.3 or greater
ENV SPARK_VERSION=3.2.0 \
HADOOP_VERSION=3.2 \
SPARK_HOME=/opt/spark \
PYTHONHASHSEED=1 \
SHARED_WORKSPACE=${shared_workspace}

# Install spark
RUN wget --no-verbose -O apache-spark.tgz "https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz" \
&& mkdir -p /opt/spark \
&& tar -xf apache-spark.tgz -C /opt/spark --strip-components=1 \
&& rm apache-spark.tgz

# Install python packages
RUN pip3 install ipykernel && \
    pip3 install jupyter && \
    pip3 install wget && \
    pip3 install pyspark==${SPARK_VERSION}

# sdkman for scala & maven
RUN curl -s https://get.sdkman.io | bash
RUN chmod a+x "$HOME/.sdkman/bin/sdkman-init.sh" && \
    source "$HOME/.sdkman/bin/sdkman-init.sh" && \
    sdk install maven && \
    sdk install scala 2.12.15 && \
    sdk use scala 2.12.15

# almond.sh for scala jupyter kernel
RUN curl -Lo coursier https://git.io/coursier-cli && \
    chmod +x coursier && \
    ./coursier --help

RUN ./coursier launch --fork almond:0.11.1 -v -v --scala 2.12 -- --install && \
    rm -f coursier


VOLUME ${shared_workspace}

WORKDIR ${SHARED_WORKSPACE}


FROM builder as apache-spark

WORKDIR /opt/spark

# ARG shared_workspace=/opt/workspace

ENV SPARK_MASTER_PORT=7077 \
SPARK_MASTER_WEBUI_PORT=8080 \
SPARK_LOG_DIR=/opt/spark/logs \
SPARK_MASTER_LOG=/opt/spark/logs/spark-master.out \
SPARK_WORKER_LOG=/opt/spark/logs/spark-worker.out \
SPARK_WORKER_WEBUI_PORT=8080 \
SPARK_WORKER_PORT=7000 \
SPARK_MASTER="spark://spark-master:7077" \
SPARK_WORKLOAD="master" \
SHARED_WORKSPACE=${shared_workspace}

# VOLUME ${shared_workspace}

EXPOSE 8080 7077 7000 4040

RUN mkdir -p $SPARK_LOG_DIR && \
touch $SPARK_MASTER_LOG && \
touch $SPARK_WORKER_LOG && \
ln -sf /dev/stdout $SPARK_MASTER_LOG && \
ln -sf /dev/stdout $SPARK_WORKER_LOG

COPY start-spark.sh /

CMD ["/bin/bash", "/start-spark.sh"]