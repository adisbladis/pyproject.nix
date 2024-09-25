# Usage

While the nixpkgs Python infrastructure is built mainly for manual packaging, `pyproject.nix`'s builders are mainly targeted at lock file consumers like [uv2nix](https://github.com/adisbladis/uv2nix).

This example shows the essence of implementing a lock file converter in pure Nix using `pyproject.nix`.
A real world implementation is more complex. To see a lock file converter built according to `pyproject.nix` best practices see [uv2nix](https://github.com/adisbladis/uv2nix).

## example.nix

```nix
{{#include ./minimal-lock.nix}}
```
