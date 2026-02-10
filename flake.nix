{
  description = "Godot 4.5.1";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs { inherit system; };

      buildInputs = with pkgs; [
        godot_4
        gdscript-formatter
        clang-tools
        # gdtoolkit_4
        # python311Packages.gdtoolkit_4
      ];
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        inherit buildInputs;

        shellHook = ''
          echo "Godot nix shell loaded."
        '';
      };

      apps.${system}.default = {
        type = "app";
        program = "${pkgs.godot_4}/bin/godot";
      };
    };
}
