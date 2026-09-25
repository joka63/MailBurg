{
  # NixOS-Entwicklungsumgebung für MailBurg.
  #
  # `nix develop` reicht: Python mit allen Extras aus pyproject.toml
  # (oberflaeche, imap, anhaenge, packen, verschluesselung, server) kommt
  # fertig aus nixpkgs statt über pip - PySide6 bringt seine Qt-Bibliotheken
  # damit gleich mit, kein manuelles LD_LIBRARY_PATH nötig.
  #
  # Das Paket selbst wird NICHT über pip installiert (kein "pip install -e
  # .") - Nix stellt nur die Abhängigkeiten bereit. Im Projektordner läuft
  # es trotzdem, weil PYTHONPATH auf das Repo zeigt:
  #
  #     nix develop
  #     mailburg --hilfe
  #     mailburg-gui
  #     python3 -m unittest discover -s tests
  #
  # Ohne Flakes (klassisch): siehe shell.nix daneben.

  description = "Entwicklungsumgebung für MailBurg (mit PySide6-Oberfläche)";

  inputs = {
    # An den Kanal der Zielsysteme gebunden, nicht an unstable: Wer schon
    # nixos-26.05 systemweit installiert hat, hat die meisten Store-Pfade
    # (PySide6, Qt, glibc, ...) bereits im lokalen Cache. Mit unstable
    # holte sich "nix develop" einen zweiten, meist abweichenden Satz
    # derselben Pakete - unnötiger Download, und zwei leicht verschiedene
    # PySide6-Fassungen im Umlauf.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        pythonEnv = pkgs.python3.withPackages (ps: with ps; [
          # oberflaeche
          pyside6
          keyring
          # imap (keyring bereits oben)
          # anhaenge
          pypdf
          # packen
          zstandard
          # server / verschluesselung
          cryptography
          starlette
          uvicorn

          # zum Entwickeln/Testen, nicht in pyproject.toml als Laufzeit-
          # Abhängigkeit gelistet, aber hier praktisch
          pyflakes
        ]);

        # "mailburg" und "mailburg-gui" aus pyproject.toml ([project.scripts],
        # [project.gui-scripts]) entstehen normalerweise erst, wenn pip das
        # Paket installiert und dabei Wrapper-Skripte erzeugt. Ohne
        # "pip install" - und genau das ist hier Absicht, siehe Kommentar
        # oben - gibt es diese Befehle nicht von selbst. Diese beiden
        # Wrapper übernehmen exakt das, was die von pip erzeugten Skripte
        # auch täten (sys.exit(main())), nur ohne dafür das Paket zu
        # installieren. PYTHONPATH und LD_LIBRARY_PATH stehen bereits aus
        # der Shell-Umgebung (shellHook bzw. mkShell), deshalb genügt ein
        # einfacher exec.
        mailburgCli = pkgs.writeShellScriptBin "mailburg" ''
          exec ${pythonEnv}/bin/python3 -m mailburg "$@"
        '';
        mailburgGui = pkgs.writeShellScriptBin "mailburg-gui" ''
          exec ${pythonEnv}/bin/python3 -m mailburg.ui.app "$@"
        '';
      in
      {
        devShells.default = pkgs.mkShell {
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

          # PySide6 braucht zur Laufzeit u.a. libGL, xkbcommon, X11/Wayland-
          # Bibliotheken. Qt selbst bringt die passenden Plugins mit, aber
          # ein paar Systembibliotheken müssen im Ladepfad stehen, sonst
          # scheitert der Fensterstart mit "could not load the Qt platform
          # plugin xcb", obwohl Qt korrekt installiert ist.
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
        };
      });
}
