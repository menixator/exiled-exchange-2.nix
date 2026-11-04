{
  description = "Exiled Exchange 2 — Path of Exile 2 trade overlay";

  inputs.nixpkgs.url = "nixpkgs";

  outputs =
    { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;

      # version. Also doubles as the revision tag on the repo with a 'v' prefix
      version = "0.16.3";
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          # libs uiohook-napi's prebuilt .node needs at dlopen time
          libuioHookDeps = [
            pkgs.libXtst
            pkgs.libXext
            pkgs.libX11
            pkgs.libxcb
            pkgs.libXi
            pkgs.libXinerama
            pkgs.libx11
            pkgs.libxcb
            pkgs.libxkbcommon
            pkgs.xinput
            pkgs.libxau
            pkgs.libxdmcp
            pkgs.libxi
            pkgs.libxinerama
            pkgs.libxt
            pkgs.libxtst
            pkgs.libxext
            pkgs.libxkbfile
          ];

          libPaths = pkgs.lib.makeLibraryPath libuioHookDeps;

          src = pkgs.fetchFromGitHub {
            owner = "Kvan7";
            repo = "Exiled-Exchange-2";
            rev = "v${version}";
            hash = "sha256-yGP9u4lidmzKJgryW1oS5ooZ2OUdtZ5afy9RtAEUQZI="; # fill in
          };

          renderer = pkgs.buildNpmPackage {
            pname = "exiled-exchange-2-renderer";
            inherit version src;
            sourceRoot = "source/renderer";

            npmDepsHash = "sha256-xFIvx5K9ZUMhpgmAnKiNxuGSBHlf8UdXBVXCsZDlcnQ=";

            preBuild = ''
              npm run make-index-files  
            '';
            npmBuildScript = "build"; # vue-tsc --noEmit && vite build

            installPhase = ''
              cp -r dist $out  
            '';
          };

          app = pkgs.buildNpmPackage {
            pname = "exiled-exchange-2";
            inherit version src;
            sourceRoot = "source/main";

            npmDepsHash = "sha256-goAtiS7vF6rtwdkImtLa/wXL9DARsf7vcKhbGSjgBeo=";
            npmBuildScript = "build"; # tsc --noEmit && node build/script.mjs --prod
            env.ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
            env.ELECTRON_OVERRIDE_DIST_PATH = "${pkgs.electron}/bin";
            env.NIX_CFLAGS_COMPILE = "-Wno-error=incompatible-pointer-types";

            env.dontPatchShebangs = 1;
            nativeBuildInputs = [ pkgs.makeWrapper ];
            buildInputs = [
              pkgs.electron
              #libuiohook dependencies
              pkgs.libx11
              pkgs.libxcb
            ];
            desktopItems = [
              (pkgs.makeDesktopItem {
                name = "Exiled Exchange 2";
                exec = "exiled-exchange-2";
                icon = "exiled-exchange-2";
                desktopName = "Exiled Exchange 2";
                comment = "Path of Exile 2 trade overlay";
                terminal = false;
              })
            ];

            #- "package.json"
            #- from: "dist"
            #  to: "."
            #  filter: ["main.js", "vision.js"]
            #- from: "../renderer/dist"
            # to: "."
            # override the installPhase.
            installPhase = ''
               runHook preInstall 
               npm prune --omit=optional --omit=dev
               outdir="$out/lib/exiled-exchange-2" 
               mkdir -p "$outdir" "$out/bin" 

               cp dist/main.js dist/vision.js "$outdir" 

               substituteInPlace "package.json" \
                 --replace-fail '"main": "dist/main.js"' '"main": "main.js"' 
               cp package.json "$outdir" 

               cp -r ${renderer}/. "$outdir/"

              cp -r node_modules "$outdir/" 

              # --no-updates disables updates
               makeWrapper ${pkgs.electron}/bin/electron "$out/bin/exiled-exchange-2" \
                 --add-flags "$outdir" \
                 --add-flags "--no-updates" \
                 --add-flags "--sandbox" \
                 --add-flags "--ozone-platform=x11" \
                 --add-flags "--disable-gpu-sandbox" \
                 --prefix LD_LIBRARY_PATH : "${libPaths}" 
              # icon
              install -Dm644 ${renderer}/icon.png "$out/share/icons/hicolor/256x256/apps/exiled-exchange-2.png"  
               runHook postInstall 
            '';
          };
        in
        {
          default = app;
          inherit app renderer;
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              nodejs_24
              electron
            ];
          };
        }
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
    };
}
