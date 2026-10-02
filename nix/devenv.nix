# Gemeinsame Entwicklungsumgebung für shell.nix (klassisch) und flake.nix.
#
# Definiert pythonEnv, Wrapper-Skripte, GSettings-Schemas und
# Library-Pfade — einmal, zur Verwendung in beiden Dateien.

{ pkgs }:

let
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
  # "pip install" - und genau das ist hier Absicht - gibt es diese
  # Befehle nicht von selbst. Diese beiden Wrapper übernehmen exakt das,
  # was die von pip erzeugten Skripte auch täten (sys.exit(main())), nur
  # ohne dafür das Paket zu installieren. PYTHONPATH und LD_LIBRARY_PATH
  # stehen bereits aus der Shell-Umgebung (shellHook bzw. mkShell),
  # deshalb genügt ein einfacher exec.
  mailburgCli = pkgs.writeShellScriptBin "mailburg" ''
    exec ${pythonEnv}/bin/python3 -m mailburg "$@"
  '';

  mailburgGui = pkgs.writeShellScriptBin "mailburg-gui" ''
    # Qt sucht beim Portal nach der .desktop Datei; im Store liegt sie unter
    # /nix/store/.../share/applications/. Damit das Portal sie findet, muss
    # XDG_DATA_DIRS mitgesetzt werden - sonst erscheint die Warnung
    # "Could not register app ID: App info not found for 'de.stephanlefty.MailBurg'".
    export XDG_DATA_DIRS="${pkgs.hicolor-icon-theme}/share:''${XDG_DATA_DIRS:-}"
    exec ${pythonEnv}/bin/python3 -m mailburg.ui.app "$@"
  '';

  # Kompiliertes GSettings-Schema "org.gtk.Settings.FileChooser" als
  # eigene Store-Ableitung, nicht als "mktemp -d" im shellHook: Ein
  # mktemp-Verzeichnis landet unter $TMPDIR, und das setzt "nix develop"
  # bzw. "nix-shell" selbst auf sein eigenes, flüchtiges
  # Build-Verzeichnis - das ist schon weg, sobald die Shell-Einrichtung
  # durchgelaufen ist, nicht erst beim Verlassen der Shell. Ein
  # Store-Pfad bleibt, solange ihn niemand von Hand aus dem Store
  # entfernt. Ohne dieses Schema stürzt Qt beim ersten Öffnen des
  # nativen Dateiauswahldialogs ab ("Settings schema
  # 'org.gtk.Settings.FileChooser' is not installed").
  gtkSchemas = pkgs.runCommand "mailburg-gtk-schemas" { } ''
    mkdir -p "$out"
    ${pkgs.glib.dev}/bin/glib-compile-schemas --targetdir="$out" \
      "${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}/glib-2.0/schemas"
  '';

  # PySide6 braucht zur Laufzeit u.a. libGL, xkbcommon und X11/Wayland-
  # Bibliotheken im Ladepfad, sonst scheitert der Fensterstart mit
  # "could not load the Qt platform plugin xcb", obwohl Qt korrekt
  # installiert ist.
  ldLibraryPath = pkgs.lib.makeLibraryPath [
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

  # Alle Pakete, die in die Devshell gehören: Python-Umgebung, Wrapper,
  # Hilfsprogramme (pdftotext, tesseract, Schlüsselbund-Backend, Icon-Theme).
  devPackages = [
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

    # Liefert u.a. das Icon-Theme fürs GTK-Plattformthema. Das
    # eigentliche GSettings-Schema "org.gtk.Settings.FileChooser"
    # kommt kompiliert aus "gtkSchemas" oben und wird unten im
    # shellHook über GSETTINGS_SCHEMA_DIR bekanntgemacht.
    pkgs.gtk3
  ];
in
{
  inherit pythonEnv mailburgCli mailburgGui gtkSchemas ldLibraryPath devPackages;
}
