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
          (setenv "PATH" (concat (getenv "PATH") ":${(pkgsFor system).texlive.combined.scheme-full}/bin"))
          (require 'org)
          (find-file "file.org")
          (org-latex-export-to-pdf)
          (message "Exporting org to pdf done!")
        '';
      };
  in rec {
    exportOrgFor = system: file:
      derivation {
        name = "exported.pdf";
        inherit system;
        builder = "${(pkgsFor system).bash}/bin/bash";
        args = [
          "-c"
          ''
            ${(pkgsFor system).coreutils}/bin/cp ${file} file.org
            ${customEmacsFor system}/bin/emacs --batch --no-init --load ${elispScriptFor system}
            ${(pkgsFor system).coreutils}/bin/mv file.pdf $out
          ''
        ];
      };

    # Example how to use `exportOrgFor`
    readmeExported = perSystem (system: exportOrgFor system ./README.org);

    formatter = perSystem (system: nixpkgs.legacyPackages.${system}.alejandra);
  };
}
