{
  lib,
  stdenvNoCC,
  makeWrapper,
  runtimeShell,
  quickshell,
  adwaita-icon-theme,
  hicolor-icon-theme,
  glib,
  dconf,
  networkmanager,
  wl-clipboard,
  cliphist,
  grim,
  slurp,
  coreutils,
  gnugrep,
  gnused,
  findutils,
  procps,
}:

# Tessera is plain QML: Quickshell compiles it at startup, so there is nothing
# to build. The derivation only places the tree and wraps the dispatcher in
# front of it.
#
# Every external program the shell runs must be on the wrapper's PATH, or the
# feature it backs silently stays dark: gdbus answers the colour scheme from
# the desktop portal, nmcli joins hidden networks, cliphist and wl-clipboard
# keep the clipboard history, grim freezes the screen for the colour picker,
# and with slurp takes the screenshots on Hyprland.
#
# busctl and udevadm drive the backlight. They belong to systemd, which is
# already the session's own, so they are appended rather than prepended: the
# copies that match the running daemons should win.

stdenvNoCC.mkDerivation {
  pname = "tessera";
  version = "0.1.0";

  src = lib.cleanSourceWith {
    src = ../.;
    name = "tessera-source";
    filter =
      path: _type:
      let
        base = baseNameOf path;
      in
      !(builtins.elem base [
        ".git"
        ".direnv"
        "docs"
      ])
      && !(lib.hasPrefix "result" base);
  };

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/tessera
    cp -r shell $out/share/tessera/shell

    substitute nix/tessera.sh $out/bin/tessera \
      --replace-fail '#!/bin/sh' "#!${runtimeShell}" \
      --replace-fail '@qs@' "${quickshell}/bin/qs" \
      --replace-fail '@shell@' "$out/share/tessera/shell"
    chmod +x $out/bin/tessera

    wrapProgram $out/bin/tessera \
      --prefix PATH : ${
        lib.makeBinPath [
          glib.bin
          dconf
          networkmanager
          wl-clipboard
          cliphist
          grim
          slurp
          coreutils
          gnugrep
          gnused
          findutils
          procps
        ]
      } \
      --suffix PATH : /run/current-system/sw/bin \
      --suffix XDG_DATA_DIRS : ${
        lib.makeSearchPath "share" [
          adwaita-icon-theme
          hicolor-icon-theme
        ]
      }

    runHook postInstall
  '';

  meta = {
    description = "A desktop shell for niri and Hyprland, built on Quickshell";
    mainProgram = "tessera";
    platforms = lib.platforms.linux;
    license = lib.licenses.mit;
  };
}
