#!/usr/bin/env python
import sys

from auditwheel.main import main

if "repair" in sys.argv:
    sys.argv.append("--only-plat")

sys.exit(main())
