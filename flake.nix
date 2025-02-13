{
  outputs = _: {
    lib.select = import ./select.nix;
    tests = builtins.toJSON (import ./tests.nix);
  };
}
