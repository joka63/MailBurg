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

{ pkgs ? import <nixpkgs> { } }:

let
  pythonEnv = pkgs.python3.withPackages (ps: with ps; [
    pyside6 # oberflaeche
    keyring # oberflaeche, imap
    pypdf # anhaenge
    zstandard # packen
    cryptography # server, verschluesselung
    starlette # server
    uvicorn # server

    pyflakes # Entwicklung, siehe TODO.md
  ]);

  # "mailburg" und "mailburg-gui" aus pyproject.toml ([project.scripts],
  # [project.gui-scripts]) entstehen normalerweise erst, wenn pip das
  # Paket installiert und dabei Wrapper-Skripte erzeugt. Ohne
  # "pip install" - und genau das ist hier Absicht, siehe Kommentar oben -
  # gibt es diese Befehle nicht von selbst. Diese beiden Wrapper
  # übernehmen exakt das, was die von pip erzeugten Skripte auch täten
  # (sys.exit(main())), nur ohne dafür das Paket zu installieren.
  # PYTHONPATH und LD_LIBRARY_PATH stehen bereits aus der Shell-Umgebung
  # (shellHook bzw. mkShell), deshalb genügt ein einfacher exec.
  mailburgCli = pkgs.writeShellScriptBin "mailburg" ''
    exec ${pythonEnv}/bin/python3 -m mailburg "$@"
  '';
  mailburgGui = pkgs.writeShellScriptBin "mailburg-gui" ''
    exec ${pythonEnv}/bin/python3 -m mailburg.ui.app "$@"
  '';
in
pkgs.mkShell {
  name = "mailburg-devshell";

  packages = [
    pythonEnv
    mailburgCli
    mailburgGui

    # pdftotext - schneller Rückfall vor pypdf, siehe pyproject.toml
    pkgs.poppler-utils
    # Texterkennung für gescannte Anhänge
    pkgs.tesseract
    # Schlüsselbund-Backend unter Linux, wie in install.sh
    pkgs.gnome-keyring
    pkgs.libsecret
  ];

  # PySide6 braucht zur Laufzeit u.a. libGL, xkbcommon und X11/Wayland-
  # Bibliotheken im Ladepfad, sonst scheitert der Fensterstart mit
  # "could not load the Qt platform plugin xcb", obwohl Qt korrekt
  # installiert ist.
  LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
    pkgs.libGL
    pkgs.libxkbcommon
    pkgs.fontconfig
    pkgs.freetype
    pkgs.libx11
    pkgs.libxcursor
    pkgs.libxrandr
    pkgs.libxi
    pkgs.zstd
  ];

  shellHook = ''
    export PYTHONPATH="$PWD:$PYTHONPATH"
    echo "MailBurg-Devshell: $(python3 --version), PySide6 aus nixpkgs."
    echo "  mailburg --hilfe"
    echo "  mailburg-gui"
    echo "  QT_QPA_PLATFORM=offscreen python3 -m unittest discover -s tests"
  '';
}
