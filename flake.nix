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
        devenv = import ./nix/devenv.nix { inherit pkgs; };
        mailburg = import ./nix/mailburg.nix {
          inherit pkgs;
          lib = pkgs.lib;
        };
      in
      {
        packages.default = mailburg;
        apps.default = {
          type = "app";
          program = "${mailburg}/bin/mailburg-gui";
        };

        devShells.default = pkgs.mkShell {
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
        };
      });
}
