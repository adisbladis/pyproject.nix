{ pkgs, ... }: {
  # Used to find the project root
  projectRootFile = "flake.lock";

  programs.prettier.enable = true;

  programs.shellcheck.enable = true;

  settings.formatter = {
    nix = {
      command = "sh";
      options = [
        "-eucx"
        ''
          ${pkgs.lib.getExe pkgs.deadnix} --edit "$@"

          for i in "$@"; do
            ${pkgs.lib.getExe pkgs.statix} fix "$i"
          done

          ${pkgs.lib.getExe pkgs.nixpkgs-fmt} "$@"
        ''
        "--"
      ];
      includes = [ "*.nix" ];
      excludes = [ ];
    };

    prettier = {
      excludes = [ "highlight.js" ];
    };

    python = {
      command = "sh";
      options = [
        "-eucx"
        ''
          ${pkgs.lib.getExe pkgs.python3.pkgs.black} "$@"
          ${pkgs.lib.getExe pkgs.ruff} --fix "$@"
        ''
        "--" # this argument is ignored by bash
      ];
      includes = [ "*.py" ];
    };
  };
}
