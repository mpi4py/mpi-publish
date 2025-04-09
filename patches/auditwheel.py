#!/usr/bin/env python
import pathlib
import sys

import auditwheel.tools
from auditwheel.main import main

aw_walk = auditwheel.tools.walk

def walk(topdir):
    topdir = pathlib.Path(topdir).resolve(strict=True)
    for dirpath, dirnames, filenames in aw_walk(topdir):
        if (
            dirpath.suffix == ".dist-info"
            and dirpath.parent == topdir
        ):
            # list any dist-info/licenses/LICENSE* files
            for dirname in dirnames:
                for dn, _, fns in walk(dirpath / dirname):
                    for fn in fns:
                        fn = (dn / fn).relative_to(dirpath)
                        filenames.append(str(fn))
            del dirnames[:]
            # list any dist-info/RECORD file last
            if "RECORD" in filenames:
                filenames.remove("RECORD")
                filenames.append("RECORD")
        yield dirpath, dirnames, filenames

auditwheel.tools.walk = walk

if "repair" in sys.argv:
    sys.argv.append("--only-plat")

sys.exit(main())
