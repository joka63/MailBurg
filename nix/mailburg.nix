{ pkgs ? import <nixpkgs> { }
, lib ? pkgs.lib
, src ? lib.cleanSource ../.
, version ? "unstable"
, makeDesktopItem ? pkgs.makeDesktopItem
, copyDesktopItems ? pkgs.copyDesktopItems
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

    # --- Desktop-Entry ---
  desktopItems = [
    (makeDesktopItem {
      name = "de.stefanlefty.MailBurg";
      desktopName = "MailBurg";
      exec = "mailburg-gui";
      icon = "mailburg";           # Icon-Name (in $out/share/icons/...)
      categories = [ "Office;Email" ];
      comment = "E-Mails sammeln, aufbewahren und durchsuchen";
    })
  ];

  nativeBuildInputs = [
    pkgs.makeWrapper
    pkgs.wrapGAppsHook3
    pkgs.qt6.qtbase
    pkgs.qt6.wrapQtAppsHook
    pythonPackages.setuptools
    pythonPackages.wheel
    copyDesktopItems
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
  '';

  meta = with lib; {
    description = "Archiv für E-Mail, an einem Ort Ihrer Wahl";
    homepage = "https://github.com/Stephan-Lefty/MailBurg";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "mailburg-gui";
  };
}
