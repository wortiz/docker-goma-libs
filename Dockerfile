# Build stage with Spack pre-installed and ready to be used
FROM spack/ubuntu-jammy:develop as builder

# What we want to install and how we want to install it
# is specified in a manifest file (spack.yaml)
RUN mkdir -p /opt/spack-environment && \
set -o noclobber \
&&  (echo spack: \
&&   echo '  specs:' \
&&   echo '  - cmake' \
&&   echo '  - sparse' \
&&   echo '  - catch2' \
&&   echo '  - openmpi@4.1.6' \
&&   echo '  - arpack-ng' \
&&   echo '  - metis~int64' \
&&   echo '  - parmetis~int64' \
&&   echo '  - hypre~int64' \
&&   echo '  - strumpack+scotch~openmp~slate' \
&&   echo '  - mumps~openmp+metis+parmetis' \
&&   echo '  - trilinos@15.1.1+amesos+amesos2+aztec+belos+boost~chaco+epetra+epetraext~exodus+explicit_template_instantiation+fortran+hdf5~hypre+ifpack+ml+mpi+muelu+mumps+shared+stratimikos+suite-sparse+superlu-dist+teko+tpetra+piro+nox+tempus+shards+intrepid2+zoltan2+sacado+intrepid+isorropia+strumpack   build_type=Release' \
&&   echo '    gotype=long_long' \
&&   echo '  - omega-h build_type=Release' \
&&   echo '  - petsc~X~batch~cgns~complex~cuda~debug+double~exodusii~fftw~giflib+hdf5~hwloc+hypre~int64~jpeg~knl~libpng~libyaml~memkind+metis~mkl-pardiso~moab~mpfr+mpi+mumps~openmp~p4est+ptscotch~random123~rocm~saws+shared~suite-sparse~superlu-dist~trilinos+strumpack' \
&&   echo '  - seacas' \
&&   echo '  concretizer:' \
&&   echo '    unify: true' \
&&   echo '  packages:' \
&&   echo '    all:' \
&&   echo '      target:' \
&&   echo '      - x86_64_v3' \
&&   echo '      providers:' \
&&   echo '        mpi: [openmpi]' \
&&   echo '  config:' \
&&   echo '    install_tree: /opt/software' \
&&   echo '  view: /opt/views/view') > /opt/spack-environment/spack.yaml

# Install the software, remove unnecessary deps
RUN cd /opt/spack-environment && spack env activate . && spack install --fail-fast

# Install the software, remove unnecessary deps
RUN mkdir -p /opt/spack-complex-environment && \
set -o noclobber \
&&  (echo spack: \
&&   echo '  specs:' \
&&   echo '  - cmake' \
&&   echo '  - sparse' \
&&   echo '  - catch2' \
&&   echo '  - openmpi@4.1.6' \
&&   echo '  - arpack-ng' \
&&   echo '  - metis~int64' \
&&   echo '  - parmetis~int64' \
&&   echo '  - hypre~int64' \
&&   echo '  - strumpack+scotch~openmp~slate' \
&&   echo '  - mumps~openmp+metis+parmetis' \
&&   echo '  - trilinos@15.1.1+amesos+amesos2+aztec+belos+boost~chaco+epetra+epetraext~exodus+explicit_template_instantiation+fortran+hdf5~hypre+ifpack+ml+mpi+muelu+mumps+shared+stratimikos+suite-sparse+superlu-dist+teko+tpetra+piro+nox+tempus+shards+intrepid2+zoltan2+sacado+intrepid+isorropia+strumpack   build_type=Release' \
&&   echo '    gotype=long_long' \
&&   echo '  - omega-h build_type=Release' \
&&   echo '  - petsc~X~batch~cgns+complex~cuda~debug+double~exodusii~fftw~giflib+hdf5~hwloc+hypre~int64~jpeg~knl~libpng~libyaml~memkind+metis~mkl-pardiso~moab~mpfr+mpi+mumps~openmp~p4est+ptscotch~random123~rocm~saws+shared~suite-sparse~superlu-dist~trilinos+strumpack' \
&&   echo '  - seacas' \
&&   echo '  concretizer:' \
&&   echo '    unify: true' \
&&   echo '  packages:' \
&&   echo '    all:' \
&&   echo '      target:' \
&&   echo '      - x86_64_v3' \
&&   echo '      providers:' \
&&   echo '        mpi: [openmpi]' \
&&   echo '  config:' \
&&   echo '    install_tree: /opt/software' \
&&   echo '  view: /opt/views/view-complex') > /opt/spack-complex-environment/spack.yaml
RUN cd /opt/spack-complex-environment && spack env activate . && spack install --fail-fast && spack gc -y

# This doesn't work, missing indices
# Strip all the binaries
#RUN find -L /opt/views/view/* -type f -exec readlink -f '{}' \; | \
#    xargs file -i | \
#    grep 'charset=binary' | \
#    grep 'x-executable\|x-archive\|x-sharedlib' | \
#    awk -F: '{print $1}' | xargs strip
#
#RUN find -L /opt/views/view-complex/* -type f -exec readlink -f '{}' \; | \
#    xargs file -i | \
#    grep 'charset=binary' | \
#    grep 'x-executable\|x-archive\|x-sharedlib' | \
#    awk -F: '{print $1}' | xargs strip


# Modifications to the environment that are necessary to run
RUN cd /opt/spack-environment && \
    spack env activate --sh -d . > activate.sh

RUN cd /opt/spack-complex-environment && \
    spack env activate --sh -d . > activate.sh

# Bare OS image to run the installed executables
FROM ubuntu:22.04

COPY --from=builder /opt/spack-environment /opt/spack-environment
COPY --from=builder /opt/software /opt/software

# paths.view is a symlink, so copy the parent to avoid dereferencing and duplicating it
COPY --from=builder /opt/views /opt/views

RUN apt update
RUN apt install -y git build-essential m4 zlib1g-dev libx11-dev gfortran pkg-config autoconf python3-dev vim tmux nano gdb valgrind
RUN apt autoremove && apt clean
   

RUN { \
      echo '#!/bin/sh' \
      && echo '.' /opt/spack-environment/activate.sh \
      && echo 'exec "$@"'; \
    } > /entrypoint.sh \
&& chmod a+x /entrypoint.sh \
&& ln -s /opt/views/view /opt/view

#RUN adduser --disabled-password --gecos '' $USER
#RUN adduser $USER sudo; echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
#
#RUN chown -R $USER:$USER /home/$USER
#USER $USER
#ENV HOME /home/$USER
#ENV USER $USER
#ENV OMPI_MCA_btl "^vader"
ENV OMPI_MCA_btl_base_warn_component_unuse "0"
ENV OMPI_ALLOW_RUN_AS_ROOT 1
ENV OMPI_ALLOW_RUN_AS_ROOT_CONFIRM 1
ENV SPACK_ENV=/opt/spack-environment;
ENV SPACK_ENV_VIEW=default;
ENV ACLOCAL_PATH=/opt/views/view/share/aclocal;
ENV BOOST_ROOT=/opt/views/view;
ENV CMAKE_PREFIX_PATH=/opt/views/view;
ENV HDF5_PLUGIN_PATH=/opt/views/view/plugins;
ENV LD_LIBRARY_PATH=/opt/views/view/lib;
ENV MANPATH=/opt/views/view/share/man:/opt/views/view/man:/usr/share/man:;
ENV MPICC=/opt/views/view/bin/mpicc;
ENV MPICXX=/opt/views/view/bin/mpic++;
ENV MPIF77=/opt/views/view/bin/mpif77;
ENV MPIF90=/opt/views/view/bin/mpif90;
ENV MPIFC=/opt/views/view/bin/mpifort;
ENV PATH=/opt/views/view/bin:/opt/spack/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin;
ENV PETSC_ARCH="";
ENV PETSC_DIR=/opt/views/view;
ENV PKG_CONFIG_PATH=/opt/views/view/lib/pkgconfig:/opt/views/view/share/pkgconfig:/opt/views/view/lib64/pkgconfig;
ENV PYTHONPATH=/opt/views/view/lib:/opt/views/view/lib/python3.11/site-packages;
ENV XLOCALEDIR=/opt/views/view/share/X11/locale;

ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "/bin/bash" ]
