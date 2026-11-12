import os
import re
import shutil
import subprocess as sp
import sys
from pathlib import Path

prefix = Path(sys.argv[1])
incdir = prefix / "include"
libdir = prefix / "lib"
libmpi = next(libdir.glob("libmpi.so.*"))
libopenmpi = next(libdir.glob("libopen_mpi.so.*"))

identifier_re = re.compile(r"\b(?:P?MPIX?|ompi)_\w+\b")
identifiers = set()
for dirpath, _, filenames in os.walk(incdir):
    headers = [f for f in filenames if f.endswith(".h")]
    for filename in headers:
        fpath = Path(dirpath) / filename
        with fpath.open(encoding="utf-8") as fobj:
            for line in fobj:
                for idn in identifier_re.findall(line):
                    identifiers.add(idn)

objects = []
functions = []
for binary in [libmpi, libopenmpi]:
    output = sp.check_output(  # noqa: S603
        [shutil.which("nm"), "-DP", binary],
        text=True,
    )
    for line in output.splitlines():
        data = line.split()
        name, kind = data[:2]
        if name not in identifiers or kind == "U":
            pass
        elif kind in "TW":
            weak = kind == "W"
            functions.append((name, weak))
        elif kind in "BDRV":
            weak = kind == "V"
            addr = int(data[-2], 16)
            size = int(data[-1], 16)
            assert not addr % 8  # noqa: S101
            assert not size % 8  # noqa: S101
            objects.append((name, weak, size))
        else:
            raise AssertionError(line)

preamble = """/* generated */
#define WEAK __attribute__((weak))
#define EXTERN extern
#define EXPORT __attribute__((visibility("default")))
#define CODE(sym) void sym(void)
#define DATA(s,n) void *s[n/sizeof(void*)]
#define W(sym) WEAK F(sym)
#define V(s,n) WEAK O(s,n)
#define F(sym) EXTERN EXPORT CODE(sym); CODE(sym){}
#define O(s,n) EXTERN EXPORT DATA(s,n); DATA(s,n);
"""
content = [preamble]
for name, weak in functions:
    macro = "W" if weak else "F"
    content.append(f"{macro}({name})")
for name, weak, size in objects:
    macro = "V" if weak else "O"
    content.append(f"{macro}({name},{size})")

for code in content:
    print(code)  # noqa: T201
