{
  callPackage,
  makeSetupHook,
  python,
  pkgs,
  lib,
  stdenv,
  hooks,
  resolveBuildSystem,
  pythonPkgsBuildHost,
}:
let
  inherit (python) pythonOnBuildForHost isPy3k;
  inherit (pkgs) buildPackages;
  pythonInterpreter = pythonOnBuildForHost.interpreter;
  pythonSitePackages = python.sitePackages;

in
{
  /*
    Undo any `$PYTHONPATH` changes done by nixpkgs Python infrastructure dependency propagation.

    Used internally by `pyprojectHook`.
  */
  pyprojectConfigureHook = callPackage (
    { python }:
    makeSetupHook {
      name = "pyproject-configure-hook";
      substitutions = {
        inherit pythonInterpreter;
        pythonPath = lib.concatStringsSep ":" (
          lib.optional (
            stdenv.buildPlatform != stdenv.hostPlatform
          ) "${python.pythonOnBuildForHost}/${python.sitePackages}"
          ++ [
            "${python}/${python.sitePackages}"
          ]
        );
      };
    } ./pyproject-configure-hook.sh
  ) { };

  /*
    Build a pyproject.toml/setuptools project.

    Used internally by `pyprojectHook`.
  */
  pyprojectBuildHook =
    callPackage
      (
        { uv }:
        makeSetupHook {
          name = "pyproject-build-hook";
          substitutions = {
            inherit pythonInterpreter uv;
          };
        } ./pyproject-build-hook.sh
      )
      {
        inherit (buildPackages) uv;
      };

  /*
    Build a pyproject.toml/setuptools project.

    Used internally by `pyprojectHook`.
  */
  pyprojectPypaBuildHook =
    callPackage
      (
        _:
        makeSetupHook {
          name = "pyproject-pypa-build-hook";
          substitutions = {
            inherit (pythonPkgsBuildHost) build;
            inherit pythonInterpreter;
          };
          propagatedBuildInputs = pythonPkgsBuildHost.resolveBuildSystem {
            build = [ ];
          };
        } ./pyproject-pypa-build-hook.sh
      )
      {
        inherit (buildPackages) python;
      };

  /*
    Symlink prebuilt wheel sources.

    Used internally by `pyprojectWheelHook`.
  */
  pyprojectWheelDistHook = callPackage (
    _:
    makeSetupHook {
      name = "pyproject-wheel-dist-hook";
    } ./pyproject-wheel-dist-hook.sh
  ) { };

  /*
    Install built projects from dist/*.whl.

    Used internally by `pyprojectHook`.
  */
  pyprojectInstallHook =
    callPackage
      (
        { uv }:
        makeSetupHook {
          name = "pyproject-install-hook";
          substitutions = {
            inherit pythonInterpreter uv;
          };
        } ./pyproject-install-hook.sh
      )
      {
        inherit (buildPackages) uv;
      };

  /*
    Install hook using pypa/installer.

    Used instead of `pyprojectInstallHook` for cross compilation support.
  */
  pyprojectPypaInstallHook = callPackage (
    { pythonPkgsBuildHost }:
    makeSetupHook {
      name = "pyproject-pypa-install-hook";
      substitutions = {
        inherit (pythonPkgsBuildHost) installer;
        inherit pythonInterpreter pythonSitePackages;
      };
    } ./pyproject-pypa-install-hook.sh
  ) { };

  /*
    Clean up any shipped bytecode in package output and recompile.

    Used internally by `pyprojectHook`.
  */
  pyprojectBytecodeHook = callPackage (
    _:
    makeSetupHook {
      name = "pyproject-bytecode-hook";
      substitutions = {
        inherit pythonInterpreter pythonSitePackages;
        compileArgs = lib.concatStringsSep " " (
          [
            "-q"
            "-f"
            "-i -"
          ]
          ++ lib.optionals isPy3k [ "-j $NIX_BUILD_CORES" ]
        );
        bytecodeName = if isPy3k then "__pycache__" else "*.pyc";
      };
    } ./pyproject-bytecode-hook.sh
  ) { };

  /*
    Create `pyproject.nix` setup hook in package output.

    Used internally by `pyprojectHook`.
  */
  pyprojectOutputSetupHook = callPackage (
    _:
    makeSetupHook {
      name = "pyproject-output-setup-hook";
      substitutions = {
        inherit pythonInterpreter pythonSitePackages;
      };
    } ./pyproject-output-setup-hook.sh
  ) { };

  /*
    Create a virtual environment from buildInputs

    Used internally by `mkVirtualEnv`.
  */
  pyprojectMakeVenvHook = callPackage (
    { python }:
    makeSetupHook {
      name = "pyproject-make-venv-hook";
      substitutions = {
        inherit pythonInterpreter python;
        makeVenvScript = ./make-venv.py;
      };
    } ./pyproject-make-venv-hook.sh
  ) { };

  /*
    Meta hook aggregating the default pyproject.toml/setup.py install behaviour and adds Python.

    This is the default choice for both pyproject.toml & setuptools projects.
  */
  #
  pyprojectHook =
    callPackage
      (
        {
          pyprojectConfigureHook,
          pyprojectBuildHook,
          pyprojectInstallHook,
          pyprojectBytecodeHook,
          pyprojectOutputSetupHook,
          python,
          stdenv,
        }:
        makeSetupHook {
          name = "pyproject-hook";
          passthru.python = python;
          propagatedBuildInputs = [
            python
            pyprojectConfigureHook
            pyprojectBuildHook
            pyprojectInstallHook
            pyprojectOutputSetupHook
          ] ++ lib.optional (stdenv.buildPlatform != stdenv.hostPlatform) pyprojectBytecodeHook;
        } ./meta-hook.sh
      )
      (
        {
          python = pythonOnBuildForHost;
        }
        // (lib.optionalAttrs (stdenv.buildPlatform != stdenv.hostPlatform) {
          # Uv is not yet compatible with cross installs, or at least I can't figure out the magic incantation.
          # We can use installer for cross, and still use uv for native.
          pyprojectBuildHook = hooks.pyprojectPypaBuildHook;
          pyprojectInstallHook = hooks.pyprojectPypaInstallHook;
        })
      );

  /*
    Hook used to build prebuilt wheels.

    Use instead of pyprojectHook.
  */
  pyprojectWheelHook = hooks.pyprojectHook.override {
    pyprojectBuildHook = hooks.pyprojectWheelDistHook;
  };
}
