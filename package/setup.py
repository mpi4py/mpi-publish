from setuptools import setup
from wheel.bdist_wheel import bdist_wheel
import re
import os


class bdist_wheel(bdist_wheel):

    def finalize_options(self):
        super().finalize_options()
        self.root_is_pure = False
        self.build_number = release or None

    def get_tag(self):
        plat_tag = super().get_tag()[-1]
        return (self.python_tag, "none", plat_tag)


mpiname = os.environ.get("MPINAME", "mpich")
release = os.environ.get("RELEASE", "")
pkgname = mpiname

if mpiname == "mpich":
    project = "MPICH"
    version_re = re.compile(r"""
    \#define\s+MPICH_VERSION\s+\"(.*)\"
    """, re.VERBOSE)
    license = "LicenseRef-MPICH"
    author = "MPICH Team"
    author_email = "discuss@mpich.org"
    project_urls = {
        "Homepage":      "https://www.mpich.org",
        "Downloads":     "https://www.mpich.org/downloads/",
        "Documentation": "https://www.mpich.org/documentation/guides/",
        "Source":        "https://github.com/pmodels/mpich",
        "Issues":        "https://github.com/pmodels/mpich/issues",
        "Discussions":   "https://github.com/pmodels/mpich/discussions",
    }

if mpiname == "openmpi":
    project = "Open MPI"
    version_re = re.compile(r"""
    \#define\s+OMPI_MAJOR_VERSION\s+(\d+)\n
    \#define\s+OMPI_MINOR_VERSION\s+(\d+)\n
    \#define\s+OMPI_RELEASE_VERSION\s+(\d+)\n
    """, re.VERBOSE)
    license = "LicenseRef-OpenMPI"
    author = "Open MPI Team"
    author_email = "users@lists.open-mpi.org"
    project_urls = {
        "Homepage":      "https://www.open-mpi.org",
        "Downloads":     "https://www.open-mpi.org/software/",
        "Documentation": "https://www.open-mpi.org/doc/",
        "Source":        "https://github.com/open-mpi/ompi",
        "Issues":        "https://github.com/open-mpi/ompi/issues",
        "Discussions":   "https://github.com/open-mpi/ompi/discussions",
    }

description = "A high performance implementation of MPI"
long_description = f"""`{project} <{project_urls["Homepage"]}>`_ is a
high-performance and widely portable implementation of the Message
Passing Interface (`MPI <https://www.mpi-forum.org/>`_) standard."""

prefix = os.environ.get("PREFIX", f"/opt/{mpiname}")
basedir = os.path.dirname(__file__)
destdir = os.environ.get("DESTDIR", f"{basedir}/install")
rootdir = f"{destdir}{prefix}"

with open(f"{rootdir}/include/mpi.h") as fobj:
    version = ".".join(version_re.search(fobj.read()).groups())

data_files = []
for path, dirs, files in os.walk(rootdir):
    dirs.sort()
    files.sort()
    subdir = os.path.relpath(path, rootdir)
    filelist = [os.path.join(path, f) for f in files]
    data_files.append((subdir, filelist))

cmdclass = {
    "bdist_wheel": bdist_wheel,
}

setup(
    name=pkgname,
    version=version,
    license=license,
    license_files=["LICENSE"],
    description=description,
    long_description=long_description,
    long_description_content_type="text/x-rst",
    author=author,
    author_email=author_email,
    maintainer="Lisandro Dalcin",
    maintainer_email="dalcinl@gmail.com",
    url=project_urls["Homepage"],
    project_urls=project_urls,
    packages=[],
    data_files=data_files,
    cmdclass=cmdclass,
)
