"""Unit tests for the Runner Class"""
import logging
import os
import pathlib
import shutil
import tempfile
import unittest

from unittest.mock import Mock

import adsbs
import menuconfig


EXPECTED_CONFIG = {'CONFIG_TEST': '1', 'CONFIG_BLAH': 'more'}


class adsbsTest(unittest.TestCase):
    """Tests for the adsbs.adsbs Class"""

    # noinspection PyUnusedLocal
    def _write_config(self, *args, **kwargs):
        with open(self.configfile, 'w') as f:
            print('Writing out config')
            f.write(self.sample_config)

    def setUp(self):
        """Before each test is run, set up some initial state."""
        self.tempdir = tempfile.TemporaryDirectory()
        self.homedir = self.tempdir.name
        self.statedir = '{}/.adsbs'.format(self.homedir)
        self.configfile = '{}/config'.format(self.statedir)
        os.environ['HOME'] = self.homedir
        os.environ['adsbs_LEGACY_CMD'] = 'true'
        self.althomedir = os.getcwd()
        self.altstatedir = '{}/.adsbs'.format(self.althomedir)
        self.mconfig = Mock(menuconfig)
        self.mconfig.menuconfig.side_effect = self._write_config
        self.sample_config = ('CONFIG_TEST=1\n'
                              '# CONFIG_BLEH is not set\n'
                              ' # Some other kind of comment\n'
                              'CONFIG_BLAH=more\n')

    def tearDown(self):
        """Clean up the state after each test."""
        self.tempdir.cleanup()
        if os.path.exists(self.altstatedir):
            assert self.altstatedir != os.getcwd()
            assert self.altstatedir != os.path.dirname(__file__)
            shutil.rmtree(self.altstatedir, ignore_errors=True)

    def test_statedir_when_HOME_is_set(self):
        """New instances of adsbs will have a property called statedir.
           Its value will be $HOME/.adsbs if $HOME is set.
           The config file will be [statedir]/config."""
        self.assertEqual(os.environ['HOME'], self.homedir)
        self.assertTrue(os.path.isdir(self.homedir))
        ads = adsbs.adsbs(mconfig=self.mconfig)
        self.assertEqual(self.statedir, ads.statedir)
        self.assertTrue(self.homedir in ads.statedir)
        self.assertEqual(self.configfile, ads.configfile)
        self.assertTrue(self.statedir in ads.configfile)

    def test_statedir_when_HOME_is_unset(self):
        """New instances of adsbs will use a statedir in CWD if HOME unset"""
        os.environ.pop('HOME', None)
        statedir = '{}/.adsbs'.format(self.althomedir)
        self.configfile = '{}/config'.format(statedir)
        ads = adsbs.adsbs(mconfig=self.mconfig)
        self.assertEqual(statedir, ads.statedir)
        self.assertEqual(self.configfile, ads.configfile)

    def test_statedir_exists(self):
        """New instances of adsbs will create a statedir if not present"""
        ads = adsbs.adsbs(mconfig=self.mconfig)
        self.assertTrue(os.path.isdir(ads.statedir))

    def test_statedir_failed_create(self):
        """Test that a adsbsException is raised on failed dir creation"""
        os.environ['HOME'] = '/dev/null'
        # noinspection PyTypeChecker
        with self.assertRaises((adsbs.adsbsException, SystemExit)):
            adsbs.adsbs(mconfig=self.mconfig)

    def test_config_is_set_correctly(self):
        """Test that the kconf file is set in the environment"""
        ads = adsbs.adsbs(mconfig=self.mconfig)
        self.assertEqual(self.configfile, os.getenv('KCONFIG_CONFIG'))
        self.assertEqual(ads.configfile, os.getenv('KCONFIG_CONFIG'))

    def test_menuconfig_is_run_when_no_config(self):
        """If a previous .adsbs/config file doesn't exist run menuconfig"""
        adsbs.adsbs(mconfig=self.mconfig)
        self.mconfig.menuconfig.assert_called()

    def test_menuconfig_is_not_run_when_config_exists(self):
        """If a previous .adsbs/config file does exist don't run menuconfig"""
        os.mkdir(self.statedir)
        pathlib.Path(self.configfile).touch()
        pathlib.Path('{}/ds'.format(self.statedir)).touch()
        mconfig = Mock(menuconfig)
        adsbs.adsbs(mconfig=mconfig)
        mconfig.menuconfig.assert_not_called()

    def test_exit_when_no_config_saved(self):
        """If no config, menuconfig is run and no config is saved, exit"""
        mconfig = Mock(menuconfig)
        # noinspection PyTypeChecker
        with self.assertRaises((adsbs.adsbsException, SystemExit)):
            adsbs.adsbs(mconfig=mconfig)
            mconfig.menuconfig.assert_called()

    def test_menuconfig_is_run_when_reconfigure_is_set(self):
        """If a reconfigure argument is passed, menuconfig is always run"""
        os.mkdir(self.statedir)
        pathlib.Path(self.configfile).touch()
        mconfig = Mock(menuconfig)
        adsbs.adsbs(mconfig=mconfig, reconf=True)
        mconfig.menuconfig.assert_called()

    def test_config_values_are_loaded(self):
        """Ensure the values from the config file are properly loaded"""
        ads = adsbs.adsbs(mconfig=self.mconfig)
        self.assertEqual(ads.config, EXPECTED_CONFIG)

    def test_main_help(self):
        """Execute the main function with the help flag."""
        # noinspection PyTypeChecker
        with self.assertRaises(SystemExit):
            adsbs.main(args=['-h'], mconfig=self.mconfig)

    def test_main_without_verbose(self):
        """Execute the main function without the verbose flag."""
        log = Mock(logging)
        adsbs.main(args=[], mconfig=self.mconfig, log=log)
        log.basicConfig.assert_called_with(
                format='%(asctime)s %(levelname)-6s %(message)s',
                level=logging.INFO)

    def test_main_verbose(self):
        """Execute the main function with the verbose flag."""
        log = Mock(logging)
        adsbs.main(args=['-v'], mconfig=self.mconfig, log=log)
        log.basicConfig.assert_called_with(
                format='%(asctime)s %(levelname)-6s %(message)s',
                level=logging.DEBUG)

    def test_main_reconfigure(self):
        """Execute the main function with the reconfigure flag."""
        os.mkdir(self.statedir)
        pathlib.Path(self.configfile).touch()
        mconfig = Mock(menuconfig)
        adsbs.main(args=['-r'], mconfig=mconfig)

    def test_main_version(self):
        """Supplying the version argument will simply print a version and
           exit."""
        # noinspection PyTypeChecker
        with self.assertRaises(SystemExit):
            adsbs.main(args=['-V'])
