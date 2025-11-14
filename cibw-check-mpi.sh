#!/bin/bash
set -euo pipefail

if command -v mpichversion > /dev/null; then
    mpiname=mpich
    version=$(mpichversion --version | cut -d':' -f 2)
elif command -v ompi_info > /dev/null; then
    mpiname=openmpi
    version=$(ompi_info --version | head -n 1 | cut -d'v' -f 2)
fi

tempdir="$(mktemp -d)"
trap 'rm -rf $tempdir' EXIT
cd "$tempdir"

cat > helloworld.c << EOF
#include <mpi.h>
#include <stdio.h>

int main(int argc, char *argv[])
{
  int size, rank, len;
  char name[MPI_MAX_PROCESSOR_NAME];

  MPI_Init(&argc, &argv);
  MPI_Comm_size(MPI_COMM_WORLD, &size);
  MPI_Comm_rank(MPI_COMM_WORLD, &rank);
  MPI_Get_processor_name(name, &len);
  if (rank != 0)
    MPI_Recv(name, 0 , MPI_BYTE, rank-1, 0, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
  printf("Hello, World! I am process %d of %d on %s.\n", rank, size, name);
  if (rank != size - 1)
    MPI_Send(name, 0 , MPI_BYTE, rank+1, 0, MPI_COMM_WORLD);
  MPI_Finalize();
  return 0;
}
EOF
ln -s helloworld.c helloworld.cxx

if test "$mpiname" = "openmpi"; then
    export OMPI_ALLOW_RUN_AS_ROOT=1
    export OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1
    export OMPI_MCA_btl=tcp,self
    export OMPI_MCA_plm_rsh_agent=false
    export OMPI_MCA_plm_ssh_agent=false
    export OMPI_MCA_mpi_yield_when_idle=true
    export OMPI_MCA_rmaps_base_oversubscribe=true
    export OMPI_MCA_rmaps_default_mapping_policy=:oversubscribe
    export PRTE_MCA_rmaps_default_mapping_policy=:oversubscribe
    if test "${version%%.*}" -lt 4 -a "$(id -u)" -eq 0; then
        mpiexec() { set -- command mpiexec --allow-run-as-root "$@"; "$@"; }
    fi
fi

export MPIEXEC_TIMEOUT=60

RUN() { echo + "$@"; "$@"; }

if test "$mpiname" = "mpich"; then
    RUN command -v mpichversion
    RUN mpichversion
fi

if test "$mpiname" = "mpich" && test "${version%%.*}" -ge 4; then
    RUN command -v mpivars
    RUN mpivars -nodesc | grep 'Category .* has'
fi

if test "$mpiname" = "openmpi"; then
    RUN command -v ompi_info
    RUN ompi_info
    if command -v pmix_info > /dev/null; then
        RUN command -v pmix_info
        RUN pmix_info
    fi
    if command -v prte_info > /dev/null; then
        RUN command -v prte_info
        RUN prte_info
    fi
fi

RUN command -v mpicc
RUN mpicc -show
RUN mpicc helloworld.c -o helloworld-c

RUN command -v mpicxx
RUN mpicxx -show
RUN mpicxx helloworld.cxx -o helloworld-cxx

RUN command -v mpiexec
RUN mpiexec -help
RUN mpiexec -n 3 ./helloworld-c
RUN mpiexec -n 3 ./helloworld-cxx

if test "$mpiname-$(uname)" = "mpich-Linux" && test "${version%%.*}" -ge 4; then
    export MPICH_CH4_UCX_CAPABILITY_DEBUG=1
    export MPICH_CH4_OFI_CAPABILITY_DEBUG=1
    for netmod in ucx ofi; do
        printf "testing %s ... " "$netmod"
        export MPICH_CH4_NETMOD="$netmod"
        mpiexec -n 1 ./helloworld-c | grep -i "$netmod" > /dev/null
        for nonlocal in 0 1; do
            export MPICH_NOLOCAL=$nonlocal
            for n in $(seq 1 4); do
                mpiexec -n "$n" ./helloworld-c > /dev/null
            done
        done
        printf "OK\n"
    done
    unset MPICH_CH4_UCX_CAPABILITY_DEBUG
    unset MPICH_CH4_OFI_CAPABILITY_DEBUG
    unset MPICH_CH4_NETMOD
    unset MPICH_NOLOCAL
fi

if test "$mpiname-$(uname)" = "openmpi-Linux"; then
    for backend in ofi ucx; do
        printf "testing %s ... " "$backend"
        if test "$backend" = "ucx"; then
            export OMPI_MCA_pml=ucx
            export OMPI_MCA_osc=ucx
            export OMPI_MCA_btl=^vader,tcp,openib,uct
            export OMPI_MCA_opal_common_ucx_tls=tcp
            export OMPI_MCA_opal_common_ucx_devices=lo
            export OMPI_MCA_opal_common_ucx_verbose=1
            check='mca_pml_ucx_init'
        fi
        if test "$backend" = "ofi"; then
            export OMPI_MCA_pml=cm
            export OMPI_MCA_mtl=ofi
            export OMPI_MCA_opal_common_ofi_provider_include=tcp
            export OMPI_MCA_opal_common_ofi_verbose=1
            check='mtl:ofi:prov.*: tcp'
        fi
        mpiexec -n 1 ./helloworld-c 2>&1 | grep -i "$check" > /dev/null
        for n in $(seq 1 4); do
            mpiexec -n "$n" ./helloworld-c > /dev/null 2>&1
        done
        unset OMPI_MCA_pml
        unset OMPI_MCA_osc
        unset OMPI_MCA_mtl
        unset OMPI_MCA_btl
        unset OMPI_MCA_opal_common_ucx_tls
        unset OMPI_MCA_opal_common_ucx_devices
        unset OMPI_MCA_opal_common_ucx_verbose
        unset OMPI_MCA_opal_common_ofi_provider_include
        unset OMPI_MCA_opal_common_ofi_verbose
        printf "OK\n"
    done
fi
