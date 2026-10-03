<!-- Vor dem Merge github:joka63/MailBurg/nix2 ersetzen durch github:Stefan-Lefty/MailBurg --> 

# Installation (NixOS)

Diese Anleitung beschreibt die Möglichkeiten, MailBurg zu testen, zu installieren oder eine Entwicklungsumgebung einzurichten. Sie ist für NixOS-Benutzer gedacht, die Nix und Flakes verwenden. 
Für andere Distributionen siehe [README.md](../README.md).


## Voraussetzungen

- NixOS 26.05 (die aktuelle stabile NixOS-Version) oder neuer
- Experimentelle Features in `/etc/nixos/configuration.nix` aktivieren
- Direnv, um die Entwicklungsumgebung automatisch beim Wechsel in das MailBurg-Verzeichnis zu laden (optional)

Hierfür folgendes in `/etc/nixos/configuration.nix` eintragen:

```nix
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  programs.direnv.enable = true;    # Optionale Empfehlung, um die Entwicklungsumgebung automatisch zu laden
```

## Imperativ

### Direkt starten (ohne Installation)

Folgendes Kommando startet den Download aller benötigten Pakete und dann die MailBurg-GUI, ohne sie dauerhaft zu installieren. 

```bash
nix run github:joka63/Mailburg/nix2?dir=nix
```

Nach dem Beenden der GUI liegen die Pakete noch im Nix-Store (`/nix/store`), 
können aber nicht mehr direkt aufgerufen werden. Sie bleiben im Nix-Store, 
so dass der nächste Aufruf von `nix run github:joka63/Mailburg/nix2?dir=nix` schneller ist.
Die nächste Nix-Garbage-Collection löscht die Pakete wieder aus dem Nix-Store,


### Paket dauerhaft ins Profil installieren

```bash
nix profile install github:joka63/Mailburg/nix2?dir=nix
```

Danach stehen die Kommandos `mailburg` und `mailburg-gui` im Profil des aufrufenden Nutzers zur Verfügung.
Der Starter für die GUI ist auch im Anwendungsmenü verfügbar, allerdings erst nach einem Neustart von NixOS.
Später ist eine Aktualisierung des Pakets mit `nix profile update MailBurg` möglich, 
Deinstallation mit `nix profile remove MailBurg`. 


## Deklarativ

In eine NixOS-Flake übernehmen (`environment.systemPackages`)

```nix
{
  inputs.mailburg.url = "github:joka63/Mailburg/nix2?dir=nix";

  outputs = { self, nixpkgs, mailburg, ... }:
  let
    system = "x86_64-linux"; # auf dein System anpassen
  in {
    nixosConfigurations.hostname = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        ./configuration.nix
        {
          environment.systemPackages = [
            mailburg.packages.${system}.default
          ];
        }
      ];
    };
  };
}
```

## Entwicklungsumgebung (optional)

Im ersten Schritt das MailBurg-Repository klonen:

```bash
git clone https://github.com/joka63/MailBurg.git
cd MailBurg
direnv allow # optional, falls direnv installiert ist
``` 

### MailBurg-Derivation bauen

Folgendes Kommando baut das MailBurg-Paket mit GUI und dem Kommandozeilen-Tool.

```bash
nix-build ./nix
```

Danach stehen die Kommandos `mailburg-gui` und `mailburg` im Verzeichnis `./result/bin/` zur Verfügung:

```bash
./result/bin/mailburg-gui
./result/bin/mailburg --help
```

### MailBurg-Programme direkt mit Python starten

Wenn `direnv` aktiviert ist, wird die Entwicklungsumgebung, d.h. die benötigten Libaries und Umgebungsvariablen, 
automatisch geladen, sobald man in das MailBurg-Verzeichnis wechselt. 
Andernfalls `nix develop ./nix` oder `nix-shell ./nix` ausführen.

Jetzt können die Kommandos `mailburg-gui` und `mailburg` direkt mit dem Python-Interpreter gestartet werden, z.B.:

```bash
python mailburg/ui/app.py
python python mailburg/__main__.py -- info ~/Dokumente/E-Mails/
```

Wichtig zu wissen: Nach Aktivierung der Entwicklungsumgebung 
verweist `python` auf die speziell für das MailBurg-Projekt erstellte Python-Version im Nix-Store, 
nicht auf die System-Python-Version (falls vorhanden). 
Den aktuellen Pfad zum Python-Interpreter kann man mit `which python` überprüfen.
Dieser sollte dann in einer Python-IDE wie z.B. PyCharm als Interpreter für das Projekt eingetragen werden, 
damit die IDE die richtigen Libaries findet. 
Falls verfügbar, empfiehlt es sich, ein direnv-Plugin für die IDE zu installieren.



