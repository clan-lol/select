{
  outputs = _: {
    lib.select = import ./select.nix;
  };
}
