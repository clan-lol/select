let
  select = import ./select.nix;
  testdata = {
    somedict = {
      hello = "world";
      foo = {
        something.x = "hi";
        something.y = "there";
        something.z = "sup";
      };
      "foo.bar" = "baz";
    };
    somelists = [
      { name = "foo"; data.a = ":)"; }
      { name = "bar"; data.b = ":|"; }
      { name = "baz"; data.c = ":("; }
    ];
  };
in
  {
    listSingle = assert ((select "somelists.0.name" testdata) == "foo"); true;
    listAll = assert ((select "somelists.*.name" testdata) == [ "foo" "bar" "baz" ]); true;
    listMulti = assert ((select "somelists.{0,2}.name" testdata) == [ "foo" "baz" ]); true;
    dictSingle = assert ((select "somedict.hello" testdata) == "world"); true;
    dictQuoted = assert ((select ''somedict."foo.bar"'' testdata) == "baz"); true;
    dictMulti = assert ((select "somedict.foo.something.{x,y}" testdata) == { x = "hi"; y = "there";}); true;
    dictAll = assert ((select "somedict.foo.something.*" testdata) == { x = "hi"; y = "there"; z = "sup";}); true;

  }
