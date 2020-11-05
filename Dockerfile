FROM ubuntu:16.04

ENV DEBIAN_FRONTEND=noninteractive \
    GPG_KEY=C01E1CAD5EA2C4F0B8E3571504C367C218ADD4FF \
    PYTHON_VERSION=2.7.15 \
    PYTHON_PIP_VERSION=10.0.1 \
    CAFFE_DIR=/root/caffe SNPE_ROOT=/root/snpe

WORKDIR /root
VOLUME "/root/snpe"
SHELL ["/bin/bash", "-c"]

RUN echo hello && set -xe \
		\
 		&& apt-get update \
 		&& apt-get -y --no-install-recommends install \
			libprotobuf-dev protobuf-compiler \
	 		libleveldb-dev libsnappy-dev libopencv-dev libhdf5-serial-dev libboost-all-dev libatlas-base-dev \
	 		cmake \
	 		libgflags-dev libgoogle-glog-dev liblmdb-dev \
 		\
    && apt-get install -y --no-install-recommends \
      tcl tk \
    && apt-get install -y gcc g++ wget zip git android-tools-adb android-tools-fastboot

#python
RUN set -ex \
  && buildDeps=' \
    dpkg-dev \
    tcl-dev \
    tk-dev \
  ' \
  && apt-get install -y $buildDeps openssl libssl-dev --no-install-recommends \
  \
  && wget --no-check-certificate -O python.tar.xz "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz" \
  && wget --no-check-certificate -O python.tar.xz.asc "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz.asc" \
  && export GNUPGHOME="$(mktemp -d)" \
  && gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$GPG_KEY" \
  && gpg --batch --verify python.tar.xz.asc python.tar.xz \
  && rm -rf "$GNUPGHOME" python.tar.xz.asc \
  && mkdir -p /usr/src/python \
  && tar -xJC /usr/src/python --strip-components=1 -f python.tar.xz \
  && rm python.tar.xz \
  \
  && cd /usr/src/python \
  && gnuArch="$(dpkg-architecture -qDEB_BUILD_GNU_TYPE)" \
  && ./configure \
    --build="$gnuArch" \
    --enable-shared \
    --with-shared \
    --enable-unicode=ucs4 \
    --enable-optimizations \
  && make -j "$(nproc)" \
  && make install \
  && ldconfig \
  \
  \
  && find /usr/local -depth \
    \( \
      \( -type d -a \( -name test -o -name tests \) \) \
      -o \
      \( -type f -a \( -name '*.pyc' -o -name '*.pyo' \) \) \
    \) -exec rm -rf '{}' + \
  && rm -rf /usr/src/python

RUN set -ex; \
  \
  wget --no-check-certificate -O get-pip.py 'https://bootstrap.pypa.io/get-pip.py'; \
  \
  python get-pip.py \
    --disable-pip-version-check \
    --no-cache-dir \
    "pip==$PYTHON_PIP_VERSION" \
  ; \
  pip --version; \
  \
  find /usr/local -depth \
    \( \
      \( -type d -a \( -name test -o -name tests \) \) \
      -o \
      \( -type f -a \( -name '*.pyc' -o -name '*.pyo' \) \) \
    \) -exec rm -rf '{}' +; \
  rm -f get-pip.py

#Done with python

RUN set -ex \
	&& apt-get -y --no-install-recommends install python-numpy gfortran \
	&& pip install cython \
	&& pip install numpy==1.14.5 \
		sphinx==1.2.2 \
		scipy==1.1.0 \
		matplotlib==2.0.0 \
		scikit-image \
	protobuf==2.5.0 \
	pyyaml==3.10 
RUN cd /root \
  && wget --no-check-certificate https://github.com/google/glog/archive/v0.3.3.tar.gz \
	  && tar zxvf v0.3.3.tar.gz && rm -f v0.3.3.tar.gz\
	  && cd glog-0.3.3 \
	  && ./configure \
	  && make && make install \
	  \
  && cd /root \
  && wget --no-check-certificate https://github.com/schuhschuh/gflags/archive/master.zip \
	  && unzip master.zip && rm -f master.zip \
	  && cd gflags-master \
	  && mkdir build \
 	&& cd build \
 	&& export CXXFLAGS="-fPIC" \
 	&& cmake .. \
 	&& make VERBOSE=1 \
 	&& make && make install \
	\
  && cd /root \
	&& git clone https://github.com/LMDB/lmdb && cd lmdb/libraries/liblmdb \
 	&& make && make install \
  \
  && cd /root \
  && git clone https://github.com/BVLC/caffe.git && cd caffe \
  && git reset --hard d8f79537977f9dbcc2b7054a9e95be00eb6f26d0 \
  && cp Makefile.config.example Makefile.config

RUN set -ex \
  && apt update && apt install -y python3 python3-dev python3-numpy python3-skimage-lib python3-pip python3-yaml \
  && cd /usr/lib/x86_64-linux-gnu/ && ln -s libboost_python-py35.so libboost_python3.so \
  && python3 -m pip install protobuf

RUN cd /root/caffe/ \
  && sed -i 's/^# CPU_ONLY := 1$/CPU_ONLY := 1/' Makefile.config \
  && sed -i '/^INCLUDE_DIRS/ s/$/ \/usr\/include\/hdf5\/serial\//' Makefile.config \
  && sed -i '/^LIBRARY_DIRS/ s/$/ \/usr\/lib\/x86_64-linux-gnu\/hdf5\/serial\//' Makefile.config \
  && sed -i 's%# PYTHON_LIBRARIES := boost_python3 python3.5m%PYTHON_LIBRARIES := boost_python3 python3.5m%g' Makefile.config \
  && sed -i 's%# PYTHON_INCLUDE := /usr/include/python3.5m \\%PYTHON_INCLUDE := /usr/include/python3.5m \\%g' Makefile.config \
  && sed -i 's%#                 /usr/lib/python3.5/dist-packages/numpy/core/include%                /usr/lib/python3.5/dist-packages/numpy/core/include%g' Makefile.config

RUN cd /root/caffe/ \
  && make -j all \
  && make -j test \
  && make -j runtest \
  && make -j distribute \
  && make pycaffe \
  # end caffe build
  \
  && cd /root \
  && echo 'SUBSYSTEM=="usb", ATTRS{idVendor}=="05c6", MODE="0660", GROUP="plugdev"' >> /etc/udev/rules.d

  ENV PYTHONPATH="${SNPE_ROOT}/lib/python:${SNPE_ROOT}/models/lenet/scripts:${SNPE_ROOT}/models/alexnet/scripts:${PYTHONPATH}" \
      CAFFE_HOME="/root/caffe" \
      PATH="/root/caffe/build/install/bin:/root/caffe/distribute/bin:${PATH}" \
      LD_LIBRARY_PATH="${SNPE_ROOT}/lib/x86_64-linux-clang:/root/caffe/build/install/lib:/root/caffe/distribute/lib:${LD_LIBRARY_PATH}"
  ENV PYTHONPATH="/root/caffe/build/install/python:/root/caffe/distribute/python:${PYTHONPATH}" \
      PATH="${SNPE_ROOT}/bin/x86_64-linux-clang:${PATH}"

RUN apt-get purge -y --auto-remove $buildDeps \
  && apt-get purge -y --auto-remove git wget zip \
  && rm -rf /tmp/*


CMD ["/bin/bash"]
