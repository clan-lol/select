{
  outputs = _: {
    lib = import ./select.nix;
    tests = builtins.toJSON (import ./tests.nix);
  };
}
