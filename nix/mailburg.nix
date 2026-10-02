{ pkgs ? import <nixpkgs> { }
, lib ? pkgs.lib
, src ? lib.cleanSource ../.
, version ? "unstable"
}:

let
  pythonPackages = pkgs.python3Packages;

  # Der Dateiauswahldialog braucht das kompiliertes Schema auch außerhalb der
  # Devshell, sonst fehlt Qt beim Start die passende GSettings-Basis.
  gtkSchemas = pkgs.runCommand "mailburg-gtk-schemas" { } ''
    mkdir -p "$out"
    ${pkgs.glib.dev}/bin/glib-compile-schemas --targetdir="$out" \
      "${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}/glib-2.0/schemas"
  '';
in
pythonPackages.buildPythonApplication rec {
  pname = "mailburg";
  inherit version src;
  format = "pyproject";

  nativeBuildInputs = [
    pkgs.makeWrapper
    pkgs.wrapGAppsHook3
    pkgs.qt6.qtbase
    pkgs.qt6.wrapQtAppsHook
    pythonPackages.setuptools
    pythonPackages.wheel
  ];

  propagatedBuildInputs = with pythonPackages; [
    pyside6
    keyring
    pypdf
    zstandard
    cryptography
    starlette
    uvicorn
  ];

  buildInputs = [
    pkgs.gtk3
    pkgs.gnome-keyring
    pkgs.libsecret
  ];

  makeWrapperArgs = [
    "--set"
    "GSETTINGS_SCHEMA_DIR"
    "${gtkSchemas}"
    "--prefix"
    "PATH"
    ":"
    (lib.makeBinPath [ pkgs.poppler-utils pkgs.tesseract ])
  ];

  postInstall = ''
    install -Dm644 ${src}/assets/icon.svg \
      "$out/share/icons/hicolor/scalable/apps/mailburg.svg"

    cat > mailburg.desktop <<EOF
    [Desktop Entry]
    Type=Application
    Name=MailBurg
    GenericName=E-Mail-Archiv
    Comment=E-Mails sammeln, aufbewahren und durchsuchen
    Exec=${placeholder "out"}/bin/mailburg-gui %f
    Icon=mailburg
    Terminal=false
    Categories=Office;Email;
    Keywords=Mail;E-Mail;Archiv;Suche;IMAP;
    StartupNotify=true
    EOF

    install -Dm644 mailburg.desktop \
      "$out/share/applications/de.stephanlefty.MailBurg.desktop"
  '';

  postFixup = ''
    # Qt sucht beim Portal nach .desktop Dateien; XDG_DATA_DIRS muss auf
    # den Store-Pfad zeigen, sonst erscheint die Warnung
    # "Could not register app ID: App info not found".
    ${pkgs.lib.getExe pkgs.makeWrapper} "$out/bin/mailburg-gui" "$out/bin/mailburg-gui.wrapped" \
      --prefix XDG_DATA_DIRS : "$out/share:${pkgs.hicolor-icon-theme}/share"
    mv "$out/bin/mailburg-gui.wrapped" "$out/bin/mailburg-gui"
  '';

  meta = with lib; {
    description = "Archiv für E-Mail, an einem Ort Ihrer Wahl";
    homepage = "https://github.com/Stephan-Lefty/MailBurg";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "mailburg-gui";
  };
}
