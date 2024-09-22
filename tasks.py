from invoke import task, context, Exit
import os
import subprocess
from colorama import *
import glob
from shutil import copy2, rmtree, copytree
from datetime import datetime
import pathlib
from typing import *

from pathlib import Path

os.chdir(Path(__file__).parent)

init()

DEFAULT_DELPHI_VERSION = "12"

g_new_version = ""

unit_test_project = r".\tests\templateprounittests.dproj"


def build_delphi_project(
    ctx: context.Context,
    project_filename,
    platform: str,
    config="DEBUG",
    delphi_version=DEFAULT_DELPHI_VERSION,
):
    delphi_versions = {
        "10": {"path": "17.0", "desc": "Delphi 10 Seattle"},
        "10.1": {"path": "18.0", "desc": "Delphi 10.1 Berlin"},
        "10.2": {"path": "19.0", "desc": "Delphi 10.2 Tokyo"},
        "10.3": {"path": "20.0", "desc": "Delphi 10.3 Rio"},
        "10.4": {"path": "21.0", "desc": "Delphi 10.4 Sydney"},
        "11": {"path": "22.0", "desc": "Delphi 11 Alexandria"},
        "12": {"path": "23.0", "desc": "Delphi 12 Athens"},
    }

    assert platform in (
        "Win32",
        "Win64",
    ), f"Invalid platform {platform}. Only Win32 and Win64 allowed."

    assert delphi_version in delphi_versions, (
        "Invalid Delphi version: " + delphi_version
    )
    printkv("COMPILER", "[" + delphi_versions[delphi_version]["desc"] + "]")
    version_path = delphi_versions[delphi_version]["path"]

    rsvars_path = (
        f"C:\\Program Files (x86)\\Embarcadero\\Studio\\{version_path}\\bin\\rsvars.bat"
    )
    if not os.path.isfile(rsvars_path):
        rsvars_path = f"D:\\Program Files (x86)\\Embarcadero\\Studio\\{version_path}\\bin\\rsvars.bat"
        if not os.path.isfile(rsvars_path):
            raise Exception("Cannot find rsvars.bat")
    cmdline = (
        '"'
        + rsvars_path
        + '"'
        + " & msbuild /t:Build /p:Config="
        + config
        + f' /p:Platform={platform} "'
        + project_filename
        + '"'
    )
    print("\n" + "".join(cmdline))
    r = ctx.run(cmdline, hide=True, warn=True)
    if r.failed:
        print(r.stdout)
        print(r.stderr)
        raise Exit("Build failed for " + delphi_versions[delphi_version]["desc"])


@task()
def tests(ctx):
    """Builds the broker and execute the unit tests"""
    import time

    printkv("ACTION", "Building Unit Test (Win32)")
    build_delphi_project(ctx, unit_test_project, platform="Win32", config="DEBUG")

    import subprocess

    printkv("ACTION", "Executing tests")
    with ctx.cd(r'.\tests\bin'):    
        try:
            ctx.run(r"templateprounittests.exe")
        except Exception as e:
            print(e)
            print("Unit Tests Failed")
            return Exit("Unit tests failed")


def printkv(key, value):
    print(
        Fore.RESET
        + Fore.YELLOW
        + key.ljust(20)
        + ": "
        + Fore.GREEN
        + value
        + Fore.RESET
    )


@task
def clean(ctx, folder=None):
    import os
    import glob

    print(f"Cleaning folder {folder}")
    output = pathlib.Path(folder)
    to_delete = []
    to_delete += glob.glob(folder + r"\**\*.exe", recursive=True)
    to_delete += glob.glob(folder + r"\**\*.dcu", recursive=True)
    to_delete += glob.glob(folder + r"\**\*.stat", recursive=True)
    to_delete += glob.glob(folder + r"\**\*.res", recursive=True)
    to_delete += glob.glob(folder + r"\**\*.map", recursive=True)
    to_delete += glob.glob(folder + r"\**\*.~*", recursive=True)
    to_delete += glob.glob(folder + r"\**\*.rsm", recursive=True)
    to_delete += glob.glob(folder + r"\**\*.drc", recursive=True)
    to_delete += glob.glob(folder + r"\**\*.log", recursive=True)
    to_delete += glob.glob(folder + r"\**\*.local", recursive=True)

    for f in to_delete:
        print(f"Deleting {f}")
        os.remove(f)
