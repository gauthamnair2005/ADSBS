import argparse
import logging
import io
import os
import re
import subprocess
import sys

from pkg_resources import get_distribution

import kconfiglib
import menuconfig

PKGDIR = os.path.dirname(__file__)
TOPDIR = os.path.dirname(PKGDIR)

with open('{}/git-version'.format(PKGDIR), 'r') as f:
    detail = f.read()

__version__ = '''adsbs version {version}
{detail}
  Copyright (C) 2023, the adsbs team:
    Jeremy Huntwork
    George Boudreau
    Manuel Canales Esparcia
    Thomas Pegg
    Matthew Burgess
    Pierre Labastie
'''.format(version=get_distribution('adsbs').version,
           detail=detail)


class adsbsException(Exception):
    """A simple exception that doesn't output a stack trace."""
    def __init__(self, message, return_code=1):
        super().__init__(message)
        logging.error('%s', message)
        sys.exit(return_code)


class adsbsStdio(list):
    """A class for temporarily capturing a std fd, like stdout.
       May be used as a context manager.

        Args:
            fd (string): The name of the std fd.
    """
    def __init__(self, fd):
        self._fd = fd
        super().__init__()

    def __enter__(self):
        self._stdfd = getattr(sys, self._fd)
        self._io = io.StringIO()
        setattr(sys, self._fd, self._io)
        return self

    def __exit__(self, *args):
        self.extend(self._io.getvalue().splitlines())
        del self._io
        setattr(sys, self._fd, self._stdfd)


class adsbs(object):
    def __init__(self, reconf=False, mconfig=menuconfig, log=logging):
        """The adsbs class.

            Args:
                reconf (bool): Whether or not to force menuconfig to run.
                mconfig: The menuconfig module. Allows dependency injection of
                         a mocked object for testing purposes.
                log: The logging module. Allows dependency injection of a
                     mocked object for testing purposes.
        """
        self.statedir = '{}/.adsbs'.format(
                os.environ.get('HOME', os.getcwd()))
        self.configfile = '{}/config'.format(self.statedir)
        os.environ['KCONFIG_CONFIG'] = self.configfile
        os.environ['MENUCONFIG_STYLE'] = 'selection=fg:white,bg:blue'
        self.kconf = kconfiglib.Kconfig('{}/Config.in'.format(PKGDIR))
        self.log = log
        self._legacy_cmd = os.getenv('adsbs_LEGACY_CMD', './adsbs.sh')

        if not os.path.isdir(self.statedir):
            try:
                os.mkdir(self.statedir)
            except Exception as e:
                raise adsbsException(e)

        if not os.path.exists(self.configfile) or reconf:
            with adsbsStdio('stdout') as out:
                mconfig.menuconfig(self.kconf)
            for line in out:
                log.info(line)

        try:
            self.config = {}
            pattern = re.compile(r'^CONFIG_[\w]+=.*')
            with open(self.configfile, 'r') as f:
                for line in f:
                    line = line.strip()
                    if pattern.fullmatch(line):
                        key, value = line.split('=', 1)
                        self.config[key] = value
        except FileNotFoundError:
            raise adsbsException('No configuration file found.')

        with open('{}/configuration'.format(self.statedir), 'w') as legacy_cnf:
            subprocess.run(['sed', 's@CONFIG_@@', self.configfile],
                           stdout=legacy_cnf)
        for item in ['adsbs.sh', 'ds', 'Bds', 'Cds', 'Cds2', 'Cds3',
                     'common', 'extras', 'git-version']:
            src = '{}/{}'.format(PKGDIR, item)
            dst = '{}/{}'.format(self.statedir, item)
            if not os.path.exists(dst):
                os.symlink(src, dst)

        for item in ['optimize', 'pkgmngt', 'custom']:
            src = '{}/{}'.format(TOPDIR, item)
            dst = '{}/{}'.format(self.statedir, item)
            if not os.path.exists(dst):
                os.symlink(src, dst)

    def run(self):
        subprocess.run([self._legacy_cmd, 'run'],
                       cwd=self.statedir, env=os.environ)


def main(args=sys.argv[1:], mconfig=menuconfig, log=logging):
    mainparser = argparse.ArgumentParser(
        description='Automate the building of Linux From Scratch')
    mainparser.add_argument(
        '-r', '--reconfigure',
        action='store_true',
        help='Force menuconfig to run even if a config file already exists.')
    mainparser.add_argument(
        '-v', '--verbose',
        action='store_true')
    mainparser.add_argument(
        '-V', '--version',
        action='store_true')
    parser = mainparser.parse_args(args)

    if parser.version:
        print(__version__)
        sys.exit(0)

    if parser.verbose:
        loglevel = logging.DEBUG
    else:
        loglevel = logging.INFO

    log.basicConfig(
        level=loglevel,
        format='%(asctime)s %(levelname)-6s %(message)s')

    ads = adsbs(reconf=parser.reconfigure, mconfig=mconfig, log=log)
    ads.run()
