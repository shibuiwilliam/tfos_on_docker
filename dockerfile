FROM ubuntu
MAINTAINER cvusk

# insert hostname on environmental variable
ENV HOSTNAME tensorflow.spark

# install prerequisites
RUN apt-get -y update
RUN apt-get -y upgrade
RUN apt-get -y install apt-utils
RUN apt-get -y install software-properties-common python-software-properties
RUN add-apt-repository ppa:openjdk-r/ppa
RUN apt-get -y update
RUN apt-get -y install wget curl zip unzip vim openjdk-7-jre openjdk-7-jdk git python-pip python-dev python-virtualenv
ENV JAVA_HOME=/usr/lib/jvm/java-7-openjdk-amd64

# git clone tensorflowonspark.git
WORKDIR /opt/
RUN git clone --recurse-submodules https://github.com/yahoo/TensorFlowOnSpark.git

WORKDIR /opt/TensorFlowOnSpark/
RUN git submodule init
RUN git submodule update --force
RUN git submodule foreach --recursive git clean -dfx

# environmental variable for tensorflowonspark home
ENV TFoS_HOME=/opt/TensorFlowOnSpark

WORKDIR /opt/TensorFlowOnSpark/src/
RUN zip -r /opt/TensorFlowOnSpark/tfspark.zip /opt/TensorFlowOnSpark/src/*
WORKDIR /opt/TensorFlowOnSpark/

# setup spark
RUN sh /opt/TensorFlowOnSpark/scripts/local-setup-spark.sh
ENV SPARK_HOME=/opt/TensorFlowOnSpark/spark-1.6.0-bin-hadoop2.6
ENV PATH=/opt/TensorFlowOnSpark/src:${PATH}
ENV PATH=${SPARK_HOME}/bin:${PATH}
ENV PYTHONPATH=/opt/TensorFlowOnSpark/src


# install tensorflow, jupyter and py4j
RUN pip install pip --upgrade
RUN python -m pip install tensorflow
RUN pip install jupyter jupyter[notebook]
RUN pip install py4j


# download mnist data
RUN mkdir /opt/TensorFlowOnSpark/mnist
WORKDIR /opt/TensorFlowOnSpark/mnist/
RUN curl -O "http://yann.lecun.com/exdb/mnist/train-images-idx3-ubyte.gz"
RUN curl -O "http://yann.lecun.com/exdb/mnist/train-labels-idx1-ubyte.gz"
RUN curl -O "http://yann.lecun.com/exdb/mnist/t10k-images-idx3-ubyte.gz"
RUN curl -O "http://yann.lecun.com/exdb/mnist/t10k-labels-idx1-ubyte.gz"


# create shellscript for starting spark standalone cluster
RUN echo '${SPARK_HOME}/sbin/start-master.sh' >> ${TFoS_HOME}/spark_cluster.sh
RUN echo 'MASTER=spark://${HOSTNAME}:7077' >> ${TFoS_HOME}/spark_cluster.sh
RUN echo 'SPARK_WORKER_INSTANCES=2' >> ${TFoS_HOME}/spark_cluster.sh
RUN echo 'CORES_PER_WORKER=1' >> ${TFoS_HOME}/spark_cluster.sh
RUN echo 'TOTAL_CORES=$((${CORES_PER_WORKER}*${SPARK_WORKER_INSTANCES}))' >> ${TFoS_HOME}/spark_cluster.sh
RUN echo '${SPARK_HOME}/sbin/start-slave.sh -c $CORES_PER_WORKER -m 3G ${MASTER}' >> ${TFoS_HOME}/spark_cluster.sh
RUN echo '${SPARK_HOME}/sbin/start-slave.sh -c $CORES_PER_WORKER -m 3G ${MASTER}' >> ${TFoS_HOME}/spark_cluster.sh


ENV MASTER=spark://${HOSTNAME}:7077
ENV SPARK_WORKER_INSTANCES=2
ENV CORES_PER_WORKER=1
ENV TOTAL_CORES=2


# create shellscript for pyspark on jupyter and mnist data
WORKDIR /opt/TensorFlowOnSpark/

RUN echo "PYSPARK_DRIVER_PYTHON=\"jupyter\" PYSPARK_DRIVER_PYTHON_OPTS=\"notebook --no-browser --ip=* --NotebookApp.token=''\" pyspark  --master ${MASTER} --conf spark.cores.max=${TOTAL_CORES} --conf spark.task.cpus=${CORES_PER_WORKER} --py-files ${TFoS_HOME}/tfspark.zip,${TFoS_HOME}/examples/mnist/spark/mnist_dist.py --conf spark.executorEnv.JAVA_HOME=\"$JAVA_HOME\"" > ${TFoS_HOME}/pyspark_notebook.sh

RUN echo "${SPARK_HOME}/bin/spark-submit --master ${MASTER} ${TFoS_HOME}/examples/mnist/mnist_data_setup.py --output examples/mnist/csv --format csv" > ${TFoS_HOME}/mnist_data_setup.sh


ENV SPARK_MASTER_OPTS="-Dspark.driver.port=7001 -Dspark.fileserver.port=7002 -Dspark.broadcast.port=7003 -Dspark.replClassServer.port=7004 -Dspark.blockManager.port=7005 -Dspark.executor.port=7006 -Dspark.ui.port=4040 -Dspark.broadcast.factory=org.apache.spark.broadcast.HttpBroadcastFactory"
ENV SPARK_WORKER_OPTS="-Dspark.driver.port=7001 -Dspark.fileserver.port=7002 -Dspark.broadcast.port=7003 -Dspark.replClassServer.port=7004 -Dspark.blockManager.port=7005 -Dspark.executor.port=7006 -Dspark.ui.port=4040 -Dspark.broadcast.factory=org.apache.spark.broadcast.HttpBroadcastFactory"
EXPOSE 8080 7077 8888 8081 4040 7001 7002 7003 7004 7005 7006
