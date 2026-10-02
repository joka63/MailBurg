# NixOS-Entwicklungsumgebung für MailBurg, klassischer Weg ohne Flakes.
#
# Aufruf aus dem Projektordner:
#
#     nix-shell
#     mailburg --hilfe
#     mailburg-gui
#     QT_QPA_PLATFORM=offscreen python3 -m unittest discover -s tests
#
# Deckt dieselben Extras aus pyproject.toml ab wie flake.nix (oberflaeche,
# imap, anhaenge, packen, verschluesselung, server) - PySide6 kommt fertig
# aus nixpkgs, nicht über pip, damit die Qt-Bibliotheken gleich mitkommen.
#
# Das Paket selbst wird nicht installiert; PYTHONPATH zeigt auf das Repo.
#
# Gemeinsame Definitionen (pythonEnv, Wrapper, Schemas, Library-Pfade)
# stehen in nix/devenv.nix.

{ pkgs ? import <nixpkgs> { } }:

let
  devenv = import ./nix/devenv.nix { inherit pkgs; };
in
pkgs.mkShell {
  name = "mailburg-devshell";
  packages = devenv.devPackages;
  LD_LIBRARY_PATH = devenv.ldLibraryPath;

  shellHook = ''
    export PYTHONPATH="$PWD:$PYTHONPATH"
    export GSETTINGS_SCHEMA_DIR="${devenv.gtkSchemas}"

    echo "MailBurg-Devshell: $(python3 --version), PySide6 aus nixpkgs."
    echo "  mailburg --hilfe"
    echo "  mailburg-gui"
    echo "  QT_QPA_PLATFORM=offscreen python3 -m unittest discover -s tests"
  '';
}
