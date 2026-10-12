# Builds the same small library as tests/cmake, through SdkHelpers.ambuild:
#
#   mkdir build && cd build
#   python3 ../tests/ambuild/configure.py --sdk cs2 --s2sdk /path/to/s2sdk
#   ambuild
import sys
from ambuild2 import run

parser = run.BuildParser(sourcePath = sys.path[0], api='2.2')
parser.options.add_argument('--sdk', type=str, dest='sdk', default='cs2',
                        help='The game of the s2sdk checkout')
parser.options.add_argument('--s2sdk', type=str, dest='s2sdk', default=None,
                        help='The s2sdk checkout (default: the manifest\'s environment variables)')
parser.Configure()
