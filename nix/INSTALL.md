# Installation (NixOS)

NixOS-Benutzer haben folgende Möglichkeiten, MailBurg zu testen und/oder zu installieren:

## Installation via Flakes

### Direkt starten (ohne Installation)

```bash
nix run github:joka63/MailBurg
```

Die Default-App ist `mailburg-gui`.

### Paket dauerhaft ins Profil installieren

```bash
nix profile install github:joka63/MailBurg
```

Danach stehen `mailburg` und `mailburg-gui` im Profil zur Verfügung.

### In eine NixOS-Flake übernehmen (`environment.systemPackages`)

```nix
{
  inputs.mailburg.url = "github:joka63/MailBurg";

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

## Installation ohne Flakes (klassisch)

`default.nix` baut das Paket aus `nix/mailburg.nix`.

```bash
git clone https://github.com/joka63/MailBurg.git
cd MailBurg
nix-build
./result/bin/mailburg-gui
```

## Entwicklungsumgebung (optional)

Für Entwicklung statt Installation:

- mit Flakes: `nix develop`
- ohne Flakes: `nix-shell`

Beide Wege verwenden die vorhandene Dev-Umgebung aus `flake.nix` bzw. `shell.nix`.
