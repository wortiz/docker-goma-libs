FROM ubuntu:20.04 as bootstrap

ENV SPACK_ROOT=/opt/spack \
    CURRENTLY_BUILDING_DOCKER_IMAGE=1 \
    container=docker

ENV DEBIAN_FRONTEND=noninteractive   \
    LANGUAGE=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

RUN apt-get -yqq update \
 && apt-get -yqq install --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
        file \
        g++ \
        gcc \
        gfortran \
        git \
        gnupg2 \
        iproute2 \
        locales \
        lua-posix \
        make \
        python3 \
        python3-pip \
        python3-setuptools \
        unzip \
 && locale-gen en_US.UTF-8 \
 && pip3 install boto3 \
 && rm -rf /var/lib/apt/lists/*

RUN mkdir $SPACK_ROOT && cd $SPACK_ROOT && \
    git clone https://github.com/spack/spack.git . && git checkout e7894b4863b02cbb0bc2f905cad04908b045368f  && \
    mkdir -p $SPACK_ROOT/opt/spack

RUN ln -s $SPACK_ROOT/share/spack/docker/entrypoint.bash \
          /usr/local/bin/docker-shell \
 && ln -s $SPACK_ROOT/share/spack/docker/entrypoint.bash \
          /usr/local/bin/interactive-shell \
 && ln -s $SPACK_ROOT/share/spack/docker/entrypoint.bash \
          /usr/local/bin/spack-env

RUN mkdir -p /root/.spack \
 && cp $SPACK_ROOT/share/spack/docker/modules.yaml \
        /root/.spack/modules.yaml \
 && rm -rf /root/*.* /run/nologin $SPACK_ROOT/.git

# [WORKAROUND]
# https://superuser.com/questions/1241548/
#     xubuntu-16-04-ttyname-failed-inappropriate-ioctl-for-device#1253889
RUN [ -f ~/.profile ]                                               \
 && sed -i 's/mesg n/( tty -s \\&\\& mesg n || true )/g' ~/.profile \
 || true


WORKDIR /root
SHELL ["docker-shell"]

# Creates the package cache
RUN spack spec hdf5+mpi

ENTRYPOINT ["/bin/bash", "/opt/spack/share/spack/docker/entrypoint.bash"]
CMD ["interactive-shell"]

# Build stage with Spack pre-installed and ready to be used
FROM bootstrap as builder


# What we want to install and how we want to install it
# is specified in a manifest file (spack.yaml)
RUN mkdir /opt/spack-environment \
&&  (echo "spack:" \
&&   echo "  specs:" \
&&   echo "  - cmake" \
&&   echo "  - sparse" \
&&   echo "  - catch2" \
&&   echo "  - openmpi" \
&&   echo "  - arpack-ng" \
&&   echo "  - metis~int64" \
&&   echo "  - parmetis~int64" \
&&   echo "  - hypre~int64" \
&&   echo "  - mumps~openmp+metis+parmetis" \
&&   echo "  - trilinos+amesos+amesos2+aztec+belos+boost~chaco+epetra+epetraext~exodus+explicit_template_instantiation+fortran+hdf5~hypre+ifpack+ifpack2+kokkos+ml+mpi+muelu+mumps+shared+stratimikos+suite-sparse+superlu-dist+teko+tpetra+zoltan+zoltan2 build_type=Release gotype=long_long" \
&&   echo "  - omega-h build_type=Release" \
&&   echo "  - petsc~X~batch~cgns~complex~cuda~debug+double~exodusii~fftw~giflib+hdf5~hwloc+hypre~int64~jpeg~knl~libpng~libyaml~memkind+metis~mkl-pardiso~moab~mpfr+mpi+mumps~openmp+p4est+ptscotch~random123~rocm~saws+shared+suite-sparse~superlu-dist+trilinos" \
&&   echo "  - seacas" \
&&   echo "  view: /opt/view" \
&&   echo "  concretization: together" \
&&   echo "  packages:" \
&&   echo "    all:" \
&&   echo "      target:" \
&&   echo "      - x86_64_v2" \
&&   echo "      providers:" \
&&   echo "        blas:" \
&&   echo "        - netlib-lapack" \
&&   echo "        lapack:" \
&&   echo "        - netlib-lapack" \
&&   echo "  config:" \
&&   echo "    install_tree: /opt/software") > /opt/spack-environment/spack.yaml

# Install the software, remove unnecessary deps
RUN cd /opt/spack-environment && \
    spack env activate . && \
    spack install --fail-fast && \
    spack gc -y

# Modifications to the environment that are necessary to run
RUN cd /opt/spack-environment && \
    spack env activate --sh -d . >> /etc/profile.d/z10_spack_environment.sh

# Bare OS image to run the installed executables
FROM ubuntu:20.04


COPY --from=builder /opt/spack-environment /opt/spack-environment
COPY --from=builder /opt/software /opt/software
COPY --from=builder /opt/view /opt/view
COPY --from=builder /etc/profile.d/z10_spack_environment.sh /etc/profile.d/z10_spack_environment.sh

RUN apt-get clean && apt-get update && apt-get install -y locales
RUN locale-gen en_US.UTF-8  
ENV LANG en_US.UTF-8  
ENV LANGUAGE en_US:en  
ENV LC_ALL en_US.UTF-8

RUN apt-get -yqq update \
 && apt-get -yqq install --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
        file \
        g++ \
        gcc \
        gfortran \
        git \
        gnupg2 \
        iproute2 \
        locales \
        lua-posix \
        make \
        python3 \
        python3-pip \
        python3-setuptools \
        unzip 
RUN apt-get -yqq update && apt-get -yqq upgrade \
 && apt-get -yqq install \
    bash git build-essential m4 zlib1g-dev libx11-dev gfortran locales wget coreutils curl sudo
RUN apt-get autoremove -y
RUN apt-get clean
RUN rm -rf /var/lib/apt/lists/*
RUN mkdir /opt/workdir


# user setup
#ARG USER=goma
#RUN adduser --disabled-password --gecos '' $USER
#RUN adduser $USER sudo; echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
#
#RUN chown -R $USER:$USER /home/$USER
#USER $USER
#ENV HOME /home/$USER
#ENV USER $USER
#ENV OMPI_MCA_btl "^vader"
ENV OMPI_MCA_btl_base_warn_component_unuse "0"
ENV PATH "/opt/view/bin:${PATH}"
ENV LD_LIBRARY_PATH "/opt/view/lib:${LD_LIBRARY_PATH}"
ENV CMAKE_PREFIX_PATH "/opt/view/lib:${CMAKE_PREFIX_PATH}"
ENV OMPI_ALLOW_RUN_AS_ROOT 1
ENV OMPI_ALLOW_RUN_AS_ROOT_CONFIRM 1

# use /home/goma as goma root
WORKDIR /opt/workdir

#ENTRYPOINT ["/bin/bash", "--rcfile", "/etc/profile", "-l"]
