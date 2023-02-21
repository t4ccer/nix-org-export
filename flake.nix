{
  description = "nix-org-export";

  inputs = {
    emacs.url = "github:nix-community/emacs-overlay";
    nixpkgs.url = "github:NixOS/nixpkgs";
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    ...
  }: let
    supportedSystems = nixpkgs.lib.systems.flakeExposed;
    perSystem = nixpkgs.lib.genAttrs supportedSystems;
    pkgsFor = system:
      import nixpkgs {
        inherit system;
        overlays = [inputs.emacs.overlay];
      };

    customEmacsFor = system:
      (pkgsFor system).emacsWithPackagesFromUsePackage {
        package = (pkgsFor system).emacs;
        config = "";
        extraEmacsPackages = epkgs: [
          epkgs.org
        ];
      };

    elispScriptFor = system:
      (pkgsFor system).writeTextFile {
        name = "org-export.el";
        text = ''
          (message "Exporting org to pdf...")
          (require 'org)
          (find-file (getenv "NIX_ORG_EXPORT_FILE"))
          (if (getenv "NIX_ORG_EXPORT_OUT")
            (copy-file (org-latex-export-to-pdf) (getenv "NIX_ORG_EXPORT_OUT") 't)
            (org-latex-export-to-pdf))
          (message "Exporting org to pdf done!")
        '';
      };
  in rec {
    exportOrgFor = system: src: file:
      (pkgsFor system).stdenv.mkDerivation {
        name = "exported.pdf";
        inherit src;
        buildPhase = ''
          cp -r $src .
          stat ${file}
          export NIX_ORG_EXPORT_OUT="$(mktemp out.XXXXXX)"
          ${self.apps.${system}.org2pdf.program} "${file}"
        '';
        installPhase = ''
          cp $NIX_ORG_EXPORT_OUT $out
        '';
      };

    apps = perSystem (system: {
      default = self.apps.${system}.org2pdf;
      org2pdf = {
        type = "app";
        program =
          ((pkgsFor system).writeShellScript "org2pdf.sh" ''
            export PATH="${(pkgsFor system).texlive.combined.scheme-full}/bin:${(pkgsFor system).git}/bin"
            if (($# == 1))
            then
            export NIX_ORG_EXPORT_FILE="$1"
            ${customEmacsFor system}/bin/emacs --batch --no-init --load ${elispScriptFor system}
            else
            echo "Usage: $0 <org-file>"
            exit 1
            fi
          '')
          .outPath;
      };
    });

    # Example how to use `exportOrgFor`
    readmeExported = perSystem (system: exportOrgFor system ./. "README.org");

    formatter = perSystem (system: nixpkgs.legacyPackages.${system}.alejandra);
  };
}
